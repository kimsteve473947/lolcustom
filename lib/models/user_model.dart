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
  });

  // 파이어스토어에서 데이터 불러오기
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      nickname: data['nickname'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      joinedAt: data['joinedAt'] ?? Timestamp.now(),
      role: _roleFromString(data['role']),
      additionalInfo: data['additionalInfo'] as Map<String, dynamic>?,
      riotId: data['riotId'],
      tier: _tierFromString(data['tier']),
      isPremium: data['isPremium'] ?? false,
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
    };
  }

  // role 문자열 -> enum 변환 헬퍼
  static UserRole _roleFromString(String? roleStr) {
    if (roleStr == 'admin') return UserRole.admin;
    if (roleStr == 'moderator') return UserRole.moderator;
    return UserRole.user;
  }
  
  // tier 문자열 -> enum 변환 헬퍼
  static PlayerTier _tierFromString(String? tierStr) {
    if (tierStr == null) return PlayerTier.unranked;
    
    switch (tierStr.toLowerCase()) {
      case 'iron': return PlayerTier.iron;
      case 'bronze': return PlayerTier.bronze;
      case 'silver': return PlayerTier.silver;
      case 'gold': return PlayerTier.gold;
      case 'platinum': return PlayerTier.platinum;
      case 'diamond': return PlayerTier.diamond;
      case 'master': return PlayerTier.master;
      case 'grandmaster': return PlayerTier.grandmaster;
      case 'challenger': return PlayerTier.challenger;
      default: return PlayerTier.unranked;
    }
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
      ];
} 