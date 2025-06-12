import 'package:cloud_firestore/cloud_firestore.dart';

enum ClanApplicationStatus {
  pending,
  accepted,
  rejected,
  cancelled
}

class ClanApplicationModel {
  final String id;
  final String clanId;
  final String userUid;
  final String userName;
  final String? userProfileImageUrl;
  final ClanApplicationStatus status;
  final Timestamp appliedAt;
  final String? message;
  final String? position; // 선호 포지션 (예: "미드", "원딜" 등)
  final String? experience; // 플레이 경험/경력
  final String? contactInfo; // 연락처 정보

  ClanApplicationModel({
    required this.id,
    required this.clanId,
    required this.userUid,
    required this.userName,
    this.userProfileImageUrl,
    this.status = ClanApplicationStatus.pending,
    required this.appliedAt,
    this.message,
    this.position,
    this.experience,
    this.contactInfo,
  });

  factory ClanApplicationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return ClanApplicationModel(
      id: doc.id,
      clanId: data['clanId'] ?? '',
      userUid: data['userUid'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userProfileImageUrl: data['userProfileImageUrl'],
      status: ClanApplicationStatus.values[data['status'] ?? 0],
      appliedAt: data['appliedAt'] ?? Timestamp.now(),
      message: data['message'],
      position: data['position'],
      experience: data['experience'],
      contactInfo: data['contactInfo'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clanId': clanId,
      'userUid': userUid,
      'userName': userName,
      'userProfileImageUrl': userProfileImageUrl,
      'status': status.index,
      'appliedAt': appliedAt,
      'message': message,
      'position': position,
      'experience': experience,
      'contactInfo': contactInfo,
    };
  }

  ClanApplicationModel copyWith({
    String? id,
    String? clanId,
    String? userUid,
    String? userName,
    String? userProfileImageUrl,
    ClanApplicationStatus? status,
    Timestamp? appliedAt,
    String? message,
    String? position,
    String? experience,
    String? contactInfo,
  }) {
    return ClanApplicationModel(
      id: id ?? this.id,
      clanId: clanId ?? this.clanId,
      userUid: userUid ?? this.userUid,
      userName: userName ?? this.userName,
      userProfileImageUrl: userProfileImageUrl ?? this.userProfileImageUrl,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      message: message ?? this.message,
      position: position ?? this.position,
      experience: experience ?? this.experience,
      contactInfo: contactInfo ?? this.contactInfo,
    );
  }
} 