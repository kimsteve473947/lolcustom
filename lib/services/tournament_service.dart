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
  
  // 콜렉션 참조
  CollectionReference get _tournamentsRef => _firestore.collection(_collectionPath);
  
  // 모든 토너먼트 조회 (최신순)
  Stream<List<TournamentModel>> getTournamentsStream() {
    return _tournamentsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TournamentModel.fromFirestore(doc))
              .toList();
        });
  }
  
  // 상태별 토너먼트 조회
  Stream<List<TournamentModel>> getTournamentsByStatusStream(TournamentStatus status) {
    return _tournamentsRef
        .where('status', isEqualTo: status.index)
        .orderBy('startsAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TournamentModel.fromFirestore(doc))
              .toList();
        });
  }
  
  // 활성 상태 토너먼트 조회 (시작 시간 순)
  Stream<List<TournamentModel>> getActiveTournamentsStream() {
    return _tournamentsRef
        .where('status', isEqualTo: TournamentStatus.open.index)
        .orderBy('startsAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TournamentModel.fromFirestore(doc))
              .toList();
        });
  }
  
  // 특정 토너먼트 조회
  Stream<TournamentModel?> getTournamentStream(String id) {
    return _tournamentsRef
        .doc(id)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return TournamentModel.fromFirestore(doc);
          }
          return null;
        });
  }
  
  // 특정 토너먼트 데이터 가져오기 (Future)
  Future<TournamentModel?> getTournament(String id) async {
    try {
      final doc = await _tournamentsRef.doc(id).get();
      if (doc.exists) {
        return TournamentModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting tournament: $e');
      rethrow;
    }
  }
  
  // 토너먼트 목록 가져오기 (Future 버전, 필터링 기능 포함)
  Future<List<TournamentModel>> getTournaments({
    int? limit,
    DocumentSnapshot? startAfter,
    Map<String, dynamic>? filters,
  }) async {
    try {
      Query query = _tournamentsRef.orderBy('startsAt', descending: false);
      
      // 필터 적용
      if (filters != null) {
        // 유료/무료 필터
        if (filters['isPaid'] != null) {
          query = query.where('isPaid', isEqualTo: filters['isPaid']);
        }
        
        // 날짜 범위 필터
        if (filters['startDate'] != null && filters['endDate'] != null) {
          query = query.where('startsAt', 
            isGreaterThanOrEqualTo: Timestamp.fromDate(filters['startDate']),
            isLessThanOrEqualTo: Timestamp.fromDate(filters['endDate'])
          );
        }
        
        // 프리미엄 필터
        if (filters['premiumBadge'] != null) {
          query = query.where('premiumBadge', isEqualTo: filters['premiumBadge']);
        }
      }
      
      // 페이지네이션
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      if (limit != null) {
        query = query.limit(limit);
      }
      
      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => TournamentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting tournaments: $e');
      rethrow;
    }
  }
  
  // 내가 주최한 토너먼트 조회
  Stream<List<TournamentModel>> getMyHostedTournamentsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);
    
    return _tournamentsRef
        .where('hostId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TournamentModel.fromFirestore(doc))
              .toList();
        });
  }
  
  // 내가 참가한 토너먼트 조회
  Stream<List<TournamentModel>> getMyJoinedTournamentsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);
    
    return _tournamentsRef
        .where('participants', arrayContains: userId)
        .orderBy('startsAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TournamentModel.fromFirestore(doc))
              .toList();
        });
  }
  
  // 토너먼트 생성
  Future<String> createTournament(TournamentModel tournament) async {
    try {
      final docRef = await _tournamentsRef.add(tournament.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error creating tournament: $e');
      rethrow;
    }
  }
  
  // 토너먼트 업데이트
  Future<void> updateTournament(TournamentModel tournament) async {
    try {
      await _tournamentsRef.doc(tournament.id).update(tournament.toFirestore());
    } catch (e) {
      print('Error updating tournament: $e');
      rethrow;
    }
  }
  
  // 토너먼트 삭제
  Future<void> deleteTournament(String id) async {
    try {
      await _tournamentsRef.doc(id).delete();
    } catch (e) {
      print('Error deleting tournament: $e');
      rethrow;
    }
  }
  
  // 토너먼트 참가
  Future<void> joinTournament(String tournamentId, String position) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('로그인이 필요합니다.');
    
    try {
      await _firestore.runTransaction((transaction) async {
        // 토너먼트 문서 가져오기
        final docRef = _tournamentsRef.doc(tournamentId);
        final docSnapshot = await transaction.get(docRef);
        
        if (!docSnapshot.exists) {
          throw Exception('토너먼트를 찾을 수 없습니다.');
        }
        
        // 토너먼트 모델로 변환
        final tournament = TournamentModel.fromFirestore(docSnapshot);
        
        // 이미 참가했는지 확인
        if (tournament.participants.contains(userId)) {
          throw Exception('이미 참가 중인 토너먼트입니다.');
        }
        
        // 참가 가능한지 확인
        if (!tournament.canJoin(position)) {
          throw Exception('해당 포지션은 이미 가득 찼거나 참가할 수 없습니다.');
        }
        
        // 필드 값 업데이트
        final updatedFilledSlots = Map<String, int>.from(tournament.filledSlots);
        updatedFilledSlots[position] = (updatedFilledSlots[position] ?? 0) + 1;
        
        final updatedParticipants = List<String>.from(tournament.participants)..add(userId);
        
        // 모든 슬롯이 채워졌는지 확인하여 상태 업데이트
        TournamentStatus updatedStatus = tournament.status;
        final willBeFull = updatedFilledSlots.entries.every((entry) {
          final totalSlots = tournament.slots[entry.key] ?? 0;
          return entry.value >= totalSlots;
        });
        
        if (willBeFull) {
          updatedStatus = TournamentStatus.full;
        }
        
        // 트랜잭션 업데이트
        transaction.update(docRef, {
          'filledSlots': updatedFilledSlots,
          'participants': updatedParticipants,
          'status': updatedStatus.index,
          'updatedAt': Timestamp.now(),
        });
      });
    } catch (e) {
      print('Error joining tournament: $e');
      rethrow;
    }
  }
  
  // 토너먼트 참가 취소
  Future<void> leaveTournament(String tournamentId, String position) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('로그인이 필요합니다.');
    
    try {
      await _firestore.runTransaction((transaction) async {
        // 토너먼트 문서 가져오기
        final docRef = _tournamentsRef.doc(tournamentId);
        final docSnapshot = await transaction.get(docRef);
        
        if (!docSnapshot.exists) {
          throw Exception('토너먼트를 찾을 수 없습니다.');
        }
        
        // 토너먼트 모델로 변환
        final tournament = TournamentModel.fromFirestore(docSnapshot);
        
        // 참가했는지 확인
        if (!tournament.participants.contains(userId)) {
          throw Exception('참가하지 않은 토너먼트입니다.');
        }
        
        // 필드 값 업데이트
        final updatedFilledSlots = Map<String, int>.from(tournament.filledSlots);
        updatedFilledSlots[position] = (updatedFilledSlots[position] ?? 1) - 1;
        if (updatedFilledSlots[position]! < 0) updatedFilledSlots[position] = 0;
        
        final updatedParticipants = List<String>.from(tournament.participants)..remove(userId);
        
        // 상태 업데이트
        TournamentStatus updatedStatus = tournament.status;
        if (tournament.status == TournamentStatus.full) {
          updatedStatus = TournamentStatus.open;
        }
        
        // 트랜잭션 업데이트
        transaction.update(docRef, {
          'filledSlots': updatedFilledSlots,
          'participants': updatedParticipants,
          'status': updatedStatus.index,
          'updatedAt': Timestamp.now(),
        });
      });
    } catch (e) {
      print('Error leaving tournament: $e');
      rethrow;
    }
  }
  
  // 토너먼트 상태 변경
  Future<void> updateTournamentStatus(String tournamentId, TournamentStatus status) async {
    try {
      await _tournamentsRef.doc(tournamentId).update({
        'status': status.index,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating tournament status: $e');
      rethrow;
    }
  }
} 