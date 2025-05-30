import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:uuid/uuid.dart';

class TournamentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collectionPath = 'tournaments';
  
  // 사용자 ID 가져오기
  String? get _userId => _auth.currentUser?.uid;
  
  // 모든 토너먼트 가져오기 (페이징 적용)
  Future<List<TournamentModel>> getTournaments({
    int limit = 10,
    DocumentSnapshot? startAfter,
    Map<String, dynamic>? filters,
  }) async {
    try {
      Query query = _firestore.collection(_collectionPath)
          .orderBy('startsAt', descending: false)  // 가까운 날짜순
          .where('status', isEqualTo: TournamentStatus.pending.index) // 대기중인 토너먼트만
          .limit(limit);
      
      // 시작점이 있는 경우 (페이징)
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      // 필터 적용
      if (filters != null) {
        // OVR 제한 필터
        if (filters.containsKey('ovrLimit')) {
          final ovrLimit = filters['ovrLimit'] as int?;
          if (ovrLimit != null) {
            query = query.where('ovrLimit', isLessThanOrEqualTo: ovrLimit);
          }
        }
        
        // 참가비 필터 (무료/유료)
        if (filters.containsKey('isPaid')) {
          final isPaid = filters['isPaid'] as bool?;
          if (isPaid != null) {
            query = query.where('isPaid', isEqualTo: isPaid);
          }
        }
        
        // 프리미엄 배지 필터
        if (filters.containsKey('premiumBadge')) {
          final premiumBadge = filters['premiumBadge'] as bool?;
          if (premiumBadge != null) {
            query = query.where('premiumBadge', isEqualTo: premiumBadge);
          }
        }
        
        // 날짜 범위 필터
        if (filters.containsKey('startDate') && filters.containsKey('endDate')) {
          final startDate = filters['startDate'] as DateTime?;
          final endDate = filters['endDate'] as DateTime?;
          
          if (startDate != null && endDate != null) {
            query = query.where('startsAt', 
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
              isLessThanOrEqualTo: Timestamp.fromDate(endDate),
            );
          }
        }
      }
      
      final snapshots = await query.get();
      
      // 결과가 비어있으면 빈 리스트 반환
      if (snapshots.docs.isEmpty) {
        return [];
      }
      
      // 결과를 TournamentModel 리스트로 변환
      return snapshots.docs
          .map((doc) => TournamentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting tournaments: $e');
      return [];
    }
  }
  
  // 토너먼트 상세 정보 가져오기
  Future<TournamentModel?> getTournamentById(String id) async {
    try {
      final doc = await _firestore.collection(_collectionPath).doc(id).get();
      
      if (!doc.exists) {
        return null;
      }
      
      return TournamentModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting tournament by id: $e');
      return null;
    }
  }
  
  // 사용자가 주최한 토너먼트 가져오기
  Future<List<TournamentModel>> getHostedTournaments() async {
    if (_userId == null) return [];
    
    try {
      final snapshots = await _firestore.collection(_collectionPath)
          .where('hostUid', isEqualTo: _userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      if (snapshots.docs.isEmpty) {
        return [];
      }
      
      return snapshots.docs
          .map((doc) => TournamentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting hosted tournaments: $e');
      return [];
    }
  }
  
  // 사용자가 참가한 토너먼트 가져오기
  Future<List<TournamentModel>> getJoinedTournaments() async {
    if (_userId == null) return [];
    
    try {
      final snapshots = await _firestore.collection(_collectionPath)
          .where('participantUids', arrayContains: _userId)
          .orderBy('startsAt', descending: true)
          .get();
      
      if (snapshots.docs.isEmpty) {
        return [];
      }
      
      return snapshots.docs
          .map((doc) => TournamentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting joined tournaments: $e');
      return [];
    }
  }
  
  // 토너먼트 생성
  Future<String?> createTournament(TournamentModel tournament) async {
    if (_userId == null) return null;
    
    try {
      // 문서 ID 생성
      final id = const Uuid().v4();
      
      // 호스트 ID와 생성 시간 설정
      final tournamentData = tournament.copyWith(
        id: id,
        hostUid: _userId,
        createdAt: DateTime.now(),
      ).toMap();
      
      // Firestore에 저장
      await _firestore.collection(_collectionPath).doc(id).set(tournamentData);
      
      return id;
    } catch (e) {
      debugPrint('Error creating tournament: $e');
      return null;
    }
  }
  
  // 토너먼트 업데이트
  Future<bool> updateTournament(TournamentModel tournament) async {
    if (_userId == null) return false;
    
    try {
      // 호스트만 수정 가능하도록 체크
      if (tournament.hostUid != _userId) {
        throw Exception('Only the host can update this tournament');
      }
      
      await _firestore.collection(_collectionPath)
          .doc(tournament.id)
          .update(tournament.toMap());
      
      return true;
    } catch (e) {
      debugPrint('Error updating tournament: $e');
      return false;
    }
  }
  
  // 토너먼트 취소
  Future<bool> cancelTournament(String id) async {
    if (_userId == null) return false;
    
    try {
      final doc = await _firestore.collection(_collectionPath).doc(id).get();
      
      if (!doc.exists) {
        return false;
      }
      
      final tournament = TournamentModel.fromFirestore(doc);
      
      // 호스트만 취소 가능하도록 체크
      if (tournament.hostUid != _userId) {
        throw Exception('Only the host can cancel this tournament');
      }
      
      // 토너먼트 상태를 취소로 변경
      await _firestore.collection(_collectionPath).doc(id).update({
        'status': TournamentStatus.cancelled.index,
      });
      
      return true;
    } catch (e) {
      debugPrint('Error cancelling tournament: $e');
      return false;
    }
  }
  
  // 토너먼트 참가 신청
  Future<bool> joinTournament(String tournamentId, String role) async {
    if (_userId == null) return false;
    
    try {
      final docRef = _firestore.collection(_collectionPath).doc(tournamentId);
      
      // 트랜잭션으로 원자적 업데이트 수행
      return await _firestore.runTransaction<bool>((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) {
          return false;
        }
        
        final tournament = TournamentModel.fromFirestore(doc);
        
        // 이미 가득 찬 경우
        if (tournament.isFull) {
          throw Exception('Tournament is already full');
        }
        
        // 해당 포지션이 가득 찬 경우
        if (!tournament.hasAvailableSlot(role)) {
          throw Exception('Selected position is already full');
        }
        
        // 이미 참가한 경우
        if (tournament.participantUids?.contains(_userId) == true) {
          throw Exception('You have already joined this tournament');
        }
        
        // 업데이트할 데이터 준비
        final updatedFilledSlots = Map<String, int>.from(tournament.filledSlotsByRole);
        updatedFilledSlots[role] = (updatedFilledSlots[role] ?? 0) + 1;
        
        final updatedParticipants = List<String>.from(tournament.participantUids ?? []);
        updatedParticipants.add(_userId!);
        
        // 데이터 업데이트
        transaction.update(docRef, {
          'filledSlotsByRole': updatedFilledSlots,
          'participantUids': updatedParticipants,
        });
        
        return true;
      });
    } catch (e) {
      debugPrint('Error joining tournament: $e');
      return false;
    }
  }
  
  // 토너먼트 참가 취소
  Future<bool> leaveTournament(String tournamentId, String role) async {
    if (_userId == null) return false;
    
    try {
      final docRef = _firestore.collection(_collectionPath).doc(tournamentId);
      
      // 트랜잭션으로 원자적 업데이트 수행
      return await _firestore.runTransaction<bool>((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) {
          return false;
        }
        
        final tournament = TournamentModel.fromFirestore(doc);
        
        // 참가자가 아닌 경우
        if (tournament.participantUids?.contains(_userId) != true) {
          throw Exception('You are not a participant of this tournament');
        }
        
        // 해당 포지션이 비어있는 경우
        final filled = tournament.filledSlotsByRole[role] ?? 0;
        if (filled <= 0) {
          throw Exception('This position is already empty');
        }
        
        // 업데이트할 데이터 준비
        final updatedFilledSlots = Map<String, int>.from(tournament.filledSlotsByRole);
        updatedFilledSlots[role] = (updatedFilledSlots[role] ?? 1) - 1;
        
        final updatedParticipants = List<String>.from(tournament.participantUids ?? []);
        updatedParticipants.remove(_userId);
        
        // 데이터 업데이트
        transaction.update(docRef, {
          'filledSlotsByRole': updatedFilledSlots,
          'participantUids': updatedParticipants,
        });
        
        return true;
      });
    } catch (e) {
      debugPrint('Error leaving tournament: $e');
      return false;
    }
  }
  
  // 토너먼트 완료 처리
  Future<bool> completeTournament(String id) async {
    if (_userId == null) return false;
    
    try {
      final doc = await _firestore.collection(_collectionPath).doc(id).get();
      
      if (!doc.exists) {
        return false;
      }
      
      final tournament = TournamentModel.fromFirestore(doc);
      
      // 호스트만 완료 처리 가능하도록 체크
      if (tournament.hostUid != _userId) {
        throw Exception('Only the host can complete this tournament');
      }
      
      // 토너먼트 상태를 완료로 변경
      await _firestore.collection(_collectionPath).doc(id).update({
        'status': TournamentStatus.completed.index,
      });
      
      return true;
    } catch (e) {
      debugPrint('Error completing tournament: $e');
      return false;
    }
  }
  
  // 토너먼트 스트림 (실시간 업데이트)
  Stream<TournamentModel?> getTournamentStream(String id) {
    return _firestore.collection(_collectionPath)
        .doc(id)
        .snapshots()
        .map((doc) {
          if (!doc.exists) {
            return null;
          }
          return TournamentModel.fromFirestore(doc);
        });
  }
} 