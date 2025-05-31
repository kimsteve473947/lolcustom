import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

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
    );
  }

  @override
  List<Object?> get props => [
    id, userUid, createdAt, description, preferredPositions, 
    roleStats, skillStats, averageRating, totalRatings, averageRoleStat
  ];
} 