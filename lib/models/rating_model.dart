import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String id;
  final String ratedUserId;
  final String raterId;
  final String raterName;
  final String? raterProfileImageUrl;
  final double score;
  final String? role;
  final String? comment;
  final Timestamp createdAt;

  RatingModel({
    required this.id,
    required this.ratedUserId,
    required this.raterId,
    required this.raterName,
    this.raterProfileImageUrl,
    required this.score,
    this.role,
    this.comment,
    required this.createdAt,
  });

  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return RatingModel(
      id: doc.id,
      ratedUserId: data['ratedUserId'] ?? '',
      raterId: data['raterId'] ?? '',
      raterName: data['raterName'] ?? 'Unknown',
      raterProfileImageUrl: data['raterProfileImageUrl'],
      score: (data['score'] as num?)?.toDouble() ?? 0.0,
      role: data['role'],
      comment: data['comment'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ratedUserId': ratedUserId,
      'raterId': raterId,
      'raterName': raterName,
      'raterProfileImageUrl': raterProfileImageUrl,
      'score': score,
      'role': role,
      'comment': comment,
      'createdAt': createdAt,
    };
  }

  RatingModel copyWith({
    String? id,
    String? ratedUserId,
    String? raterId,
    String? raterName,
    String? raterProfileImageUrl,
    double? score,
    String? role,
    String? comment,
    Timestamp? createdAt,
  }) {
    return RatingModel(
      id: id ?? this.id,
      ratedUserId: ratedUserId ?? this.ratedUserId,
      raterId: raterId ?? this.raterId,
      raterName: raterName ?? this.raterName,
      raterProfileImageUrl: raterProfileImageUrl ?? this.raterProfileImageUrl,
      score: score ?? this.score,
      role: role ?? this.role,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 