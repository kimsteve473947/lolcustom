import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? riotId;
  final String nickname;
  final String? tier;
  final int credits;
  final double? averageRating;
  final String? profileImageUrl;
  final Timestamp joinedAt;
  final bool isPremium;

  UserModel({
    required this.uid,
    this.riotId,
    required this.nickname,
    this.tier,
    this.credits = 0,
    this.averageRating,
    this.profileImageUrl,
    required this.joinedAt,
    this.isPremium = false,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      riotId: data['riotId'],
      nickname: data['nickname'] ?? 'Unknown',
      tier: data['tier'],
      credits: data['credits'] ?? 0,
      averageRating: data['averageRating']?.toDouble(),
      profileImageUrl: data['profileImageUrl'],
      joinedAt: data['joinedAt'] ?? Timestamp.now(),
      isPremium: data['isPremium'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'riotId': riotId,
      'nickname': nickname,
      'tier': tier,
      'credits': credits,
      'averageRating': averageRating,
      'profileImageUrl': profileImageUrl,
      'joinedAt': joinedAt,
      'isPremium': isPremium,
    };
  }

  UserModel copyWith({
    String? uid,
    String? riotId,
    String? nickname,
    String? tier,
    int? credits,
    double? averageRating,
    String? profileImageUrl,
    Timestamp? joinedAt,
    bool? isPremium,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      riotId: riotId ?? this.riotId,
      nickname: nickname ?? this.nickname,
      tier: tier ?? this.tier,
      credits: credits ?? this.credits,
      averageRating: averageRating ?? this.averageRating,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      joinedAt: joinedAt ?? this.joinedAt,
      isPremium: isPremium ?? this.isPremium,
    );
  }
} 