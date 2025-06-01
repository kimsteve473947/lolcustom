import 'package:cloud_firestore/cloud_firestore.dart';

enum ApplicationStatus {
  pending,
  accepted,
  rejected,
  cancelled
}

class ApplicationModel {
  final String id;
  final String tournamentId;
  final String userUid;
  final String userName;
  final String? userProfileImageUrl;
  final String role;
  final int? userOvr;
  final ApplicationStatus status;
  final Timestamp appliedAt;
  final String? message;

  ApplicationModel({
    required this.id,
    required this.tournamentId,
    required this.userUid,
    required this.userName,
    this.userProfileImageUrl,
    required this.role,
    this.userOvr,
    this.status = ApplicationStatus.pending,
    required this.appliedAt,
    this.message,
  });

  factory ApplicationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ApplicationModel(
      id: doc.id,
      tournamentId: data['tournamentId'] ?? '',
      userUid: data['userUid'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userProfileImageUrl: data['userProfileImageUrl'],
      role: data['role'] ?? 'mid',
      userOvr: data['userOvr'],
      status: ApplicationStatus.values[data['status'] ?? 0],
      appliedAt: data['appliedAt'] ?? Timestamp.now(),
      message: data['message'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tournamentId': tournamentId,
      'userUid': userUid,
      'userName': userName,
      'userProfileImageUrl': userProfileImageUrl,
      'role': role,
      'userOvr': userOvr,
      'status': status.index,
      'appliedAt': appliedAt,
      'message': message,
    };
  }

  ApplicationModel copyWith({
    String? id,
    String? tournamentId,
    String? userUid,
    String? userName,
    String? userProfileImageUrl,
    String? role,
    int? userOvr,
    ApplicationStatus? status,
    Timestamp? appliedAt,
    String? message,
  }) {
    return ApplicationModel(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      userUid: userUid ?? this.userUid,
      userName: userName ?? this.userName,
      userProfileImageUrl: userProfileImageUrl ?? this.userProfileImageUrl,
      role: role ?? this.role,
      userOvr: userOvr ?? this.userOvr,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      message: message ?? this.message,
    );
  }
} 