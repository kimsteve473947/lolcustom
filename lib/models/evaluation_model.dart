import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// 평가 유형
enum EvaluationType {
  hostEvaluation, // 주최자 평가
  playerEvaluation, // 참가자 평가
}

// 평가 항목
class EvaluationItem {
  static const List<String> hostPositiveItems = [
    '시간 약속을 잘 지켰어요',
    '친절했어요',
    '규칙 설명이 명확했어요',
    '팀 밸런스가 좋았어요',
    '전반적으로 만족스러웠어요',
  ];

  static const List<String> hostNegativeItems = [
    '시간 지연이 있었어요',
    '운영이 혼란스러웠어요',
    '불친절했어요',
    '밸런스가 불공정했어요',
    '규칙이 불명확했어요',
  ];

  static const List<String> playerPositiveItems = [
    '시간 약속을 잘 지켰어요',
    '매너가 좋았어요',
    '실력이 좋았어요',
    '팀워크가 좋았어요',
    '게임을 재미있게 했어요',
  ];

  static const List<String> playerNegativeItems = [
    '시간 약속을 어겼어요',
    '매너가 나빴어요',
    '고의 트롤을 했어요',
    '욕설을 했어요',
    '게임을 포기했어요',
  ];

  // 점수 계산용 가중치
  static const Map<String, double> scoreWeights = {
    // 긍정 항목
    '시간 약속을 잘 지켰어요': 2.0,
    '친절했어요': 1.5,
    '규칙 설명이 명확했어요': 1.5,
    '팀 밸런스가 좋았어요': 2.0,
    '전반적으로 만족스러웠어요': 2.0,
    '매너가 좋았어요': 2.0,
    '실력이 좋았어요': 1.0,
    '팀워크가 좋았어요': 1.5,
    '게임을 재미있게 했어요': 1.0,
    
    // 부정 항목
    '시간 지연이 있었어요': -5.0,
    '운영이 혼란스러웠어요': -3.0,
    '불친절했어요': -4.0,
    '밸런스가 불공정했어요': -5.0,
    '규칙이 불명확했어요': -3.0,
    '시간 약속을 어겼어요': -5.0,
    '매너가 나빴어요': -5.0,
    '고의 트롤을 했어요': -10.0,
    '욕설을 했어요': -8.0,
    '게임을 포기했어요': -10.0,
  };
}

// 평가 모델
class EvaluationModel extends Equatable {
  final String id;
  final String tournamentId;
  final String fromUserId; // 평가자
  final String toUserId; // 피평가자
  final EvaluationType type;
  final List<String> positiveItems;
  final List<String> negativeItems;
  final bool reported;
  final String? reportReason;
  final double weight; // 평가자의 신뢰도 가중치
  final Timestamp createdAt;
  final double calculatedScore; // 계산된 점수

  const EvaluationModel({
    required this.id,
    required this.tournamentId,
    required this.fromUserId,
    required this.toUserId,
    required this.type,
    required this.positiveItems,
    required this.negativeItems,
    this.reported = false,
    this.reportReason,
    this.weight = 1.0,
    required this.createdAt,
    this.calculatedScore = 0.0,
  });

  factory EvaluationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return EvaluationModel(
      id: doc.id,
      tournamentId: data['tournamentId'] ?? '',
      fromUserId: data['fromUserId'] ?? '',
      toUserId: data['toUserId'] ?? '',
      type: data['type'] == 'hostEvaluation' 
          ? EvaluationType.hostEvaluation 
          : EvaluationType.playerEvaluation,
      positiveItems: List<String>.from(data['positiveItems'] ?? []),
      negativeItems: List<String>.from(data['negativeItems'] ?? []),
      reported: data['reported'] ?? false,
      reportReason: data['reportReason'],
      weight: (data['weight'] as num?)?.toDouble() ?? 1.0,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      calculatedScore: (data['calculatedScore'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tournamentId': tournamentId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'type': type == EvaluationType.hostEvaluation ? 'hostEvaluation' : 'playerEvaluation',
      'positiveItems': positiveItems,
      'negativeItems': negativeItems,
      'reported': reported,
      'reportReason': reportReason,
      'weight': weight,
      'createdAt': createdAt,
      'calculatedScore': calculatedScore,
    };
  }

  // 점수 계산
  double calculateScore() {
    double score = 0.0;
    
    // 긍정 항목 점수 계산
    for (final item in positiveItems) {
      score += EvaluationItem.scoreWeights[item] ?? 1.0;
    }
    
    // 부정 항목 점수 계산
    for (final item in negativeItems) {
      score += EvaluationItem.scoreWeights[item] ?? -3.0;
    }
    
    // 신고된 경우 추가 감점
    if (reported) {
      score -= 20.0;
    }
    
    return score * weight;
  }

  EvaluationModel copyWith({
    String? id,
    String? tournamentId,
    String? fromUserId,
    String? toUserId,
    EvaluationType? type,
    List<String>? positiveItems,
    List<String>? negativeItems,
    bool? reported,
    String? reportReason,
    double? weight,
    Timestamp? createdAt,
    double? calculatedScore,
  }) {
    return EvaluationModel(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      type: type ?? this.type,
      positiveItems: positiveItems ?? this.positiveItems,
      negativeItems: negativeItems ?? this.negativeItems,
      reported: reported ?? this.reported,
      reportReason: reportReason ?? this.reportReason,
      weight: weight ?? this.weight,
      createdAt: createdAt ?? this.createdAt,
      calculatedScore: calculatedScore ?? this.calculatedScore,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tournamentId,
    fromUserId,
    toUserId,
    type,
    positiveItems,
    negativeItems,
    reported,
    reportReason,
    weight,
    createdAt,
    calculatedScore,
  ];
}

// 신뢰 점수 정보
class TrustScoreInfo {
  final double score;
  final String statusText;
  final String colorCode;
  final String emoji;

  const TrustScoreInfo({
    required this.score,
    required this.statusText,
    required this.colorCode,
    required this.emoji,
  });

  factory TrustScoreInfo.fromScore(double score, {bool isHost = true}) {
    if (score >= 90) {
      return TrustScoreInfo(
        score: score,
        statusText: isHost ? '매우 안정적인 주최자예요' : '매우 신뢰할 수 있는 참가자예요',
        colorCode: '#4CAF50', // 초록색
        emoji: '🟢',
      );
    } else if (score >= 70) {
      return TrustScoreInfo(
        score: score,
        statusText: isHost ? '일반적인 수준의 진행자예요' : '일반적인 수준의 참가자예요',
        colorCode: '#FFC107', // 노란색
        emoji: '🟡',
      );
    } else if (score >= 50) {
      return TrustScoreInfo(
        score: score,
        statusText: isHost ? '최근 운영 평가가 낮아요' : '최근 평가가 낮아요',
        colorCode: '#FF9800', // 주황색
        emoji: '🟠',
      );
    } else {
      return TrustScoreInfo(
        score: score,
        statusText: isHost 
            ? '운영 신뢰도가 낮아 참여 제한될 수 있어요' 
            : '신뢰도가 낮아 참여 제한될 수 있어요',
        colorCode: '#F44336', // 빨간색
        emoji: '🔴',
      );
    }
  }
} 