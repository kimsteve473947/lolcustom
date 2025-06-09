import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum UserRole {
  user,
  admin,
  moderator,
}

enum PlayerTier {
  unranked,
  iron,
  bronze,
  silver,
  gold,
  platinum,
  emerald,
  diamond,
  master,
  grandmaster,
  challenger,
}

class UserModel extends Equatable {
  final String uid;
  final String email;
  final String nickname;
  final String profileImageUrl;
  final Timestamp joinedAt;
  final UserRole role;
  final Map<String, dynamic>? additionalInfo;
  final String? riotId;
  final PlayerTier tier;
  final bool isPremium;
  final double? averageRating;
  final int? hostedTournamentsCount;
  final int? participatedTournamentsCount;
  final String? position;
  final int? totalRatingsCount;
  final int credits;
  final List<String>? preferredPositions;

  const UserModel({
    required this.uid,
    this.email = '',
    required this.nickname,
    this.profileImageUrl = '',
    required this.joinedAt,
    this.role = UserRole.user,
    this.additionalInfo,
    this.riotId,
    this.tier = PlayerTier.unranked,
    this.isPremium = false,
    this.averageRating,
    this.hostedTournamentsCount,
    this.participatedTournamentsCount,
    this.position,
    this.totalRatingsCount,
    this.credits = 0,
    this.preferredPositions,
  });

  // 파이어스토어에서 데이터 불러오기
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // profileImageUrl 처리 - 빈 문자열이나 유효하지 않은 URL 처리
    String profileImageUrl = data['profileImageUrl'] ?? '';
    if (profileImageUrl.isEmpty || !profileImageUrl.startsWith('http')) {
      profileImageUrl = '';
    }
    
    // preferredPositions 변환
    List<String>? preferredPositions;
    if (data['preferredPositions'] != null) {
      preferredPositions = List<String>.from(data['preferredPositions']);
    }
    
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      nickname: data['nickname'] ?? '',
      profileImageUrl: profileImageUrl,
      joinedAt: data['joinedAt'] ?? Timestamp.now(),
      role: roleFromString(data['role']),
      additionalInfo: data['additionalInfo'] as Map<String, dynamic>?,
      riotId: data['riotId'],
      tier: tierFromString(data['tier']),
      isPremium: data['isPremium'] ?? false,
      averageRating: data['averageRating'] != null ? (data['averageRating'] as num).toDouble() : null,
      hostedTournamentsCount: data['hostedTournamentsCount'] as int?,
      participatedTournamentsCount: data['participatedTournamentsCount'] as int?,
      position: data['position'] as String?,
      totalRatingsCount: data['totalRatingsCount'] as int?,
      credits: data['credits'] as int? ?? 0,
      preferredPositions: preferredPositions,
    );
  }

  // 파이어스토어에 저장할 형태로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'joinedAt': joinedAt,
      'role': role.toString().split('.').last,
      'additionalInfo': additionalInfo,
      'riotId': riotId,
      'tier': tier.toString().split('.').last,
      'isPremium': isPremium,
      'averageRating': averageRating,
      'hostedTournamentsCount': hostedTournamentsCount,
      'participatedTournamentsCount': participatedTournamentsCount,
      'position': position,
      'totalRatingsCount': totalRatingsCount,
      'credits': credits,
      'preferredPositions': preferredPositions,
    };
  }
  
  // toMap은 toFirestore와 동일하게 동작
  Map<String, dynamic> toMap() {
    return toFirestore();
  }

  // role 문자열 -> enum 변환 헬퍼
  static UserRole roleFromString(String? roleStr) {
    if (roleStr == 'admin') return UserRole.admin;
    if (roleStr == 'moderator') return UserRole.moderator;
    return UserRole.user;
  }
  
  // tier 문자열 -> enum 변환 헬퍼
  static PlayerTier tierFromString(String? tierStr) {
    if (tierStr == null) return PlayerTier.unranked;
    
    switch (tierStr.toLowerCase()) {
      case 'iron': return PlayerTier.iron;
      case 'bronze': return PlayerTier.bronze;
      case 'silver': return PlayerTier.silver;
      case 'gold': return PlayerTier.gold;
      case 'platinum': return PlayerTier.platinum;
      case 'emerald': return PlayerTier.emerald;
      case 'diamond': return PlayerTier.diamond;
      case 'master': return PlayerTier.master;
      case 'grandmaster': return PlayerTier.grandmaster;
      case 'challenger': return PlayerTier.challenger;
      default: return PlayerTier.unranked;
    }
  }

  // tier enum -> 문자열 변환 헬퍼
  static String tierToString(PlayerTier tier) {
    switch (tier) {
      case PlayerTier.iron: return '아이언';
      case PlayerTier.bronze: return '브론즈';
      case PlayerTier.silver: return '실버';
      case PlayerTier.gold: return '골드';
      case PlayerTier.platinum: return '플래티넘';
      case PlayerTier.emerald: return '에메랄드';
      case PlayerTier.diamond: return '다이아몬드';
      case PlayerTier.master: return '마스터';
      case PlayerTier.grandmaster: return '그랜드마스터';
      case PlayerTier.challenger: return '챌린저';
      default: return '언랭크';
    }
  }

  // Check if user has enough credits
  bool hasEnoughCredits(int requiredCredits) {
    return credits >= requiredCredits;
  }
  
  // Create a new user model with updated credits
  UserModel withUpdatedCredits(int newCredits) {
    return copyWith(credits: newCredits);
  }

  // UserModel 복사 메서드 (불변성 유지)
  UserModel copyWith({
    String? uid,
    String? email,
    String? nickname,
    String? profileImageUrl,
    Timestamp? joinedAt,
    UserRole? role,
    Map<String, dynamic>? additionalInfo,
    String? riotId,
    PlayerTier? tier,
    bool? isPremium,
    double? averageRating,
    int? hostedTournamentsCount,
    int? participatedTournamentsCount,
    String? position,
    int? totalRatingsCount,
    int? credits,
    List<String>? preferredPositions,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      joinedAt: joinedAt ?? this.joinedAt,
      role: role ?? this.role,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      riotId: riotId ?? this.riotId,
      tier: tier ?? this.tier,
      isPremium: isPremium ?? this.isPremium,
      averageRating: averageRating ?? this.averageRating,
      hostedTournamentsCount: hostedTournamentsCount ?? this.hostedTournamentsCount,
      participatedTournamentsCount: participatedTournamentsCount ?? this.participatedTournamentsCount,
      position: position ?? this.position,
      totalRatingsCount: totalRatingsCount ?? this.totalRatingsCount,
      credits: credits ?? this.credits,
      preferredPositions: preferredPositions ?? this.preferredPositions,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        email,
        nickname,
        profileImageUrl,
        joinedAt,
        role,
        additionalInfo,
        riotId,
        tier,
        isPremium,
        averageRating,
        hostedTournamentsCount,
        participatedTournamentsCount,
        position,
        totalRatingsCount,
        credits,
        preferredPositions,
      ];
} 