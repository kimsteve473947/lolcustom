import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';

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
    this.isAvailable = true,
    required this.lastActiveAt,
  });

  factory MercenaryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    final roleStats = Map<String, int>.from(data['roleStats'] ?? {});
    
    final skillStats = data['skillStats'] != null 
        ? Map<String, int>.from(data['skillStats']) 
        : null;
    
    final preferredPositions = List<String>.from(data['preferredPositions'] ?? []);
    
    double averageRoleStat = 0;
    if (roleStats.isNotEmpty) {
      final sum = roleStats.values.fold(0, (sum, stat) => sum + stat);
      averageRoleStat = sum / roleStats.length;
    }
    
    return MercenaryModel(
      id: doc.id,
      userUid: data['userUid'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      description: data['description'],
      preferredPositions: preferredPositions,
      roleStats: roleStats,
      skillStats: skillStats,
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      totalRatings: data['totalRatings'] ?? 0,
      averageRoleStat: averageRoleStat,
      nickname: data['nickname'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      tier: UserModel.tierFromString(data['tier']),
      isAvailable: data['isAvailable'] ?? true,
      lastActiveAt: data['lastActiveAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userUid': userUid,
      'createdAt': createdAt,
      'description': description,
      'preferredPositions': preferredPositions,
      'roleStats': roleStats,
      'skillStats': skillStats,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'tier': tier.toString().split('.').last,
      'isAvailable': isAvailable,
      'lastActiveAt': lastActiveAt,
    };
  }

  MercenaryModel copyWith({
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
  }) {
    return MercenaryModel(
      id: id,
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
    );
  }

  @override
  List<Object?> get props => [
    id, userUid, createdAt, description, preferredPositions, 
    roleStats, skillStats, averageRating, totalRatings, averageRoleStat,
    nickname, profileImageUrl, tier, isAvailable, lastActiveAt
  ];
} 