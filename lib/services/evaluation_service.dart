import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/models/evaluation_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';

class EvaluationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 평가 생성
  Future<void> createEvaluation({
    required String tournamentId,
    required String fromUserId,
    required String toUserId,
    required EvaluationType type,
    required List<String> positiveItems,
    required List<String> negativeItems,
    bool reported = false,
    String? reportReason,
  }) async {
    try {
      // 평가자의 신뢰도 가져오기
      final evaluatorDoc = await _firestore.collection('users').doc(fromUserId).get();
      final evaluator = UserModel.fromFirestore(evaluatorDoc);
      
      // 평가자의 신뢰도에 따른 가중치 계산
      double weight = _calculateWeight(
        type == EvaluationType.hostEvaluation 
          ? evaluator.playerScore 
          : evaluator.hostScore
      );
      
      // 평가 문서 생성
      final evaluationRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('evaluations')
          .doc();
      
      final evaluation = EvaluationModel(
        id: evaluationRef.id,
        tournamentId: tournamentId,
        fromUserId: fromUserId,
        toUserId: toUserId,
        type: type,
        positiveItems: positiveItems,
        negativeItems: negativeItems,
        reported: reported,
        reportReason: reportReason,
        weight: weight,
        createdAt: Timestamp.now(),
      );
      
      // 점수 계산
      final calculatedScore = evaluation.calculateScore();
      
      await evaluationRef.set(
        evaluation.copyWith(calculatedScore: calculatedScore).toFirestore()
      );
      
      // 피평가자의 점수 업데이트
      await _updateUserTrustScore(toUserId, type == EvaluationType.hostEvaluation);
      
    } catch (e) {
      print('Error creating evaluation: $e');
      throw e;
    }
  }
  
  // 평가자의 신뢰도에 따른 가중치 계산
  double _calculateWeight(double trustScore) {
    if (trustScore >= 90) {
      return 1.2;
    } else if (trustScore < 60) {
      return 0.7;
    } else {
      return 1.0;
    }
  }
  
  // 사용자의 신뢰 점수 업데이트
  Future<void> _updateUserTrustScore(String userId, bool isHost) async {
    try {
      // 최근 10개 경기의 평가 가져오기
      final evaluations = await _getRecentEvaluations(userId, isHost, limit: 10);
      
      if (evaluations.isEmpty) return;
      
      // 이상치 제거 (상위/하위 10%)
      final scores = evaluations.map((e) => e.calculatedScore).toList()..sort();
      final outlierCount = (scores.length * 0.1).ceil();
      
      List<double> filteredScores = scores;
      if (scores.length > 10) {
        filteredScores = scores.sublist(outlierCount, scores.length - outlierCount);
      }
      
      // 가중 평균 계산 (최근 경기일수록 가중치 높음)
      double weightedSum = 0;
      double weightSum = 0;
      
      for (int i = 0; i < filteredScores.length; i++) {
        final weight = pow(0.9, filteredScores.length - i - 1);
        weightedSum += filteredScores[i] * weight;
        weightSum += weight;
      }
      
      final newScore = (weightedSum / weightSum).clamp(0, 100);
      
      // 평가 참여율 계산
      final totalGames = await _getTotalGamesCount(userId, isHost);
      final evaluatedGames = await _getEvaluatedGamesCount(userId, isHost);
      final evaluationRate = totalGames > 0 ? evaluatedGames / totalGames : 0.0;
      
      // 사용자 문서 업데이트
      await _firestore.collection('users').doc(userId).update({
        isHost ? 'hostScore' : 'playerScore': newScore,
        'evaluationRate': evaluationRate,
        'lastEvaluated': Timestamp.now(),
      });
      
    } catch (e) {
      print('Error updating trust score: $e');
      throw e;
    }
  }
  
  // 최근 평가 가져오기
  Future<List<EvaluationModel>> _getRecentEvaluations(
    String userId, 
    bool isHost, 
    {int limit = 10}
  ) async {
    try {
      // 모든 토너먼트에서 해당 사용자에 대한 평가 검색
      final tournamentsQuery = await _firestore
          .collection('tournaments')
          .orderBy('createdAt', descending: true)
          .limit(50) // 최근 50개 토너먼트만 확인
          .get();
      
      List<EvaluationModel> allEvaluations = [];
      
      for (final tournamentDoc in tournamentsQuery.docs) {
        final evaluationsQuery = await tournamentDoc.reference
            .collection('evaluations')
            .where('toUserId', isEqualTo: userId)
            .where('type', isEqualTo: isHost ? 'hostEvaluation' : 'playerEvaluation')
            .get();
        
        for (final evalDoc in evaluationsQuery.docs) {
          allEvaluations.add(EvaluationModel.fromFirestore(evalDoc));
        }
      }
      
      // 최신순 정렬 및 제한
      allEvaluations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return allEvaluations.take(limit).toList();
      
    } catch (e) {
      print('Error getting recent evaluations: $e');
      return [];
    }
  }
  
  // 총 게임 수 가져오기
  Future<int> _getTotalGamesCount(String userId, bool isHost) async {
    try {
      QuerySnapshot<Map<String, dynamic>> query;
      if (isHost) {
        query = await _firestore
            .collection('tournaments')
            .where('hostId', isEqualTo: userId)
            .where('status', isEqualTo: 'completed')
            .get();
      } else {
        query = await _firestore
            .collection('tournaments')
            .where('participants', arrayContains: userId)
            .where('status', isEqualTo: 'completed')
            .get();
      }
      
      return query.docs.length;
    } catch (e) {
      print('Error getting total games count: $e');
      return 0;
    }
  }
  
  // 평가한 게임 수 가져오기
  Future<int> _getEvaluatedGamesCount(String userId, bool isHost) async {
    try {
      int count = 0;
      
      // 완료된 토너먼트 중 평가한 것 찾기
      QuerySnapshot<Map<String, dynamic>> tournamentsQuery;
      if (isHost) {
        tournamentsQuery = await _firestore
            .collection('tournaments')
            .where('hostId', isEqualTo: userId)
            .where('status', isEqualTo: 'completed')
            .get();
      } else {
        tournamentsQuery = await _firestore
            .collection('tournaments')
            .where('participants', arrayContains: userId)
            .where('status', isEqualTo: 'completed')
            .get();
      }
      
      for (final tournamentDoc in tournamentsQuery.docs) {
        final evaluationQuery = await tournamentDoc.reference
            .collection('evaluations')
            .where('fromUserId', isEqualTo: userId)
            .limit(1)
            .get();
        
        if (evaluationQuery.docs.isNotEmpty) {
          count++;
        }
      }
      
      return count;
    } catch (e) {
      print('Error getting evaluated games count: $e');
      return 0;
    }
  }
  
  // 토너먼트에 대한 평가 여부 확인
  Future<bool> hasEvaluated(String tournamentId, String userId) async {
    try {
      final query = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('evaluations')
          .where('fromUserId', isEqualTo: userId)
          .limit(1)
          .get();
      
      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking evaluation status: $e');
      return false;
    }
  }
  
  // 평가 가능한 토너먼트 목록 가져오기
  Future<List<Map<String, dynamic>>> getPendingEvaluations(String userId) async {
    try {
      List<Map<String, dynamic>> pendingEvaluations = [];
      
      // 24시간 이내 완료된 토너먼트 찾기
      final cutoffTime = Timestamp.fromDate(
        DateTime.now().subtract(Duration(hours: 24))
      );
      
      // 주최한 토너먼트
      final hostedQuery = await _firestore
          .collection('tournaments')
          .where('hostId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThan: cutoffTime)
          .get();
      
      for (final doc in hostedQuery.docs) {
        final hasEval = await hasEvaluated(doc.id, userId);
        if (!hasEval) {
          pendingEvaluations.add({
            'tournamentId': doc.id,
            'tournamentName': doc.data()['name'],
            'isHost': true,
            'completedAt': doc.data()['completedAt'],
          });
        }
      }
      
      // 참가한 토너먼트
      final participatedQuery = await _firestore
          .collection('tournaments')
          .where('participants', arrayContains: userId)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThan: cutoffTime)
          .get();
      
      for (final doc in participatedQuery.docs) {
        final hasEval = await hasEvaluated(doc.id, userId);
        if (!hasEval) {
          pendingEvaluations.add({
            'tournamentId': doc.id,
            'tournamentName': doc.data()['name'],
            'isHost': false,
            'completedAt': doc.data()['completedAt'],
          });
        }
      }
      
      return pendingEvaluations;
    } catch (e) {
      print('Error getting pending evaluations: $e');
      return [];
    }
  }
  
  // 악의적 평가 패턴 감지
  Future<bool> detectMaliciousPattern(String userId) async {
    try {
      // 최근 5개 평가 확인
      final recentEvals = await _getRecentEvaluationsByUser(userId, limit: 5);
      
      if (recentEvals.length < 5) return false;
      
      // 모두 부정적이거나 모두 신고인 경우
      final allNegative = recentEvals.every((e) => 
        e.negativeItems.length > 3 && e.positiveItems.isEmpty
      );
      final allReported = recentEvals.every((e) => e.reported);
      
      return allNegative || allReported;
    } catch (e) {
      print('Error detecting malicious pattern: $e');
      return false;
    }
  }
  
  // 사용자가 작성한 최근 평가 가져오기
  Future<List<EvaluationModel>> _getRecentEvaluationsByUser(
    String userId, 
    {int limit = 5}
  ) async {
    try {
      List<EvaluationModel> evaluations = [];
      
      // 최근 토너먼트에서 해당 사용자가 작성한 평가 찾기
      final tournamentsQuery = await _firestore
          .collection('tournaments')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      
      for (final tournamentDoc in tournamentsQuery.docs) {
        final evalsQuery = await tournamentDoc.reference
            .collection('evaluations')
            .where('fromUserId', isEqualTo: userId)
            .get();
        
        for (final evalDoc in evalsQuery.docs) {
          evaluations.add(EvaluationModel.fromFirestore(evalDoc));
          if (evaluations.length >= limit) break;
        }
        
        if (evaluations.length >= limit) break;
      }
      
      return evaluations;
    } catch (e) {
      print('Error getting user evaluations: $e');
      return [];
    }
  }
} 