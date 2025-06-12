import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';

// Constants for availability time slots
const List<String> kDaysOfWeek = ['월', '화', '수', '목', '금', '토', '일'];
const List<String> kTimeSlots = ['오전', '오후', '저녁'];

class MercenaryModel extends Equatable {
  final String id;
  final String userUid;
  final Timestamp createdAt;
  final String? description;
  final List<String> preferredPositions;
  final Map<String, int> roleStats;
  final Map<String, int>? skillStats;
  final double averageRating;
  final int totalRatings;
  final double averageRoleStat;
  final String nickname;
  final String? profileImageUrl;
  final PlayerTier tier;
  final bool isAvailable;
  final Timestamp lastActiveAt;
  final Map<String, List<String>> availabilityTimeSlots;
  final String? demographicInfo;

  const MercenaryModel({
    required this.id,
    required this.userUid,
    required this.createdAt,
    this.description,
    required this.preferredPositions,
    required this.roleStats,
    this.skillStats,
    this.averageRating = 0.0,
    this.totalRatings = 0,
    required this.averageRoleStat,
    required this.nickname,
    this.profileImageUrl,
    required this.tier,
    required this.isAvailable,
    required this.lastActiveAt,
    this.availabilityTimeSlots = const {},
    this.demographicInfo,
  });

  factory MercenaryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MercenaryModel(
      id: doc.id,
      userUid: data['userUid'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      description: data['description'],
      preferredPositions: List<String>.from(data['preferredPositions'] ?? []),
      roleStats: Map<String, int>.from(data['roleStats'] ?? {}),
      skillStats: data['skillStats'] != null
          ? Map<String, int>.from(data['skillStats'])
          : null,
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      totalRatings: data['totalRatings'] ?? 0,
      averageRoleStat: (data['averageRoleStat'] ?? 0.0).toDouble(),
      nickname: data['nickname'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      tier: PlayerTier.values[data['tier'] ?? PlayerTier.unranked.index],
      isAvailable: data['isAvailable'] ?? true,
      lastActiveAt: data['lastActiveAt'] ?? Timestamp.now(),
      availabilityTimeSlots: data['availabilityTimeSlots'] != null
          ? Map<String, List<String>>.from(
              data['availabilityTimeSlots'].map(
                (key, value) => MapEntry(key, List<String>.from(value)),
              ),
            )
          : {},
      demographicInfo: data['demographicInfo'],
    );
  }

  Map<String, dynamic> toFirestore() {
    // availabilityTimeSlots가 비어 있으면 빈 맵으로 변환
    final Map<String, List<String>> safeAvailabilityTimeSlots = availabilityTimeSlots.isEmpty 
        ? {} 
        : Map<String, List<String>>.from(availabilityTimeSlots);
    
    return {
      'userUid': userUid,
      'createdAt': createdAt,
      'description': description ?? '',
      'preferredPositions': preferredPositions,
      'roleStats': roleStats,
      'skillStats': skillStats ?? {},
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'averageRoleStat': averageRoleStat,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'tier': tier.index,
      'isAvailable': isAvailable,
      'lastActiveAt': lastActiveAt,
      'availabilityTimeSlots': safeAvailabilityTimeSlots,
      'demographicInfo': demographicInfo ?? '',
    };
  }

  MercenaryModel copyWith({
    String? id,
    String? userUid,
    Timestamp? createdAt,
    String? description,
    List<String>? preferredPositions,
    Map<String, int>? roleStats,
    Map<String, int>? skillStats,
    double? averageRating,
    int? totalRatings,
    double? averageRoleStat,
    String? nickname,
    String? profileImageUrl,
    PlayerTier? tier,
    bool? isAvailable,
    Timestamp? lastActiveAt,
    Map<String, List<String>>? availabilityTimeSlots,
    String? demographicInfo,
  }) {
    return MercenaryModel(
      id: id ?? this.id,
      userUid: userUid ?? this.userUid,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      preferredPositions: preferredPositions ?? this.preferredPositions,
      roleStats: roleStats ?? this.roleStats,
      skillStats: skillStats ?? this.skillStats,
      averageRating: averageRating ?? this.averageRating,
      totalRatings: totalRatings ?? this.totalRatings,
      averageRoleStat: averageRoleStat ?? this.averageRoleStat,
      nickname: nickname ?? this.nickname,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      tier: tier ?? this.tier,
      isAvailable: isAvailable ?? this.isAvailable,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      availabilityTimeSlots: availabilityTimeSlots ?? this.availabilityTimeSlots,
      demographicInfo: demographicInfo ?? this.demographicInfo,
    );
  }

  @override
  List<Object?> get props => [
    id, userUid, createdAt, description, preferredPositions, 
    roleStats, skillStats, averageRating, totalRatings, averageRoleStat,
    nickname, profileImageUrl, tier, isAvailable, lastActiveAt,
    availabilityTimeSlots, demographicInfo
  ];
  
  // Helper method to get the top role (highest stat)
  String get topRole {
    if (roleStats.isEmpty) return 'N/A';
    
    String topRole = roleStats.keys.first;
    int topStat = roleStats.values.first;
    
    roleStats.forEach((role, stat) {
      if (stat > topStat) {
        topRole = role;
        topStat = stat;
      }
    });
    
    return topRole;
  }
  
  // Helper method to get the top role stat value
  int get topRoleStat {
    if (roleStats.isEmpty) return 0;
    
    return roleStats.values.reduce((max, stat) => stat > max ? stat : max);
  }
  
  // Helper method to get availability summary
  String get availabilitySummary {
    if (availabilityTimeSlots.isEmpty) return '시간대 미설정';
    
    // Count days with morning, afternoon, evening
    final Map<String, int> timeCounts = {
      '오전': 0,
      '오후': 0,
      '저녁': 0,
      '주말': 0,
      '평일': 0,
    };
    
    final weekends = ['토', '일'];
    final weekdays = ['월', '화', '수', '목', '금'];
    
    availabilityTimeSlots.forEach((day, slots) {
      for (final slot in slots) {
        timeCounts[slot] = (timeCounts[slot] ?? 0) + 1;
      }
      
      if (weekends.contains(day) && slots.isNotEmpty) {
        timeCounts['주말'] = (timeCounts['주말'] ?? 0) + 1;
      }
      
      if (weekdays.contains(day) && slots.isNotEmpty) {
        timeCounts['평일'] = (timeCounts['평일'] ?? 0) + 1;
      }
    });
    
    // Create summary
    final List<String> summary = [];
    
    // Weekend/Weekday
    if (timeCounts['주말']! > 0 && timeCounts['평일']! > 0) {
      summary.add('전체');
    } else if (timeCounts['주말']! > 0) {
      summary.add('주말');
    } else if (timeCounts['평일']! > 0) {
      summary.add('평일');
    }
    
    // Time of day
    final List<String> timeSlots = [];
    if (timeCounts['오전']! >= 3) timeSlots.add('오전');
    if (timeCounts['오후']! >= 3) timeSlots.add('오후');
    if (timeCounts['저녁']! >= 3) timeSlots.add('저녁');
    
    if (timeSlots.isNotEmpty) {
      summary.add(timeSlots.join('/'));
    }
    
    return summary.join(' ');
  }
} 