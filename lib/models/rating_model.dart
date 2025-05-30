import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class RatingModel extends Equatable {
  final String id;
  final String ratedUserId;
  final String raterId;
  final String raterName;
  final String? raterProfileImageUrl;
  final double score;
  final String? role;
  final String? comment;
  final Timestamp createdAt;
  final int stars; // Required by some UI components
  
  const RatingModel({
    required this.id,
    required this.ratedUserId,
    required this.raterId,
    required this.raterName,
    this.raterProfileImageUrl,
    required this.score,
    this.role,
    this.comment,
    required this.createdAt,
    int? stars,
  }) : stars = stars ?? score.round(); // Default stars to rounded score
  
  @override
  List<Object?> get props => [
    id, ratedUserId, raterId, raterName, raterProfileImageUrl, 
    score, role, comment, createdAt, stars
  ];
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ratedUserId': ratedUserId,
      'raterId': raterId,
      'raterName': raterName,
      'raterProfileImageUrl': raterProfileImageUrl,
      'score': score,
      'role': role,
      'comment': comment,
      'createdAt': createdAt,
      'stars': stars,
    };
  }
  
  factory RatingModel.fromMap(Map<String, dynamic> map) {
    return RatingModel(
      id: map['id'] ?? '',
      ratedUserId: map['ratedUserId'] ?? '',
      raterId: map['raterId'] ?? '',
      raterName: map['raterName'] ?? 'Unknown',
      raterProfileImageUrl: map['raterProfileImageUrl'],
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      role: map['role'],
      comment: map['comment'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      stars: map['stars'] ?? ((map['score'] as num?)?.round() ?? 0),
    );
  }
  
  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return RatingModel.fromMap(data);
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
    int? stars,
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
      stars: stars ?? this.stars,
    );
  }
} 