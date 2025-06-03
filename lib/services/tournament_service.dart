import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:uuid/uuid.dart';

class TournamentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collectionPath = 'tournaments';
  final String _usersPath = 'users';
  
  // 사용자 ID 가져오기
  String? get _userId => _auth.currentUser?.uid;
  
  // 콜렉션 참조
  CollectionReference get _tournamentsRef => _firestore.collection(_collectionPath);
  CollectionReference get _usersRef => _firestore.collection(_usersPath);
  
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
    int limit = 10,
    DocumentSnapshot? startAfter,
    Map<String, dynamic>? filters,
  }) async {
    try {
      // 기본 쿼리 - 시작 시간으로 정렬
      Query query = _firestore
          .collection('tournaments')
          .where('status', isEqualTo: TournamentStatus.open.index)
          .orderBy('startsAt', descending: false);
      
      // 인덱스 오류를 방지하기 위해 단순화된 쿼리 사용
      // 먼저 기본 쿼리로 데이터를 가져옴
      QuerySnapshot snapshot;
      
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter).limit(limit);
      } else {
        query = query.limit(limit);
      }
      
      try {
        // 1. 기본 필터가 적용된 쿼리 실행
        snapshot = await query.get();
        
        // 2. 메모리에서 추가 필터 적용
        List<TournamentModel> tournaments = snapshot.docs
            .map((doc) => TournamentModel.fromFirestore(doc))
            .toList();
        
        // 추가 필터가 있으면 메모리에서 필터링
        if (filters != null) {
          // 토너먼트 타입 필터 적용 (일반전/경쟁전)
          if (filters['tournamentType'] != null) {
            tournaments = tournaments.where((t) => 
              t.tournamentType.index == filters['tournamentType']).toList();
          }
          
          // 날짜 범위 필터 적용
          if (filters['startDate'] != null && filters['endDate'] != null) {
            final startDate = (filters['startDate'] as DateTime);
            final endDate = (filters['endDate'] as DateTime);
            
            tournaments = tournaments.where((t) {
              final tournamentDate = t.startsAt.toDate();
              return tournamentDate.isAfter(startDate) && 
                     tournamentDate.isBefore(endDate.add(const Duration(days: 1)));
            }).toList();
          }
          
          // OVR 제한 필터 적용
          if (filters['ovrLimit'] != null) {
            tournaments = tournaments.where((t) => 
              t.ovrLimit == null || t.ovrLimit! <= filters['ovrLimit']).toList();
          }
        }
        
        return tournaments;
      } catch (e) {
        debugPrint('인덱스 오류 발생: $e');
        debugPrint('단순 쿼리로 fallback합니다.');
        
        // 인덱스 오류 발생 시 더 간단한 쿼리로 fallback
        query = _firestore
            .collection('tournaments')
            .where('status', isEqualTo: TournamentStatus.open.index)
            .limit(limit);
            
        snapshot = await query.get();
        
        List<TournamentModel> tournaments = snapshot.docs
            .map((doc) => TournamentModel.fromFirestore(doc))
            .toList();
        
        // 메모리에서 필터 적용
        if (filters != null) {
          // 토너먼트 타입 필터 적용
          if (filters['tournamentType'] != null) {
            tournaments = tournaments.where((t) => 
              t.tournamentType.index == filters['tournamentType']).toList();
          }
        }
        
        // 시작 시간으로 정렬
        tournaments.sort((a, b) => a.startsAt.compareTo(b.startsAt));
        
        return tournaments;
      }
    } catch (e) {
      debugPrint('Error getting tournaments: $e');
      return [];
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
  
  // 토너먼트 특정 라인 참가 (라인별 참가 시스템)
  Future<void> joinTournamentByRole(String tournamentId, String role) async {
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
        if (!tournament.canJoinRole(role)) {
          throw Exception('해당 포지션은 이미 가득 찼거나 참가할 수 없습니다.');
        }
        
        // 사용자 정보 가져오기
        final userDoc = await _usersRef.doc(userId).get();
        if (!userDoc.exists) {
          throw Exception('사용자 정보를 찾을 수 없습니다.');
        }
        
        // 경쟁전인 경우 항상 20 크레딧 차감
        if (tournament.tournamentType == TournamentType.competitive) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final userCredits = userData['credits'] as int? ?? 0;
          const requiredCredits = 20; // 항상 고정 20 크레딧
          
          if (userCredits < requiredCredits) {
            throw Exception('크레딧이 부족합니다. 필요 크레딧: $requiredCredits, 보유 크레딧: $userCredits');
          }
          
          // 크레딧 차감
          transaction.update(_usersRef.doc(userId), {
            'credits': userCredits - requiredCredits
          });
        }
        
        // 필드 값 업데이트
        final updatedFilledSlots = Map<String, int>.from(tournament.filledSlots);
        updatedFilledSlots[role] = (updatedFilledSlots[role] ?? 0) + 1;
        
        final updatedFilledSlotsByRole = Map<String, int>.from(tournament.filledSlotsByRole);
        updatedFilledSlotsByRole[role] = (updatedFilledSlotsByRole[role] ?? 0) + 1;
        
        final updatedParticipants = List<String>.from(tournament.participants)..add(userId);
        
        // 역할별 참가자 목록 업데이트
        final updatedParticipantsByRole = Map<String, List<String>>.from(tournament.participantsByRole);
        if (updatedParticipantsByRole[role] == null) {
          updatedParticipantsByRole[role] = [];
        }
        updatedParticipantsByRole[role]!.add(userId);
        
        // 모든 슬롯이 채워졌는지 확인하여 상태 업데이트
        TournamentStatus updatedStatus = tournament.status;
        final willBeFull = updatedFilledSlotsByRole.entries.every((entry) {
          final totalSlots = tournament.slotsByRole[entry.key] ?? 0;
          return entry.value >= totalSlots;
        });
        
        if (willBeFull) {
          updatedStatus = TournamentStatus.full;
        }
        
        // 트랜잭션 업데이트
        transaction.update(docRef, {
          'filledSlots': updatedFilledSlots,
          'filledSlotsByRole': updatedFilledSlotsByRole,
          'participants': updatedParticipants,
          'participantsByRole': updatedParticipantsByRole,
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
  Future<void> leaveTournamentByRole(String tournamentId, String role) async {
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
        
        // 실제로 해당 역할에 참가했는지 확인
        final roleParticipants = tournament.participantsByRole[role] ?? [];
        if (!roleParticipants.contains(userId)) {
          throw Exception('해당 역할로 참가하지 않았습니다.');
        }
        
        // 필드 값 업데이트
        final updatedFilledSlots = Map<String, int>.from(tournament.filledSlots);
        updatedFilledSlots[role] = (updatedFilledSlots[role] ?? 1) - 1;
        if (updatedFilledSlots[role]! < 0) updatedFilledSlots[role] = 0;
        
        final updatedFilledSlotsByRole = Map<String, int>.from(tournament.filledSlotsByRole);
        updatedFilledSlotsByRole[role] = (updatedFilledSlotsByRole[role] ?? 1) - 1;
        if (updatedFilledSlotsByRole[role]! < 0) updatedFilledSlotsByRole[role] = 0;
        
        final updatedParticipants = List<String>.from(tournament.participants)..remove(userId);
        
        // 역할별 참가자 목록 업데이트
        final updatedParticipantsByRole = Map<String, List<String>>.from(tournament.participantsByRole);
        updatedParticipantsByRole[role] = roleParticipants.where((id) => id != userId).toList();
        
        // 상태 업데이트
        TournamentStatus updatedStatus = tournament.status;
        if (tournament.status == TournamentStatus.full) {
          updatedStatus = TournamentStatus.open;
        }
        
        // 트랜잭션 업데이트
        transaction.update(docRef, {
          'filledSlots': updatedFilledSlots,
          'filledSlotsByRole': updatedFilledSlotsByRole,
          'participants': updatedParticipants,
          'participantsByRole': updatedParticipantsByRole,
          'status': updatedStatus.index,
          'updatedAt': Timestamp.now(),
        });
        
        // 경쟁전인 경우 취소 시 크레딧 환불은 정책에 따라 결정
        // 이 예제에서는 환불하지 않음
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
  
  // 크레딧 충전
  Future<void> addCredits(String userId, int amount) async {
    try {
      // 사용자 문서 가져오기
      final userDoc = await _usersRef.doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final currentCredits = userData['credits'] as int? ?? 0;
      
      // 크레딧 추가
      await _usersRef.doc(userId).update({
        'credits': currentCredits + amount
      });
    } catch (e) {
      print('Error adding credits: $e');
      rethrow;
    }
  }
  
  // 현재 로그인한 사용자의 크레딧 조회
  Future<int> getUserCredits() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('로그인이 필요합니다.');
      }
      
      final userDoc = await _usersRef.doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['credits'] as int? ?? 0;
    } catch (e) {
      print('Error getting user credits: $e');
      rethrow;
    }
  }
  
  // 심판 추가하기
  Future<void> addReferee(String tournamentId, String refereeId) async {
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
        
        // 본인이 주최자인지 확인
        if (tournament.hostId != userId) {
          throw Exception('토너먼트 주최자만 심판을 추가할 수 있습니다.');
        }
        
        // 이미 심판인지 확인
        final referees = tournament.referees ?? [];
        if (referees.contains(refereeId)) {
          throw Exception('이미 심판으로 등록된 사용자입니다.');
        }
        
        // 심판 목록 업데이트
        final updatedReferees = List<String>.from(referees)..add(refereeId);
        
        // 경쟁전이 아닌 경우 심판 추가 불가
        if (tournament.tournamentType != TournamentType.competitive) {
          throw Exception('일반전에는 심판을 추가할 수 없습니다. 경쟁전만 심판을 추가할 수 있습니다.');
        }
        
        // 트랜잭션 업데이트
        transaction.update(docRef, {
          'referees': updatedReferees,
          'isRefereed': true,
          'updatedAt': Timestamp.now(),
        });
      });
    } catch (e) {
      print('Error adding referee: $e');
      rethrow;
    }
  }
  
  // 심판 제거하기
  Future<void> removeReferee(String tournamentId, String refereeId) async {
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
        
        // 본인이 주최자인지 확인
        if (tournament.hostId != userId) {
          throw Exception('토너먼트 주최자만 심판을 제거할 수 있습니다.');
        }
        
        // 심판 목록에 있는지 확인
        final referees = tournament.referees ?? [];
        if (!referees.contains(refereeId)) {
          throw Exception('심판으로 등록되지 않은 사용자입니다.');
        }
        
        // 심판 목록 업데이트
        final updatedReferees = List<String>.from(referees)..remove(refereeId);
        
        // 트랜잭션 업데이트
        transaction.update(docRef, {
          'referees': updatedReferees,
          'isRefereed': updatedReferees.isNotEmpty,
          'updatedAt': Timestamp.now(),
        });
      });
    } catch (e) {
      print('Error removing referee: $e');
      rethrow;
    }
  }
  
  // 모든 심판 가져오기
  Future<List<UserModel>> getTournamentReferees(String tournamentId) async {
    try {
      final tournament = await getTournament(tournamentId);
      if (tournament == null) {
        throw Exception('토너먼트를 찾을 수 없습니다.');
      }
      
      final referees = tournament.referees ?? [];
      if (referees.isEmpty) {
        return [];
      }
      
      final List<UserModel> refereeUsers = [];
      for (final refereeId in referees) {
        final userDoc = await _usersRef.doc(refereeId).get();
        if (userDoc.exists) {
          refereeUsers.add(UserModel.fromFirestore(userDoc));
        }
      }
      
      return refereeUsers;
    } catch (e) {
      print('Error getting tournament referees: $e');
      rethrow;
    }
  }
} 