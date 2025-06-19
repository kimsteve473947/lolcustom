import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/models/participant_evaluation_model.dart';

/// 참가자 신뢰도 점수 관리자
class ParticipantTrustScoreManager {
  static final ParticipantTrustScoreManager _instance = ParticipantTrustScoreManager._internal();
  factory ParticipantTrustScoreManager() => _instance;
  ParticipantTrustScoreManager._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 상수 정의
  static const double DEFAULT_SCORE = 70.0;
  static const double MIN_SCORE = 1.0;
  static const double MAX_SCORE = 100.0;
  static const double AVERAGE_BASELINE = 60.0;
  static const double RESTRICTION_THRESHOLD = 49.0;
  static const int RECENT_GAMES_COUNT = 10;
  static const double DECAY_FACTOR = 0.9;
  
  // 연속 클린 참여 보너스
  static const int CLEAN_STREAK_BONUS = 5;
  static const int CLEAN_STREAK_REQUIRED = 3;
  
  // 명예 참가자 조건
  static const int HONOR_PARTICIPANT_GAMES = 10;
  
  /// 참가자 평가 제출
  Future<void> submitParticipantEvaluation({
    required String tournamentId,
    required String tournamentTitle,
    required String participantId,
    required String evaluatorId,
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
    String? comment,
  }) async {
    try {
      // 중복 평가 확인
      final existingEval = await _firestore
          .collection('participant_evaluations')
          .where('tournamentId', isEqualTo: tournamentId)
          .where('participantId', isEqualTo: participantId)
          .where('evaluatorId', isEqualTo: evaluatorId)
          .get();
      
      if (existingEval.docs.isNotEmpty) {
        throw Exception('이미 평가를 완료했습니다.');
      }
      
      // 점수 변화 계산
      final scoreChange = ParticipantEvaluationModel.calculateScoreChange(
        onTimeAttendance: onTimeAttendance,
        completedMatch: completedMatch,
        goodManner: goodManner,
        activeParticipation: activeParticipation,
        followedRules: followedRules,
        noShow: noShow,
        late: late,
        leftEarly: leftEarly,
        badManner: badManner,
        trolling: trolling,
      );
      
      // 평가 저장
      final evaluationRef = _firestore.collection('participant_evaluations').doc();
      final evaluation = ParticipantEvaluationModel(
        id: evaluationRef.id,
        tournamentId: tournamentId,
        participantId: participantId,
        evaluatorId: evaluatorId,
        evaluatedAt: DateTime.now(),
        onTimeAttendance: onTimeAttendance,
        completedMatch: completedMatch,
        goodManner: goodManner,
        activeParticipation: activeParticipation,
        followedRules: followedRules,
        noShow: noShow,
        late: late,
        leftEarly: leftEarly,
        badManner: badManner,
        trolling: trolling,
        comment: comment,
        scoreChange: scoreChange,
      );
      
      // 트랜잭션으로 평가 저장 및 점수 업데이트
      await _firestore.runTransaction((transaction) async {
        // 평가 저장
        transaction.set(evaluationRef, evaluation.toFirestore());
        
        // 사용자 문서 가져오기
        final userRef = _firestore.collection('users').doc(participantId);
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw Exception('사용자를 찾을 수 없습니다.');
        }
        
        final userData = userDoc.data()!;
        final currentHistory = List<Map<String, dynamic>>.from(
          userData['participantTrustHistory'] ?? []
        );
        
        // 히스토리에 추가
        final reason = _getReasonText(
          onTimeAttendance: onTimeAttendance,
          completedMatch: completedMatch,
          goodManner: goodManner,
          noShow: noShow,
          late: late,
          leftEarly: leftEarly,
          badManner: badManner,
          trolling: trolling,
        );
        
        final newHistory = ParticipantTrustHistory(
          tournamentId: tournamentId,
          tournamentTitle: tournamentTitle,
          timestamp: DateTime.now(),
          scoreChange: scoreChange,
          reason: reason,
          evaluatorId: evaluatorId,
        );
        
        currentHistory.insert(0, newHistory.toMap());
        
        // 최근 10개만 유지
        if (currentHistory.length > RECENT_GAMES_COUNT) {
          currentHistory.removeRange(RECENT_GAMES_COUNT, currentHistory.length);
        }
        
        // 새로운 점수 계산
        final newScore = _calculateWeightedScore(currentHistory);
        
        // 연속 클린 참여 확인
        final cleanStreak = _checkCleanStreak(currentHistory);
        if (cleanStreak >= CLEAN_STREAK_REQUIRED) {
          currentHistory[0]['scoreChange'] = 
              (currentHistory[0]['scoreChange'] as int) + CLEAN_STREAK_BONUS;
          currentHistory[0]['reason'] = 
              '${currentHistory[0]['reason']} + 연속 클린 참여 보너스';
        }
        
        // 사용자 문서 업데이트
        transaction.update(userRef, {
          'playerScore': newScore,
          'participantTrustHistory': currentHistory,
          'lastParticipantEvaluation': FieldValue.serverTimestamp(),
          'cleanStreak': cleanStreak,
        });
      });
      
      print('참가자 평가 완료: $participantId, 점수 변화: $scoreChange');
    } catch (e) {
      print('참가자 평가 실패: $e');
      rethrow;
    }
  }
  
  /// 가중 평균 점수 계산
  double _calculateWeightedScore(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return DEFAULT_SCORE;
    
    double weightedSum = DEFAULT_SCORE;
    double totalWeight = 1.0;
    
    for (int i = 0; i < history.length && i < RECENT_GAMES_COUNT; i++) {
      final scoreChange = (history[i]['scoreChange'] as num).toDouble();
      final weight = pow(DECAY_FACTOR, i).toDouble();
      
      weightedSum += scoreChange * weight;
      totalWeight += weight;
    }
    
    final finalScore = weightedSum / totalWeight;
    return finalScore.clamp(MIN_SCORE, MAX_SCORE);
  }
  
  /// 연속 클린 참여 확인
  int _checkCleanStreak(List<Map<String, dynamic>> history) {
    int streak = 0;
    
    for (final record in history) {
      final scoreChange = record['scoreChange'] as int;
      if (scoreChange >= 0) {
        streak++;
      } else {
        break;
      }
    }
    
    return streak;
  }
  
  /// 평가 이유 텍스트 생성
  String _getReasonText({
    required bool onTimeAttendance,
    required bool completedMatch,
    required bool goodManner,
    required bool noShow,
    required bool late,
    required bool leftEarly,
    required bool badManner,
    required bool trolling,
  }) {
    final reasons = <String>[];
    
    // 부정적 평가 우선
    if (noShow) {
      reasons.add('무단 노쇼');
    } else if (late) {
      reasons.add('지각');
    }
    
    if (leftEarly) {
      reasons.add('중도 이탈');
    }
    
    if (badManner || trolling) {
      reasons.add('비매너 행위');
    }
    
    // 긍정적 평가
    if (reasons.isEmpty) {
      if (onTimeAttendance && completedMatch) {
        reasons.add('정상 참여');
      }
      if (goodManner) {
        reasons.add('매너 좋음');
      }
    }
    
    return reasons.isEmpty ? '평가 없음' : reasons.join(', ');
  }
  
  /// 참가자 신뢰도 정보 조회
  Future<ParticipantTrustInfo> getParticipantTrustInfo(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return ParticipantTrustInfo(
          score: DEFAULT_SCORE,
          history: [],
          cleanStreak: 0,
          isHonorParticipant: false,
        );
      }
      
      final userData = userDoc.data()!;
      final score = (userData['playerScore'] as num?)?.toDouble() ?? DEFAULT_SCORE;
      final historyData = List<Map<String, dynamic>>.from(
        userData['participantTrustHistory'] ?? []
      );
      final cleanStreak = userData['cleanStreak'] ?? 0;
      
      // 히스토리 변환
      final history = historyData
          .map((h) => ParticipantTrustHistory.fromMap(h))
          .toList();
      
      // 명예 참가자 확인
      final isHonorParticipant = _checkHonorParticipant(history);
      
      return ParticipantTrustInfo(
        score: score,
        history: history,
        cleanStreak: cleanStreak,
        isHonorParticipant: isHonorParticipant,
      );
    } catch (e) {
      print('참가자 신뢰도 조회 실패: $e');
      return ParticipantTrustInfo(
        score: DEFAULT_SCORE,
        history: [],
        cleanStreak: 0,
        isHonorParticipant: false,
      );
    }
  }
  
  /// 명예 참가자 확인
  bool _checkHonorParticipant(List<ParticipantTrustHistory> history) {
    if (history.length < HONOR_PARTICIPANT_GAMES) return false;
    
    // 최근 10경기 모두 클린한지 확인
    for (int i = 0; i < HONOR_PARTICIPANT_GAMES && i < history.length; i++) {
      if (history[i].scoreChange < 0) {
        return false;
      }
    }
    
    return true;
  }
  
  /// 토너먼트 자동 필터 가능 여부 확인
  bool canAutoAccept(double participantScore, double requiredScore) {
    return participantScore >= requiredScore;
  }
  
  /// 참가 제한 여부 확인
  bool isRestricted(double participantScore) {
    return participantScore <= RESTRICTION_THRESHOLD;
  }
}

/// 참가자 신뢰도 정보
class ParticipantTrustInfo {
  final double score;
  final List<ParticipantTrustHistory> history;
  final int cleanStreak;
  final bool isHonorParticipant;
  
  ParticipantTrustInfo({
    required this.score,
    required this.history,
    required this.cleanStreak,
    required this.isHonorParticipant,
  });
  
  String get statusText {
    if (score >= 90) return '매우 신뢰할 수 있는 참가자예요';
    if (score >= 70) return '일반적인 참가자입니다';
    if (score >= 50) return '최근 평가가 낮아요';
    return '주의가 필요한 유저입니다';
  }
  
  String get shortStatusText {
    if (score >= 90) return '우수';
    if (score >= 70) return '일반';
    if (score >= 50) return '주의';
    return '위험';
  }
} 