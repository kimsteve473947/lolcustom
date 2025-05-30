import 'package:cloud_firestore/cloud_firestore.dart';

class MercenaryModel {
  final String id;
  final String userUid;
  final String nickname;
  final String? profileImageUrl;
  final String? tier;
  final Map<String, int> roleStats; // RW, CF, CM, etc.
  final Map<String, int> skillStats; // teamwork, pass, vision
  final bool isAvailable;
  final List<String> preferredPositions;
  final String? description;
  final double? averageRating;
  final Timestamp createdAt;
  final Timestamp? lastActiveAt;

  MercenaryModel({
    required this.id,
    required this.userUid,
    required this.nickname,
    this.profileImageUrl,
    this.tier,
    required this.roleStats,
    required this.skillStats,
    this.isAvailable = true,
    required this.preferredPositions,
    this.description,
    this.averageRating,
    required this.createdAt,
    this.lastActiveAt,
  });

  factory MercenaryModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Handle role stats
    Map<String, int> roleStats = {
      'RW': 0, 'CF': 0, 'LW': 0,
      'RM': 0, 'CM': 0, 'LM': 0,
      'RB': 0, 'CB': 0, 'LB': 0,
      'GK': 0,
    };
    
    if (data['roleStats'] != null) {
      Map<String, dynamic> statsData = data['roleStats'];
      statsData.forEach((key, value) {
        roleStats[key] = value as int;
      });
    }
    
    // Handle skill stats
    Map<String, int> skillStats = {
      'teamwork': 0, 'pass': 0, 'vision': 0,
      'shooting': 0, 'dribble': 0, 'defending': 0,
    };
    
    if (data['skillStats'] != null) {
      Map<String, dynamic> skillData = data['skillStats'];
      skillData.forEach((key, value) {
        skillStats[key] = value as int;
      });
    }
    
    // Handle preferred positions
    List<String> preferredPositions = [];
    if (data['preferredPositions'] != null) {
      for (var position in data['preferredPositions']) {
        preferredPositions.add(position as String);
      }
    }

    return MercenaryModel(
      id: doc.id,
      userUid: data['userUid'] ?? '',
      nickname: data['nickname'] ?? 'Unknown',
      profileImageUrl: data['profileImageUrl'],
      tier: data['tier'],
      roleStats: roleStats,
      skillStats: skillStats,
      isAvailable: data['isAvailable'] ?? true,
      preferredPositions: preferredPositions,
      description: data['description'],
      averageRating: data['averageRating']?.toDouble(),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      lastActiveAt: data['lastActiveAt'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userUid': userUid,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'tier': tier,
      'roleStats': roleStats,
      'skillStats': skillStats,
      'isAvailable': isAvailable,
      'preferredPositions': preferredPositions,
      'description': description,
      'averageRating': averageRating,
      'createdAt': createdAt,
      'lastActiveAt': lastActiveAt ?? Timestamp.now(),
    };
  }

  MercenaryModel copyWith({
    String? id,
    String? userUid,
    String? nickname,
    String? profileImageUrl,
    String? tier,
    Map<String, int>? roleStats,
    Map<String, int>? skillStats,
    bool? isAvailable,
    List<String>? preferredPositions,
    String? description,
    double? averageRating,
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
      isAvailable: isAvailable ?? this.isAvailable,
      preferredPositions: preferredPositions ?? this.preferredPositions,
      description: description ?? this.description,
      averageRating: averageRating ?? this.averageRating,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

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
} 