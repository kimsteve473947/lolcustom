import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum MatchingRequestStatus {
  pending,    // 요청 보냄
  accepted,   // 수락됨
  rejected,   // 거절됨
  cancelled,  // 취소됨
}

class MatchingRequestModel extends Equatable {
  final String id;
  final String fromUserId;        // 요청자
  final String fromUserNickname;
  final String? fromUserProfileUrl;
  final String toUserId;          // 대상자 (용병)
  final String toUserNickname;
  final String? toUserProfileUrl;
  final String? message;          // 요청 메시지
  final MatchingRequestStatus status;
  final Timestamp createdAt;
  final Timestamp? respondedAt;  // 응답 시간
  final String? tournamentId;     // 연결된 토너먼트 (선택)
  
  const MatchingRequestModel({
    required this.id,
    required this.fromUserId,
    required this.fromUserNickname,
    this.fromUserProfileUrl,
    required this.toUserId,
    required this.toUserNickname,
    this.toUserProfileUrl,
    this.message,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.tournamentId,
  });
  
  factory MatchingRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MatchingRequestModel(
      id: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      fromUserNickname: data['fromUserNickname'] ?? '',
      fromUserProfileUrl: data['fromUserProfileUrl'],
      toUserId: data['toUserId'] ?? '',
      toUserNickname: data['toUserNickname'] ?? '',
      toUserProfileUrl: data['toUserProfileUrl'],
      message: data['message'],
      status: MatchingRequestStatus.values[data['status'] ?? 0],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      respondedAt: data['respondedAt'],
      tournamentId: data['tournamentId'],
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'fromUserNickname': fromUserNickname,
      'fromUserProfileUrl': fromUserProfileUrl,
      'toUserId': toUserId,
      'toUserNickname': toUserNickname,
      'toUserProfileUrl': toUserProfileUrl,
      'message': message,
      'status': status.index,
      'createdAt': createdAt,
      'respondedAt': respondedAt,
      'tournamentId': tournamentId,
    };
  }
  
  MatchingRequestModel copyWith({
    String? id,
    String? fromUserId,
    String? fromUserNickname,
    String? fromUserProfileUrl,
    String? toUserId,
    String? toUserNickname,
    String? toUserProfileUrl,
    String? message,
    MatchingRequestStatus? status,
    Timestamp? createdAt,
    Timestamp? respondedAt,
    String? tournamentId,
  }) {
    return MatchingRequestModel(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserNickname: fromUserNickname ?? this.fromUserNickname,
      fromUserProfileUrl: fromUserProfileUrl ?? this.fromUserProfileUrl,
      toUserId: toUserId ?? this.toUserId,
      toUserNickname: toUserNickname ?? this.toUserNickname,
      toUserProfileUrl: toUserProfileUrl ?? this.toUserProfileUrl,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      tournamentId: tournamentId ?? this.tournamentId,
    );
  }
  
  @override
  List<Object?> get props => [
    id, fromUserId, fromUserNickname, fromUserProfileUrl,
    toUserId, toUserNickname, toUserProfileUrl,
    message, status, createdAt, respondedAt, tournamentId
  ];
} 