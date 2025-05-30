import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String uid;
  final String? riotId;
  final String nickname;
  final String? tier;
  final String? profileImageUrl;
  final int credits;
  final double? averageRating;
  final int ratingCount;
  final bool isVerified;
  final DateTime joinedAt;
  final DateTime? lastActiveAt;
  final bool isPremium;
  final Map<String, dynamic>? stats;
  
  const UserModel({
    required this.uid,
    this.riotId,
    required this.nickname,
    this.tier,
    this.profileImageUrl,
    this.credits = 0,
    this.averageRating,
    this.ratingCount = 0,
    this.isVerified = false,
    required this.joinedAt,
    this.lastActiveAt,
    this.isPremium = false,
    this.stats,
  });
  
  @override
  List<Object?> get props => [
    uid, riotId, nickname, tier, profileImageUrl, 
    credits, averageRating, ratingCount, isVerified, 
    joinedAt, lastActiveAt, isPremium, stats
  ];
  
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'riotId': riotId,
      'nickname': nickname,
      'tier': tier,
      'profileImageUrl': profileImageUrl,
      'credits': credits,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'isVerified': isVerified,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'isPremium': isPremium,
      'stats': stats,
    };
  }
  
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      riotId: map['riotId'],
      nickname: map['nickname'] ?? 'Unknown',
      tier: map['tier'],
      profileImageUrl: map['profileImageUrl'],
      credits: map['credits'] ?? 0,
      averageRating: (map['averageRating'] as num?)?.toDouble(),
      ratingCount: map['ratingCount'] ?? 0,
      isVerified: map['isVerified'] ?? false,
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt: (map['lastActiveAt'] as Timestamp?)?.toDate(),
      isPremium: map['isPremium'] ?? false,
      stats: map['stats'],
    );
  }
  
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    data['uid'] = doc.id;
    return UserModel.fromMap(data);
  }
  
  UserModel copyWith({
    String? uid,
    String? riotId,
    String? nickname,
    String? tier,
    String? profileImageUrl,
    int? credits,
    double? averageRating,
    int? ratingCount,
    bool? isVerified,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    bool? isPremium,
    Map<String, dynamic>? stats,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      riotId: riotId ?? this.riotId,
      nickname: nickname ?? this.nickname,
      tier: tier ?? this.tier,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      credits: credits ?? this.credits,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      isVerified: isVerified ?? this.isVerified,
      joinedAt: joinedAt ?? this.joinedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isPremium: isPremium ?? this.isPremium,
      stats: stats ?? this.stats,
    );
  }
  
  factory UserModel.initial() {
    return UserModel(
      uid: '',
      nickname: 'Guest',
      joinedAt: DateTime.now(),
    );
  }
} 