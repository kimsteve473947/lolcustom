import 'package:cloud_firestore/cloud_firestore.dart';

/// 참가자 평가 모델
class ParticipantEvaluationModel {
  final String id;
  final String tournamentId;
  final String participantId;
  final String evaluatorId; // 주최자 ID
  final DateTime evaluatedAt;
  
  // 평가 항목들
  final bool onTimeAttendance; // 정시 출석
  final bool completedMatch; // 경기 완주
  final bool goodManner; // 매너 좋음
  final bool activeParticipation; // 적극 참여
  final bool followedRules; // 규칙 준수
  
  // 부정적 평가
  final bool noShow; // 무단 불참
  final bool late; // 지각 (10분 이상)
  final bool leftEarly; // 중도 이탈
  final bool badManner; // 비매너
  final bool trolling; // 트롤링
  
  // 추가 정보
  final String? comment; // 주최자 코멘트
  final int scoreChange; // 이 평가로 인한 점수 변화
  
  ParticipantEvaluationModel({
    required this.id,
    required this.tournamentId,
    required this.participantId,
    required this.evaluatorId,
    required this.evaluatedAt,
    required this.onTimeAttendance,
    required this.completedMatch,
    required this.goodManner,
    required this.activeParticipation,
    required this.followedRules,
    required this.noShow,
    required this.late,
    required this.leftEarly,
    required this.badManner,
    required this.trolling,
    this.comment,
    required this.scoreChange,
  });
  
  /// 점수 변화 계산
  static int calculateScoreChange({
    required bool onTimeAttendance,
    required bool completedMatch,
    required bool goodManner,
    required bool activeParticipation,
    required bool followedRules,
    required bool noShow,
    required bool late,
    required bool leftEarly,
    required bool badManner,
    required bool trolling,
  }) {
    int scoreChange = 0;
    
    // 긍정적 평가
    if (onTimeAttendance && completedMatch) {
      scoreChange += 3; // 정시 출석 + 경기 완주
    }
    if (goodManner || activeParticipation || followedRules) {
      scoreChange += 2; // 주최자로부터 긍정 평가
    }
    
    // 부정적 평가
    if (noShow) {
      scoreChange -= 15; // 무단 노쇼
    } else if (late) {
      scoreChange -= 5; // 10분 이상 지각
    }
    
    if (leftEarly) {
      scoreChange -= 7; // 경기 중도 이탈
    }
    
    if (badManner || trolling) {
      scoreChange -= 10; // 비매너 행위
    }
    
    return scoreChange;
  }
  
  factory ParticipantEvaluationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ParticipantEvaluationModel(
      id: doc.id,
      tournamentId: data['tournamentId'] ?? '',
      participantId: data['participantId'] ?? '',
      evaluatorId: data['evaluatorId'] ?? '',
      evaluatedAt: (data['evaluatedAt'] as Timestamp).toDate(),
      onTimeAttendance: data['onTimeAttendance'] ?? false,
      completedMatch: data['completedMatch'] ?? false,
      goodManner: data['goodManner'] ?? false,
      activeParticipation: data['activeParticipation'] ?? false,
      followedRules: data['followedRules'] ?? false,
      noShow: data['noShow'] ?? false,
      late: data['late'] ?? false,
      leftEarly: data['leftEarly'] ?? false,
      badManner: data['badManner'] ?? false,
      trolling: data['trolling'] ?? false,
      comment: data['comment'],
      scoreChange: data['scoreChange'] ?? 0,
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'tournamentId': tournamentId,
      'participantId': participantId,
      'evaluatorId': evaluatorId,
      'evaluatedAt': Timestamp.fromDate(evaluatedAt),
      'onTimeAttendance': onTimeAttendance,
      'completedMatch': completedMatch,
      'goodManner': goodManner,
      'activeParticipation': activeParticipation,
      'followedRules': followedRules,
      'noShow': noShow,
      'late': late,
      'leftEarly': leftEarly,
      'badManner': badManner,
      'trolling': trolling,
      'comment': comment,
      'scoreChange': scoreChange,
    };
  }
}

/// 참가자 신뢰도 히스토리
class ParticipantTrustHistory {
  final String tournamentId;
  final String tournamentTitle;
  final DateTime timestamp;
  final int scoreChange;
  final String reason;
  final String? evaluatorId;
  
  ParticipantTrustHistory({
    required this.tournamentId,
    required this.tournamentTitle,
    required this.timestamp,
    required this.scoreChange,
    required this.reason,
    this.evaluatorId,
  });
  
  factory ParticipantTrustHistory.fromMap(Map<String, dynamic> map) {
    return ParticipantTrustHistory(
      tournamentId: map['tournamentId'] ?? '',
      tournamentTitle: map['tournamentTitle'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      scoreChange: map['scoreChange'] ?? 0,
      reason: map['reason'] ?? '',
      evaluatorId: map['evaluatorId'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'tournamentTitle': tournamentTitle,
      'timestamp': Timestamp.fromDate(timestamp),
      'scoreChange': scoreChange,
      'reason': reason,
      'evaluatorId': evaluatorId,
    };
  }
} 