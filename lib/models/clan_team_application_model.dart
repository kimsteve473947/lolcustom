import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum ClanTeamApplicationStatus {
  pending,   // 대기 중
  accepted,  // 승인됨
  rejected,  // 거절됨
  cancelled, // 취소됨
}

class ClanTeamMember extends Equatable {
  final String userId;
  final String nickname;
  final String? profileImageUrl;
  final String role; // top, jungle, mid, adc, support
  final String? riotId;
  final String? tier;

  const ClanTeamMember({
    required this.userId,
    required this.nickname,
    this.profileImageUrl,
    required this.role,
    this.riotId,
    this.tier,
  });

  @override
  List<Object?> get props => [userId, nickname, profileImageUrl, role, riotId, tier];

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'role': role,
      'riotId': riotId,
      'tier': tier,
    };
  }

  factory ClanTeamMember.fromMap(Map<String, dynamic> map) {
    return ClanTeamMember(
      userId: map['userId'] ?? '',
      nickname: map['nickname'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      role: map['role'] ?? '',
      riotId: map['riotId'],
      tier: map['tier'],
    );
  }

  ClanTeamMember copyWith({
    String? userId,
    String? nickname,
    String? profileImageUrl,
    String? role,
    String? riotId,
    String? tier,
  }) {
    return ClanTeamMember(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      riotId: riotId ?? this.riotId,
      tier: tier ?? this.tier,
    );
  }
}

class ClanTeamApplicationModel extends Equatable {
  final String id;
  final String tournamentId;
  final String clanId;
  final String clanName;
  final String teamCaptainId;     // 팀 주장 (신청자)
  final String teamCaptainName;
  final String? teamCaptainProfileImageUrl;
  final String teamName;          // 팀 이름 (클랜명 또는 별도 설정)
  final List<ClanTeamMember> teamMembers; // 5명의 팀원
  final String? message;          // 신청 메시지
  final ClanTeamApplicationStatus status;
  final Timestamp appliedAt;
  final Timestamp? processedAt;   // 승인/거절 처리 시간
  final String? processedBy;      // 승인/거절 처리자
  final String? rejectionReason;  // 거절 사유

  const ClanTeamApplicationModel({
    required this.id,
    required this.tournamentId,
    required this.clanId,
    required this.clanName,
    required this.teamCaptainId,
    required this.teamCaptainName,
    this.teamCaptainProfileImageUrl,
    required this.teamName,
    required this.teamMembers,
    this.message,
    required this.status,
    required this.appliedAt,
    this.processedAt,
    this.processedBy,
    this.rejectionReason,
  });

  @override
  List<Object?> get props => [
    id, tournamentId, clanId, clanName, teamCaptainId, teamCaptainName,
    teamCaptainProfileImageUrl, teamName, teamMembers, message, status,
    appliedAt, processedAt, processedBy, rejectionReason
  ];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tournamentId': tournamentId,
      'clanId': clanId,
      'clanName': clanName,
      'teamCaptainId': teamCaptainId,
      'teamCaptainName': teamCaptainName,
      'teamCaptainProfileImageUrl': teamCaptainProfileImageUrl,
      'teamName': teamName,
      'teamMembers': teamMembers.map((member) => member.toMap()).toList(),
      'message': message,
      'status': status.index,
      'appliedAt': appliedAt,
      'processedAt': processedAt,
      'processedBy': processedBy,
      'rejectionReason': rejectionReason,
    };
  }

  factory ClanTeamApplicationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // teamMembers 리스트 변환
    List<ClanTeamMember> teamMembers = [];
    if (data['teamMembers'] != null && data['teamMembers'] is List) {
      teamMembers = (data['teamMembers'] as List)
          .map((memberData) => ClanTeamMember.fromMap(memberData as Map<String, dynamic>))
          .toList();
    }

    // status 변환
    ClanTeamApplicationStatus status;
    try {
      final statusIndex = data['status'] as int? ?? 0;
      if (statusIndex >= 0 && statusIndex < ClanTeamApplicationStatus.values.length) {
        status = ClanTeamApplicationStatus.values[statusIndex];
      } else {
        status = ClanTeamApplicationStatus.pending;
      }
    } catch (e) {
      status = ClanTeamApplicationStatus.pending;
    }

    return ClanTeamApplicationModel(
      id: doc.id,
      tournamentId: data['tournamentId'] ?? '',
      clanId: data['clanId'] ?? '',
      clanName: data['clanName'] ?? '',
      teamCaptainId: data['teamCaptainId'] ?? '',
      teamCaptainName: data['teamCaptainName'] ?? '',
      teamCaptainProfileImageUrl: data['teamCaptainProfileImageUrl'],
      teamName: data['teamName'] ?? '',
      teamMembers: teamMembers,
      message: data['message'],
      status: status,
      appliedAt: data['appliedAt'] ?? Timestamp.now(),
      processedAt: data['processedAt'],
      processedBy: data['processedBy'],
      rejectionReason: data['rejectionReason'],
    );
  }

  ClanTeamApplicationModel copyWith({
    String? id,
    String? tournamentId,
    String? clanId,
    String? clanName,
    String? teamCaptainId,
    String? teamCaptainName,
    String? teamCaptainProfileImageUrl,
    String? teamName,
    List<ClanTeamMember>? teamMembers,
    String? message,
    ClanTeamApplicationStatus? status,
    Timestamp? appliedAt,
    Timestamp? processedAt,
    String? processedBy,
    String? rejectionReason,
  }) {
    return ClanTeamApplicationModel(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      clanId: clanId ?? this.clanId,
      clanName: clanName ?? this.clanName,
      teamCaptainId: teamCaptainId ?? this.teamCaptainId,
      teamCaptainName: teamCaptainName ?? this.teamCaptainName,
      teamCaptainProfileImageUrl: teamCaptainProfileImageUrl ?? this.teamCaptainProfileImageUrl,
      teamName: teamName ?? this.teamName,
      teamMembers: teamMembers ?? this.teamMembers,
      message: message ?? this.message,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      processedAt: processedAt ?? this.processedAt,
      processedBy: processedBy ?? this.processedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  // 팀원 역할별 조회
  ClanTeamMember? getMemberByRole(String role) {
    try {
      return teamMembers.firstWhere((member) => member.role == role);
    } catch (e) {
      return null;
    }
  }

  // 모든 역할이 채워져 있는지 확인
  bool get isTeamComplete {
    final requiredRoles = ['top', 'jungle', 'mid', 'adc', 'support'];
    return requiredRoles.every((role) => getMemberByRole(role) != null);
  }

  // 팀원 ID 목록
  List<String> get memberIds {
    return teamMembers.map((member) => member.userId).toList();
  }
} 