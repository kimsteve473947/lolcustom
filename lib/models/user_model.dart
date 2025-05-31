import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum UserRole {
  user,
  admin,
  moderator,
}

class UserModel extends Equatable {
  final String uid;
  final String email;
  final String nickname;
  final String profileImageUrl;
  final DateTime createdAt;
  final UserRole role;
  final Map<String, dynamic>? additionalInfo;

  const UserModel({
    required this.uid,
    this.email = '',
    required this.nickname,
    this.profileImageUrl = '',
    required this.createdAt,
    this.role = UserRole.user,
    this.additionalInfo,
  });

  // 파이어스토어에서 데이터 불러오기
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      nickname: data['nickname'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      role: _roleFromString(data['role']),
      additionalInfo: data['additionalInfo'] as Map<String, dynamic>?,
    );
  }

  // 파이어스토어에 저장할 형태로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'role': role.toString().split('.').last,
      'additionalInfo': additionalInfo,
    };
  }

  // role 문자열 -> enum 변환 헬퍼
  static UserRole _roleFromString(String? roleStr) {
    if (roleStr == 'admin') return UserRole.admin;
    if (roleStr == 'moderator') return UserRole.moderator;
    return UserRole.user;
  }

  // UserModel 복사 메서드 (불변성 유지)
  UserModel copyWith({
    String? uid,
    String? email,
    String? nickname,
    String? profileImageUrl,
    DateTime? createdAt,
    UserRole? role,
    Map<String, dynamic>? additionalInfo,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        email,
        nickname,
        profileImageUrl,
        createdAt,
        role,
        additionalInfo,
      ];
} 