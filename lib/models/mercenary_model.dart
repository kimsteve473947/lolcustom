import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class MercenaryModel extends Equatable {
  final String id;
  final String userUid;
  final String nickname;
  final String? profileImageUrl;
  final String? tier;
  final Map<String, int> roleStats;
  final Map<String, int> skillStats;
  final List<String> preferredPositions;
  final String? description;
  final double? averageRating;
  final int ratingCount;
  final bool isAvailable;
  final Timestamp createdAt;
  final Timestamp? lastActiveAt;
  
  const MercenaryModel({
    required this.id,
    required this.userUid,
    required this.nickname,
    this.profileImageUrl,
    this.tier,
    required this.roleStats,
    required this.skillStats,
    required this.preferredPositions,
    this.description,
    this.averageRating,
    required this.ratingCount,
    required this.isAvailable,
    required this.createdAt,
    this.lastActiveAt,
  });
  
  @override
  List<Object?> get props => [
    id, userUid, nickname, profileImageUrl, tier, 
    roleStats, skillStats, preferredPositions, description,
    averageRating, ratingCount, isAvailable, createdAt, lastActiveAt
  ];
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userUid': userUid,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'tier': tier,
      'roleStats': roleStats,
      'skillStats': skillStats,
      'preferredPositions': preferredPositions,
      'description': description,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'isAvailable': isAvailable,
      'createdAt': createdAt,
      'lastActiveAt': lastActiveAt,
    };
  }
  
  factory MercenaryModel.fromMap(Map<String, dynamic> map) {
    return MercenaryModel(
      id: map['id'] ?? '',
      userUid: map['userUid'] ?? '',
      nickname: map['nickname'] ?? 'Unknown',
      profileImageUrl: map['profileImageUrl'],
      tier: map['tier'],
      roleStats: Map<String, int>.from(map['roleStats'] ?? {}),
      skillStats: Map<String, int>.from(map['skillStats'] ?? {}),
      preferredPositions: List<String>.from(map['preferredPositions'] ?? []),
      description: map['description'],
      averageRating: (map['averageRating'] as num?)?.toDouble(),
      ratingCount: map['ratingCount'] ?? 0,
      isAvailable: map['isAvailable'] ?? true,
      createdAt: map['createdAt'] ?? Timestamp.now(),
      lastActiveAt: map['lastActiveAt'],
    );
  }
  
  factory MercenaryModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return MercenaryModel.fromMap(data);
  }
  
  // 기존 getter 메서드들 추가
  int? getStatForRole(String role) {
    return roleStats[role];
  }

  int? getSkillStat(String skill) {
    return skillStats[skill];
  }

  int get averageRoleStat {
    if (roleStats.isEmpty) return 0;
    int total = 0;
    roleStats.forEach((_, value) => total += value);
    return total ~/ roleStats.length;
  }

  int get topRoleStat {
    if (roleStats.isEmpty) return 0;
    int highest = 0;
    roleStats.forEach((_, value) {
      if (value > highest) highest = value;
    });
    return highest;
  }

  String get topRole {
    if (roleStats.isEmpty) return 'N/A';
    String best = '';
    int highest = 0;
    roleStats.forEach((key, value) {
      if (value > highest) {
        highest = value;
        best = key;
      }
    });
    return best;
  }
  
  // Proper handling of nullable rating
  String getFormattedRating() {
    return (averageRating ?? 0.0).toStringAsFixed(1);
  }
  
  // Example of cast for fold operation
  static int getTotalMercenaries(Map<String, dynamic> slotsByRole) {
    return slotsByRole.values.cast<int>().fold(0, (prev, curr) => prev + curr);
  }
  
  MercenaryModel copyWith({
    String? id,
    String? userUid,
    String? nickname,
    String? profileImageUrl,
    String? tier,
    Map<String, int>? roleStats,
    Map<String, int>? skillStats,
    List<String>? preferredPositions,
    String? description,
    double? averageRating,
    int? ratingCount,
    bool? isAvailable,
    Timestamp? createdAt,
    Timestamp? lastActiveAt,
  }) {
    return MercenaryModel(
      id: id ?? this.id,
      userUid: userUid ?? this.userUid,
      nickname: nickname ?? this.nickname,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      tier: tier ?? this.tier,
      roleStats: roleStats ?? this.roleStats,
      skillStats: skillStats ?? this.skillStats,
      preferredPositions: preferredPositions ?? this.preferredPositions,
      description: description ?? this.description,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
} 