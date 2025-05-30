import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String id;
  final String tournamentId;
  final String targetUid;
  final String raterUid;
  final String raterName;
  final double stars;
  final String? comment;
  final Timestamp createdAt;
  final Map<String, double>? statRatings; // teamwork, pass, vision, etc.

  RatingModel({
    required this.id,
    required this.tournamentId,
    required this.targetUid,
    required this.raterUid,
    required this.raterName,
    required this.stars,
    this.comment,
    required this.createdAt,
    this.statRatings,
  });

  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Handle the stat ratings map
    Map<String, double>? statRatings;
    if (data['statRatings'] != null) {
      statRatings = {};
      Map<String, dynamic> statsData = data['statRatings'];
      statsData.forEach((key, value) {
        statRatings![key] = (value as num).toDouble();
      });
    }

    return RatingModel(
      id: doc.id,
      tournamentId: data['tournamentId'] ?? '',
      targetUid: data['targetUid'] ?? '',
      raterUid: data['raterUid'] ?? '',
      raterName: data['raterName'] ?? 'Unknown',
      stars: (data['stars'] ?? 0.0).toDouble(),
      comment: data['comment'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      statRatings: statRatings,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tournamentId': tournamentId,
      'targetUid': targetUid,
      'raterUid': raterUid,
      'raterName': raterName,
      'stars': stars,
      'comment': comment,
      'createdAt': createdAt,
      'statRatings': statRatings,
    };
  }

  RatingModel copyWith({
    String? id,
    String? tournamentId,
    String? targetUid,
    String? raterUid,
    String? raterName,
    double? stars,
    String? comment,
    Timestamp? createdAt,
    Map<String, double>? statRatings,
  }) {
    return RatingModel(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      targetUid: targetUid ?? this.targetUid,
      raterUid: raterUid ?? this.raterUid,
      raterName: raterName ?? this.raterName,
      stars: stars ?? this.stars,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      statRatings: statRatings ?? this.statRatings,
    );
  }
} 