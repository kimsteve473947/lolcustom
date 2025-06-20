import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/models/chat_model.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/services/firebase_messaging_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TournamentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collectionPath = 'tournaments';
  final String _usersPath = 'users';

  // 추가: FirebaseService와 FirebaseMessagingService 의존성
  final FirebaseService _firebaseService;
  final FirebaseMessagingService _messagingService;

  // 생성자를 통한 의존성 주입
  TournamentService({
    FirebaseService? firebaseService,
    FirebaseMessagingService? messagingService,
  })  : _firebaseService = firebaseService ?? FirebaseService(),
        _messagingService = messagingService ?? FirebaseMessagingService();

  // 사용자 ID 가져오기
  String? get _userId => _auth.currentUser?.uid;

  // 콜렉션 참조
  CollectionReference get _tournamentsRef =>
      _firestore.collection(_collectionPath);
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
  Stream<List<TournamentModel>> getTournamentsByStatusStream(
      TournamentStatus status) {
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
    return _tournamentsRef.doc(id).snapshots().map((doc) {
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

  // 토너먼트 목록 가져오기 - 필터링 지원
  Future<Map<String, dynamic>> getTournaments({
    int limit = 20,
    DocumentSnapshot? startAfter,
    Map<String, dynamic>? filters,
  }) async {
    try {
      // 쿼리 생성
      Query query = _tournamentsRef;

      // 필터 적용
      if (filters != null) {
        // 토너먼트 타입 필터 (일반전/경쟁전)
        if (filters.containsKey('tournamentType') &&
            filters['tournamentType'] != null) {
          query = query.where('tournamentType',
              isEqualTo: filters['tournamentType']);
        }

        // 상태 필터
        if (filters.containsKey('status') && filters['status'] != null) {
          query = query.where('status', isEqualTo: filters['status']);
        }

        // 현재 시간 이후 토너먼트만 보여주기 위한 필터
        if (filters.containsKey('showOnlyFuture') &&
            filters['showOnlyFuture'] == true) {
          // 현재 시간 기준 Timestamp 생성
          final now = Timestamp.fromDate(DateTime.now());
          query = query.where('startsAt', isGreaterThanOrEqualTo: now);
        }
      } else {
        // 기본적으로 현재 시간 이후 토너먼트만 표시
        final now = Timestamp.fromDate(DateTime.now());
        query = query.where('startsAt', isGreaterThanOrEqualTo: now);
      }

      // 기본 정렬: 시작 시간 오름차순
      query = query.orderBy('startsAt', descending: false);

      // 페이지네이션
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      // 결과 제한
      query = query.limit(limit);

      // 쿼리 실행
      QuerySnapshot querySnapshot;
      try {
        // 복합 쿼리 실행 시도
        querySnapshot = await query.get();
      } catch (e) {
        // 인덱스 오류 발생 시 단순화된 쿼리로 폴백
        debugPrint('복합 쿼리 실행 중 오류 발생: $e');
        debugPrint('단순화된 쿼리로 폴백합니다.');

        // 기본 쿼리만 사용하되, 현재 시간 이후 토너먼트만 필터링
        final now = Timestamp.fromDate(DateTime.now());
        query = _tournamentsRef
            .where('startsAt', isGreaterThanOrEqualTo: now)
            .orderBy('startsAt', descending: false)
            .limit(limit);

        if (startAfter != null) {
          query = query.startAfterDocument(startAfter);
        }

        querySnapshot = await query.get();
      }

      // 결과가 없는 경우
      if (querySnapshot.docs.isEmpty) {
        debugPrint('No tournaments found matching the criteria');
        return {'tournaments': <TournamentModel>[], 'lastDoc': null};
      }

      // 모델 변환
      var tournaments = <TournamentModel>[];

      for (final doc in querySnapshot.docs) {
        try {
          final tournament = TournamentModel.fromFirestore(doc);
          tournaments.add(tournament);
        } catch (e) {
          debugPrint(
              'Error parsing tournament data for document ${doc.id}: $e');
          // 오류가 있는 문서는 건너뛰고 계속 진행
          continue;
        }
      }

      debugPrint('Successfully loaded ${tournaments.length} tournaments');

      // 날짜 필터 적용 (Firebase 쿼리로 처리할 수 없는 필터)
      if (filters != null &&
          filters.containsKey('startDate') &&
          filters['startDate'] != null &&
          filters.containsKey('endDate') &&
          filters['endDate'] != null) {
        final startDate = filters['startDate'] as DateTime;
        final endDate = filters['endDate'] as DateTime;

        // 날짜 필터링을 더 엄격하게 적용 - 해당 날짜에 속하는 대회만 포함
        tournaments = tournaments.where((t) {
          final tournamentDate = t.startsAt.toDate();
          return tournamentDate.year == startDate.year &&
              tournamentDate.month == startDate.month &&
              tournamentDate.day == startDate.day;
        }).toList();

        debugPrint('After date filtering: ${tournaments.length} tournaments');
      }

      // 추가 필터링 적용 (Firebase 쿼리로 처리할 수 없는 필터)
      if (filters != null) {
        // 토너먼트 타입 필터 (폴백 쿼리에서 처리 못한 경우)
        if (filters.containsKey('tournamentType') &&
            filters['tournamentType'] != null) {
          final tournamentType = filters['tournamentType'];
          tournaments = tournaments
              .where((t) => t.tournamentType.index == tournamentType)
              .toList();
        }

        // 거리 필터
        if (filters.containsKey('maxDistance') &&
            filters['maxDistance'] != null) {
          final maxDistance = filters['maxDistance'] as double;
          tournaments = tournaments
              .where((t) => t.distance == null || t.distance! <= maxDistance)
              .toList();
        }

        // OVR 제한 필터
        if (filters.containsKey('ovrLimit') && filters['ovrLimit'] != null) {
          final ovrLimit = filters['ovrLimit'];
          tournaments = tournaments
              .where((t) => t.ovrLimit == null || t.ovrLimit! <= ovrLimit)
              .toList();
        }

        // 티어 제한 필터
        if (filters.containsKey('tierLimit') && filters['tierLimit'] != null) {
          final tierLimit = filters['tierLimit'] as PlayerTier;
          tournaments = tournaments
              .where((t) => t.isUserTierEligible(tierLimit))
              .toList();
        }

        // 상태 필터 (폴백 쿼리에서 처리 못한 경우)
        if (filters.containsKey('status') && filters['status'] != null) {
          final status = filters['status'];
          tournaments =
              tournaments.where((t) => t.status.index == status).toList();
        }

        // 현재 시간 이후 토너먼트만 표시 (폴백 쿼리에서 처리 못한 경우)
        if (filters.containsKey('showOnlyFuture') &&
            filters['showOnlyFuture'] == true) {
          final now = DateTime.now();
          tournaments = tournaments
              .where((t) {
                // 토너먼트 시작 시간이 현재 시간보다 미래인 경우만 표시
                final tournamentTime = t.startsAt.toDate();
                final isAfterNow = tournamentTime.isAfter(now);
                
                // 디버깅을 위한 로그
                if (!isAfterNow) {
                  debugPrint('필터링됨: ${t.title} - 시작시간: $tournamentTime, 현재시간: $now');
                }
                
                return isAfterNow;
              })
              .toList();
        }
      } else {
        // 기본적으로 현재 시간 이후 토너먼트만 표시 (폴백 쿼리에서 처리 못한 경우)
        final now = DateTime.now();
        tournaments =
            tournaments.where((t) {
              final tournamentTime = t.startsAt.toDate();
              return tournamentTime.isAfter(now);
            }).toList();
      }
 
      // 명시적으로 타입을 보장하여 반환
      final List<TournamentModel> typedTournaments = List<TournamentModel>.from(tournaments);
 
      return {
        'tournaments': typedTournaments,
        'lastDoc': querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
      };
    } catch (e) {
      debugPrint('Error getting tournaments: $e');
      // 에러 발생 시 빈 배열 반환 (앱 동작 유지를 위해)
      return {'tournaments': <TournamentModel>[], 'lastDoc': null};
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
      debugPrint('=== 토너먼트 생성 시작 ===');
      // 기본 유효성 검사
      if (tournament.title.isEmpty) {
        throw Exception('제목이 비어있습니다');
      }

      if (tournament.hostId.isEmpty) {
        throw Exception('호스트 ID가 비어있습니다');
      }

      // 사용자 인증 확인
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('사용자 인증이 필요합니다');
      }

      // 데이터 변환 및 검증
      final data = tournament.toFirestore();
      final requiredFields = ['title', 'hostId', 'startsAt', 'status'];

      for (final field in requiredFields) {
        if (!data.containsKey(field) || data[field] == null) {
          throw Exception('필수 필드 누락: $field');
        }
      }

      // 트랜잭션을 사용하여 토너먼트 생성 및 사용자 데이터 업데이트
      String newTournamentId = '';

      await _firestore.runTransaction((transaction) async {
        try {
          // 1. 새 토너먼트 문서 생성
          final docRef = _tournamentsRef.doc();
          newTournamentId = docRef.id;
          debugPrint('새 토너먼트 ID 생성: $newTournamentId');

          // 2. 트랜잭션에 토너먼트 데이터 쓰기 추가
          transaction.set(docRef, data);
          debugPrint('토너먼트 데이터 저장 완료');

          // 3. 사용자 문서에 생성한 토너먼트 ID 추가 (옵션)
          final userRef = _usersRef.doc(userId);
          final userDoc = await transaction.get(userRef);

          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final hostedTournaments =
                List<String>.from(userData['hostedTournaments'] ?? []);

            if (!hostedTournaments.contains(newTournamentId)) {
              hostedTournaments.add(newTournamentId);
              transaction
                  .update(userRef, {'hostedTournaments': hostedTournaments});
              debugPrint('사용자 문서에 토너먼트 ID 추가 완료');
            }
          }

          debugPrint('토너먼트 생성 트랜잭션 완료: $newTournamentId');
        } catch (e) {
          debugPrint('토너먼트 생성 트랜잭션 중 오류: $e');
          throw Exception('토너먼트 생성 실패: $e');
        }
      });

      // 4. 토너먼트 생성 후 채팅방 자동 생성
      debugPrint('토너먼트 생성 후 채팅방 생성 시작');
      
      // 완전한 토너먼트 데이터 로드
      final tournamentDoc = await _tournamentsRef.doc(newTournamentId).get();
      if (!tournamentDoc.exists) {
        debugPrint('오류: 생성된 토너먼트 문서를 찾을 수 없음');
        throw Exception('생성된 토너먼트를 찾을 수 없습니다');
      }
      
      final createdTournament = TournamentModel.fromFirestore(tournamentDoc);
      debugPrint('생성된 토너먼트 데이터 로드 완료: ${createdTournament.title}');
      
      // 채팅방 생성 명시적 호출
      await _createTournamentChatRoom(newTournamentId, createdTournament);
      debugPrint('=== 토너먼트 생성 완료 ===');

      return newTournamentId;
    } catch (e) {
      debugPrint('토너먼트 생성 중 오류: $e');
      rethrow;
    }
  }

  // 내전용 채팅방 생성 메서드
  Future<void> _createTournamentChatRoom(
      String tournamentId, TournamentModel tournament) async {
    try {
      debugPrint('=== 채팅방 생성 시작: 토너먼트 ID = $tournamentId ===');
      
      // 이미 채팅방이 있는지 확인
      final existingChatRoomId =
          await _firebaseService.findChatRoomByTournamentId(tournamentId);
      if (existingChatRoomId != null) {
        debugPrint(
            '채팅방이 이미 존재합니다: 토너먼트 ID = $tournamentId, 채팅방 ID = $existingChatRoomId');
        return;
      }
      
      debugPrint('기존 채팅방 없음, 새 채팅방 생성 시작');

      // 호스트 정보 가져오기
      final hostUser = await _firebaseService.getUserById(tournament.hostId);
      if (hostUser == null) {
        debugPrint('오류: 호스트 사용자를 찾을 수 없습니다. ID = ${tournament.hostId}');
        return;
      }
      
      debugPrint('호스트 정보 조회 성공: ${hostUser.nickname}');

      // 채팅방 참가자 초기화 (호스트만 포함)
      final participantIds = [tournament.hostId];
      final participantNames = {tournament.hostId: hostUser.nickname};
      final participantProfileImages = {
        tournament.hostId: hostUser.profileImageUrl
      };
      final unreadCount = {tournament.hostId: 0};

      // 채팅방 모델 생성
      final chatRoom = ChatRoomModel(
        id: tournamentId, // 토너먼트 ID를 채팅방 ID로 사용
        title: '${tournament.title}', // 임시 제목 (나중에 업데이트됨)
        participantIds: participantIds,
        participantNames: participantNames,
        participantProfileImages: participantProfileImages,
        unreadCount: unreadCount,
        type: ChatRoomType.tournamentRecruitment,
        tournamentId: tournamentId,
        createdAt: Timestamp.now(),
        lastMessageTime: Timestamp.now(), // 메시지 정렬을 위해 마지막 메시지 시간 설정
      );
      
      debugPrint('채팅방 모델 생성 완료: ${chatRoom.title}');

      // 채팅방 생성 - 토너먼트 ID와 동일한 ID로 직접 생성
      debugPrint('Firestore에 채팅방 문서 생성 시작 (ID: $tournamentId)...');
      
      // 채팅방 문서를 tournamentId로 직접 생성
      await FirebaseFirestore.instance.collection('chatRooms').doc(tournamentId).set(chatRoom.toFirestore());
      debugPrint('채팅방 문서 생성 완료, ID: $tournamentId');
      
      // 채팅방 제목 업데이트 - 참가자 수 정확히 반영
      await _updateChatRoomTitle(tournamentId, 0, tournamentId); // 0은 무시되고 실제 참가자 수가 사용됨
      
      // 시스템 메시지 전송
      await _sendSystemMessage(
        tournamentId,
        '내전 채팅방이 생성되었습니다. 참가자가 모이면 알림이 전송됩니다.',
      );
      debugPrint('시스템 메시지 전송 완료');
      
      // 생성 확인
      final verifyDoc = await FirebaseFirestore.instance.collection('chatRooms').doc(tournamentId).get();
      if (verifyDoc.exists) {
        final data = verifyDoc.data() as Map<String, dynamic>;
        debugPrint('채팅방 생성 확인: ${data['title']} - 토너먼트 ID: ${data['tournamentId']}');
      } else {
        debugPrint('!!! 경고: 채팅방이 생성되지 않았거나 확인할 수 없음 !!!');
      }
      
      debugPrint('=== 채팅방 생성 완료 ===');
    } catch (e) {
      debugPrint('!!! 채팅방 생성 중 오류 발생: $e !!!');
      debugPrint('스택 트레이스: ${StackTrace.current}');
    }
  }

  // 날짜 포맷 유틸리티 메서드
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // 채팅방에 참가자 추가
  Future<void> _addParticipantToChatRoom(String tournamentId, String userId, {String? role, bool sendSystemMessage = true}) async {
    try {
      // 사용자 정보 가져오기
      final user = await _firebaseService.getUserById(userId);
      if (user == null) {
        debugPrint('User $userId not found');
        return;
      }

      // 채팅방 ID 찾기
      final chatRoomId = await _firebaseService.findChatRoomByTournamentId(tournamentId);
      if (chatRoomId == null) {
        debugPrint('Chat room for tournament $tournamentId not found');
        return;
      }
      
      // 토너먼트 정보 가져오기
      final tournamentDoc = await _tournamentsRef.doc(tournamentId).get();
      if (!tournamentDoc.exists) {
        debugPrint('Tournament $tournamentId not found');
        return;
      }
      final tournament = TournamentModel.fromFirestore(tournamentDoc);

      // 채팅방 정보 가져오기
      final chatRoomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      if (!chatRoomDoc.exists) {
        debugPrint('Chat room $chatRoomId not found');
        return;
      }
      final chatRoom = ChatRoomModel.fromFirestore(chatRoomDoc);
      
      // 채팅방 제목 업데이트 - 새로 생성한 _updateChatRoomTitle 메서드 사용
      await _updateChatRoomTitle(chatRoomId, 0, tournamentId); // 0은 무시되고 실제 참가자 수가 사용됨

      // 채팅방에 참가자 추가
      await _firebaseService.addParticipantToChatRoom(
        chatRoomId,
        userId,
        user.nickname,
        user.profileImageUrl,
      );

      // 시스템 메시지 전송 옵션이 활성화된 경우에만 메시지 전송
      if (sendSystemMessage) {
        // 사용자 역할이 없는 경우 역할 찾기
        String userRole = role ?? 'unknown';
        if (userRole == 'unknown') {
          // 토너먼트에서 사용자의 역할 찾기
          for (final r in ['top', 'jungle', 'mid', 'adc', 'support']) {
            final participants = tournament.participantsByRole[r] ?? [];
            if (participants.contains(userId)) {
              userRole = r;
              break;
            }
          }
        }

        // 역할 표시 이름 가져오기
        final roleDisplayName = _getRoleDisplayName(userRole);
        final currentParticipants = tournament.participants.length;
        
        debugPrint('_addParticipantToChatRoom: 직접 구현 - 시스템 메시지 전송: ${user.nickname}[$roleDisplayName], count: $currentParticipants/${tournament.totalSlots}');
        
        // 메시지 모델 직접 생성
        final message = MessageModel(
          id: '',
          chatRoomId: chatRoomId,
          senderId: 'system',
          senderName: '시스템',
          text: "${user.nickname}[$roleDisplayName]님이 채팅방에 참가했습니다. ($currentParticipants/${tournament.totalSlots})",
          readStatus: {},
          timestamp: Timestamp.now(),
          metadata: {
            'isSystem': true,
            'action': 'join',
            'role': userRole,
            'currentCount': currentParticipants,
            'totalSlots': tournament.totalSlots,
          },
        );

        // 메시지 직접 전송
        final messageId = await _firebaseService.sendMessage(message);
        
        debugPrint('_addParticipantToChatRoom: 직접 구현 - 시스템 메시지가 전송됨. 메시지 ID: $messageId, 메타데이터: ${message.metadata}');
        
        // 참가자 수 정보를 로그에 기록
        debugPrint('Added user $userId to chat room $chatRoomId, new participant count: $currentParticipants');
      } else {
        // 시스템 메시지를 보내지 않는 경우에도 로그 기록
        final participantCount = tournament.participants.length;
        debugPrint('Added user $userId to chat room $chatRoomId, new participant count: $participantCount');
      }
    } catch (e) {
      debugPrint('Error adding participant to chat room: $e');
    }
  }

  // 시스템 메시지 전송
  Future<void> _sendSystemMessage(
    String chatRoomId, 
    String content,
    {Map<String, dynamic>? metadata}
  ) async {
    debugPrint('_sendSystemMessage: Preparing system message: "$content"');
    debugPrint('_sendSystemMessage: Original metadata: $metadata');
    
    final defaultMetadata = {'isSystem': true};
    final finalMetadata = metadata != null 
        ? {...defaultMetadata, ...metadata} 
        : defaultMetadata;
    
    debugPrint('_sendSystemMessage: Final metadata: $finalMetadata');
    
    final message = MessageModel(
      id: '',
      chatRoomId: chatRoomId,
      senderId: 'system',
      senderName: '시스템',
      text: content,
      readStatus: {},
      timestamp: Timestamp.now(),
      metadata: finalMetadata,
    );
    
    final messageId = await _firebaseService.sendMessage(message);
    debugPrint('_sendSystemMessage: Message sent with ID: $messageId, content: "$content"');
  }

  // 역할명을 표시용 문자열로 변환
  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'top': return '탑';
      case 'jungle': return '정글';
      case 'mid': return '미드';
      case 'adc': return '원딜';
      case 'support': return '서포터';
      default: return role;
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
  Future<void> deleteTournament(String id, {bool deleteChatRoom = true}) async {
    try {
      // 채팅방 삭제 옵션이 true인 경우에만 채팅방 삭제
      if (deleteChatRoom) {
        await _deleteTournamentChatRoom(id);
      } else {
        // 채팅방을 삭제하지 않는 경우, 토너먼트 ID 연결만 제거
        final chatRoomId = await _firebaseService.findChatRoomByTournamentId(id);
        if (chatRoomId != null) {
          await _firestore.collection('chatRooms').doc(chatRoomId).update({
            'tournamentId': FieldValue.delete(),
            'type': ChatRoomType.direct.index, // 일반 그룹 채팅방으로 변경
          });
          
          // 시스템 메시지 전송
          await _sendSystemMessage(
            chatRoomId,
            '주최자가 내전을 취소했습니다. 채팅방은 유지됩니다.',
          );
        }
      }
      
      // 토너먼트 삭제
      await _tournamentsRef.doc(id).delete();
    } catch (e) {
      print('Error deleting tournament: $e');
      rethrow;
    }
  }
  
  // 토너먼트 채팅방 삭제
  Future<void> _deleteTournamentChatRoom(String tournamentId) async {
    try {
      // 토너먼트 관련 채팅방 찾기
      final chatRoomId = await _firebaseService.findChatRoomByTournamentId(tournamentId);
      if (chatRoomId == null) {
        debugPrint('No chat room found for tournament $tournamentId');
        return;
      }
      
      // 시스템 메시지 전송
      await _sendSystemMessage(
        chatRoomId,
        '내전이 취소되어 채팅방이 곧 삭제됩니다.',
      );
      
      // 채팅방 삭제
      await _firestore.collection('chatRooms').doc(chatRoomId).delete();
      
      // 관련 메시지도 삭제
      final messagesSnapshot = await _firestore
          .collection('messages')
          .where('chatRoomId', isEqualTo: chatRoomId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      debugPrint('Deleted chat room $chatRoomId for tournament $tournamentId');
    } catch (e) {
      debugPrint('Error deleting tournament chat room: $e');
    }
  }

  // 역할별 토너먼트 참가
  Future<TournamentModel?> joinTournamentByRole(String tournamentId, String role) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('로그인이 필요합니다.');
    
    try {
      // 트랜잭션을 통한 토너먼트 참가 처리
      bool isTournamentFull = false;
      TournamentModel? updatedTournament;

      await _firestore.runTransaction((transaction) async {
        // 토너먼트 문서 가져오기
        final tournamentDoc = await transaction
            .get(_firestore.collection('tournaments').doc(tournamentId));

        if (!tournamentDoc.exists) {
          throw Exception('토너먼트를 찾을 수 없습니다.');
        }

        // 토너먼트 데이터 파싱
        final tournament = TournamentModel.fromFirestore(tournamentDoc);

        // 이미 참가 중인지 확인
        if (tournament.participants.contains(userId)) {
          throw Exception('이미 해당 토너먼트에 참가 중입니다.');
        }

        // 자리가 있는지 확인
        final slotsByRole = tournament.slotsByRole[role] ?? 0;
        final filledSlotsByRole = tournament.filledSlotsByRole[role] ?? 0;

        if (filledSlotsByRole >= slotsByRole) {
          throw Exception('해당 역할의 자리가 이미 모두 찼습니다.');
        }

        // 업데이트할 참가자 목록 생성
        final updatedParticipants = List<String>.from(tournament.participants)
          ..add(userId);

        // 업데이트할 역할별 참가자 목록 생성
        final updatedParticipantsByRole =
            Map<String, List<String>>.from(tournament.participantsByRole);
        if (!updatedParticipantsByRole.containsKey(role)) {
          updatedParticipantsByRole[role] = [];
        }
        updatedParticipantsByRole[role] =
            List<String>.from(updatedParticipantsByRole[role]!)..add(userId);

        // 업데이트할 역할별 참가 인원 생성
        final updatedFilledSlotsByRole =
            Map<String, int>.from(tournament.filledSlotsByRole);
        updatedFilledSlotsByRole[role] =
            (updatedFilledSlotsByRole[role] ?? 0) + 1;

        // 업데이트할 전체 참가 인원 계산
        final updatedFilledSlots =
            Map<String, int>.from(tournament.filledSlots);
        updatedFilledSlots['total'] = (updatedFilledSlots['total'] ?? 0) + 1;

        // 토너먼트 꽉 찼는지 확인
        isTournamentFull = updatedParticipants.length >= tournament.totalSlots;

        // 업데이트된 토너먼트 모델 생성 (알림 전송 등에 사용)
        updatedTournament = tournament.copyWith(
          participants: updatedParticipants,
          participantsByRole: updatedParticipantsByRole,
          filledSlotsByRole: updatedFilledSlotsByRole,
          filledSlots: updatedFilledSlots,
        );

        // 토너먼트 문서 업데이트
        transaction.update(
          _firestore.collection('tournaments').doc(tournamentId),
          {
            'participants': updatedParticipants,
            'participantsByRole': updatedParticipantsByRole,
            'filledSlotsByRole': updatedFilledSlotsByRole,
            'filledSlots': updatedFilledSlots,
          },
        );
      });

      // 토너먼트가 꽉 찼으면 모든 참가자에게 알림
      if (isTournamentFull && updatedTournament != null) {
        await _notifyTournamentFull(updatedTournament);
      }

      // 토너먼트 채팅방 찾기
      final chatRoomId =
          await _firebaseService.findChatRoomByTournamentId(tournamentId);

      // 채팅방에 시스템 메시지 전송
      if (chatRoomId != null && updatedTournament != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final user = UserModel.fromFirestore(userDoc);
          final roleDisplayName = _getRoleDisplayName(role);
          
          // null이 아님을 명시적으로 표시
          final tournament = updatedTournament!;
          final participantCount = tournament.participants.length;
          final totalSlots = tournament.totalSlots;
          
          debugPrint('직접 구현: 새 참가자 시스템 메시지 전송: ${user.nickname}[$roleDisplayName], count: $participantCount/$totalSlots');
          
          // 메타데이터를 포함한 메시지 모델 직접 생성
          final message = MessageModel(
            id: '',
            chatRoomId: chatRoomId,
            senderId: 'system',
            senderName: '시스템',
            text: '${user.nickname}님이 채팅방에 참가했습니다.',
            readStatus: {},
            timestamp: Timestamp.now(),
            metadata: {
              'isSystem': true,
              'action': 'join',
              'role': role, // 역할 정보 추가
              'currentCount': participantCount,
              'totalSlots': totalSlots,
            },
          );
          
          // 메시지 직접 전송
          final messageId = await _firebaseService.sendMessageDirectly(message);
          debugPrint('Sent system message with role info: $messageId, role: $role');
          
          // _addParticipantToChatRoom 호출 시 메시지 중복 전송 방지
          await _addParticipantToChatRoom(tournamentId, userId, role: role, sendSystemMessage: false);
          
          return updatedTournament;
        }
      }
      
      // chatRoomId가 없거나 updatedTournament가 없는 경우
      await _addParticipantToChatRoom(tournamentId, userId, role: role);
      
      return updatedTournament;
    } catch (e) {
      debugPrint('Error joining tournament by role: $e');
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
        final updatedFilledSlots =
            Map<String, int>.from(tournament.filledSlots);
        updatedFilledSlots[role] = (updatedFilledSlots[role] ?? 1) - 1;
        if (updatedFilledSlots[role]! < 0)
          updatedFilledSlots[role] = 0;
        
        final updatedFilledSlotsByRole =
            Map<String, int>.from(tournament.filledSlotsByRole);
        updatedFilledSlotsByRole[role] =
            (updatedFilledSlotsByRole[role] ?? 1) - 1;
        if (updatedFilledSlotsByRole[role]! < 0)
          updatedFilledSlotsByRole[role] = 0;
        
        final updatedParticipants = List<String>.from(tournament.participants)
          ..remove(userId);
        
        // 역할별 참가자 목록 업데이트
        final updatedParticipantsByRole =
            Map<String, List<String>>.from(tournament.participantsByRole);
        updatedParticipantsByRole[role] =
            roleParticipants.where((id) => id != userId).toList();
        
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
      
      // 채팅방에서 참가자 제거
      await _removeParticipantFromChatRoom(tournamentId, userId);
      
    } catch (e) {
      print('Error leaving tournament: $e');
      rethrow;
    }
  }
  
  // 채팅방에서 참가자 제거
  Future<void> _removeParticipantFromChatRoom(String tournamentId, String userId) async {
    try {
      // 토너먼트 관련 채팅방 찾기
      final chatRoomId = await _firebaseService.findChatRoomByTournamentId(tournamentId);
      if (chatRoomId == null) {
        debugPrint('No chat room found for tournament $tournamentId');
        return;
      }
      
      // 채팅방 정보 가져오기
      final chatRoomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      if (!chatRoomDoc.exists) {
        debugPrint('Chat room $chatRoomId does not exist');
        return;
      }
      
      // 채팅방 모델로 변환
      final chatRoom = ChatRoomModel.fromFirestore(chatRoomDoc);
      
      // 호스트인 경우 채팅방을 떠날 수 없음 (호스트는 항상 채팅방에 있어야 함)
      final tournamentDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
      if (tournamentDoc.exists) {
        final tournament = TournamentModel.fromFirestore(tournamentDoc);
        if (tournament.hostId == userId) {
          debugPrint('Host cannot leave the tournament chat room');
          return;
        }
      }
      
      // 참가자인지 확인
      if (!chatRoom.participantIds.contains(userId)) {
        debugPrint('User $userId is not a participant in chat room $chatRoomId');
        return;
      }
      
      // 참가자 목록, 이름, 프로필 이미지, 읽지 않은 메시지 수 업데이트
      final updatedParticipantIds = List<String>.from(chatRoom.participantIds)..remove(userId);
      final updatedParticipantNames = Map<String, String>.from(chatRoom.participantNames)..remove(userId);
      final updatedParticipantProfileImages = Map<String, String?>.from(chatRoom.participantProfileImages)..remove(userId);
      final updatedUnreadCount = Map<String, int>.from(chatRoom.unreadCount)..remove(userId);
      
      // 채팅방 업데이트
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'participantIds': updatedParticipantIds,
        'participantNames': updatedParticipantNames,
        'participantProfileImages': updatedParticipantProfileImages,
        'unreadCount': updatedUnreadCount,
        'participantCount': updatedParticipantIds.length, // 참가자 수 업데이트 추가
      });
      
      // 사용자 역할 가져오기
      String userRole = 'unknown';
      final tournamentSnap = await _firestore.collection('tournaments').doc(tournamentId).get();
      TournamentModel? tournament;
      
      if (tournamentSnap.exists) {
        tournament = TournamentModel.fromFirestore(tournamentSnap);
        for (final role in ['top', 'jungle', 'mid', 'adc', 'support']) {
          final participants = tournament.participantsByRole[role] ?? [];
          if (participants.contains(userId)) {
            userRole = role;
            break;
          }
        }
      }
      
      // 시스템 메시지 전송
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && tournament != null) {
        final user = UserModel.fromFirestore(userDoc);
        final roleDisplayName = _getRoleDisplayName(userRole);
        final remainingParticipantCount = updatedParticipantIds.length;
        
        await _sendSystemMessage(
          chatRoomId,
          "${user.nickname}[$roleDisplayName]님이 방을 나갔습니다. ($remainingParticipantCount/${tournament.totalSlots})",
          metadata: {
            'isSystem': true,
            'action': 'leave',
            'role': userRole,
            'currentCount': remainingParticipantCount,
            'totalSlots': tournament.totalSlots,
          },
        );
      } else {
        await _sendSystemMessage(
          chatRoomId,
          "참가자가 채팅방을 나갔습니다.",
          metadata: {
            'isSystem': true,
            'action': 'leave',
          },
        );
      }
      
      // 채팅방 제목 업데이트
      await _updateChatRoomTitle(chatRoomId, updatedParticipantIds.length, tournamentId);
      
      debugPrint('Removed user $userId from chat room $chatRoomId');
    } catch (e) {
      debugPrint('Error removing participant from chat room: $e');
    }
  }
  
  // 채팅방 제목 업데이트
  Future<void> _updateChatRoomTitle(String chatRoomId, int participantCount, String tournamentId) async {
    try {
      final tournamentDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
      if (!tournamentDoc.exists) {
        debugPrint('Tournament $tournamentId does not exist');
        return;
      }
      
      final tournament = TournamentModel.fromFirestore(tournamentDoc);
      
      // 전달받은 participantCount 사용 - 토너먼트 모델의 참가자 수가 아님
      final startDateTime = tournament.startsAt.toDate();
      final formattedDate = DateFormat('MM.dd HH:mm').format(startDateTime);
      final chatRoomTitle = 
          "${tournament.title} – $formattedDate ($participantCount/${tournament.totalSlots})";
      
      debugPrint('Updating chat room title with participant count: $participantCount/${tournament.totalSlots}');
      debugPrint('New chat room title: $chatRoomTitle');
      
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'title': chatRoomTitle,
        'participantCount': participantCount, // 전달받은 참가자 수 사용
      });
    } catch (e) {
      debugPrint('Error updating chat room title: $e');
    }
  }

  // 토너먼트 상태 변경
  Future<void> updateTournamentStatus(
      String tournamentId, TournamentStatus status) async {
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
      await _usersRef.doc(userId).update({'credits': currentCredits + amount});
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

        // 토너먼트 데이터 파싱
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

  // 추가: 사용자가 참여하거나 생성한 토너먼트를 특정 날짜별로 조회
  Future<List<TournamentModel>> getUserTournamentsByDate(DateTime date) async {
    if (_userId == null) {
      debugPrint('사용자가 로그인하지 않았습니다.');
      return [];
    }

    // 날짜 범위 설정 (해당 날짜의 00:00:00부터 23:59:59까지)
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final startTimestamp = Timestamp.fromDate(startOfDay);
    final endTimestamp = Timestamp.fromDate(endOfDay);

    try {
      // 사용자가 호스트인 토너먼트 조회
      final hostTournamentsQuery = await _tournamentsRef
          .where('hostId', isEqualTo: _userId)
          .where('startsAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('startsAt', isLessThanOrEqualTo: endTimestamp)
          .get();

      // 사용자가 참가자인 토너먼트 조회
      final participantTournamentsQuery = await _tournamentsRef
          .where('participants', arrayContains: _userId)
          .where('startsAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('startsAt', isLessThanOrEqualTo: endTimestamp)
          .get();

      // 결과 합치기 (중복 제거)
      final Map<String, TournamentModel> tournamentsMap = {};

      // 호스트 토너먼트 추가
      for (final doc in hostTournamentsQuery.docs) {
        try {
          final tournament = TournamentModel.fromFirestore(doc);
          tournamentsMap[tournament.id] = tournament;
        } catch (e) {
          debugPrint('호스트 토너먼트 파싱 오류 (${doc.id}): $e');
        }
      }

      // 참가자 토너먼트 추가
      for (final doc in participantTournamentsQuery.docs) {
        try {
          final tournament = TournamentModel.fromFirestore(doc);
          tournamentsMap[tournament.id] = tournament;
        } catch (e) {
          debugPrint('참가자 토너먼트 파싱 오류 (${doc.id}): $e');
        }
      }

      // 최종 결과 리스트로 변환 (최신순 정렬)
      final tournaments = tournamentsMap.values.toList()
        ..sort((a, b) => b.startsAt.compareTo(a.startsAt)); // 내림차순 정렬

      debugPrint(
          '${date.toString().split(' ')[0]} 날짜에 ${tournaments.length}개의 토너먼트를 찾았습니다.');
      return tournaments;
    } catch (e) {
      debugPrint('날짜별 토너먼트 조회 오류: $e');
      return [];
    }
  }

  // 추가: 사용자가 참여하거나 생성한 토너먼트가 있는 날짜 목록 조회
  Future<List<DateTime>> getUserTournamentDates(
      {DateTime? startDate, DateTime? endDate}) async {
    if (_userId == null) {
      debugPrint('사용자가 로그인하지 않았습니다.');
      return [];
    }

    // 날짜 범위 설정 (기본값: 현재 달)
    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month, 1);
    final end = endDate ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final startTimestamp = Timestamp.fromDate(start);
    final endTimestamp = Timestamp.fromDate(end);

    try {
      // 사용자가 호스트인 토너먼트 조회
      final hostTournamentsQuery = await _tournamentsRef
          .where('hostId', isEqualTo: _userId)
          .where('startsAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('startsAt', isLessThanOrEqualTo: endTimestamp)
          .get();

      // 사용자가 참가자인 토너먼트 조회
      final participantTournamentsQuery = await _tournamentsRef
          .where('participants', arrayContains: _userId)
          .where('startsAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('startsAt', isLessThanOrEqualTo: endTimestamp)
          .get();

      // 날짜 집합 생성 (중복 제거)
      final Set<String> dateStrings = {};

      // 호스트 토너먼트 날짜 추가
      for (final doc in hostTournamentsQuery.docs) {
        try {
          final timestamp = doc.get('startsAt') as Timestamp;
          final date = timestamp.toDate();
          final dateString =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          dateStrings.add(dateString);
        } catch (e) {
          debugPrint('호스트 토너먼트 날짜 파싱 오류: $e');
        }
      }

      // 참가자 토너먼트 날짜 추가
      for (final doc in participantTournamentsQuery.docs) {
        try {
          final timestamp = doc.get('startsAt') as Timestamp;
          final date = timestamp.toDate();
          final dateString =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          dateStrings.add(dateString);
        } catch (e) {
          debugPrint('참가자 토너먼트 날짜 파싱 오류: $e');
        }
      }

      // 날짜 문자열을 DateTime 객체로 변환
      final dates = dateStrings.map((dateStr) {
        final parts = dateStr.split('-');
        return DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }).toList();

      debugPrint('사용자 토너먼트가 있는 날짜 수: ${dates.length}');
      return dates;
    } catch (e) {
      debugPrint('사용자 토너먼트 날짜 조회 오류: $e');
      return [];
    }
  }

  // 토너먼트가 꽉 찼을 때 모든 참가자에게 알림 전송
  Future<void> _notifyTournamentFull(TournamentModel? tournament) async {
    if (tournament == null) return; // null 체크 추가

    try {
      // 메시지 준비
      final title = '내전 참가자 모집 완료';
      final body = '${tournament.title} 내전의 참가자가 모두 모였습니다!';

      // 토너먼트 채팅방 찾기
      final chatRoomId =
          await _firebaseService.findChatRoomByTournamentId(tournament.id);

      // 채팅방에 시스템 메시지 전송
      if (chatRoomId != null) {
        await _sendSystemMessage(
          chatRoomId,
          '모든 참가자가 모였습니다! 곧 내전이 시작됩니다.',
        );
      }

      // FCM 메시징 서비스 인스턴스 가져오기
      final messagingService = FirebaseMessagingService();

      // 토너먼트 참가자들에게 알림 전송
      await messagingService.sendTournamentNotification(
        tournamentId: tournament.id,
        title: title,
        body: body,
        userIds: tournament.participants,
      );

      debugPrint(
          'Sent notifications to all participants of tournament ${tournament.id}');
    } catch (e) {
      debugPrint('Error sending tournament full notifications: $e');
    }
  }

  // 만료된 토너먼트 채팅방 정리
  Future<void> cleanupExpiredTournamentChatRooms() async {
    try {
      // 현재 시간에서 2시간 전 계산
      final now = DateTime.now();
      final twoHoursAgo = now.subtract(const Duration(hours: 2));
      final twoHoursAgoTimestamp = Timestamp.fromDate(twoHoursAgo);
      
      // 시작 시간이 2시간 이상 지난 토너먼트 조회
      final querySnapshot = await _tournamentsRef
          .where('startsAt', isLessThan: twoHoursAgoTimestamp)
          .get();
      
      debugPrint('Found ${querySnapshot.docs.length} expired tournaments');
      
      // 각 토너먼트에 대해 채팅방 정리
      for (final doc in querySnapshot.docs) {
        final tournament = TournamentModel.fromFirestore(doc);
        
        // 채팅방 찾기
        final chatRoomId = await _firebaseService.findChatRoomByTournamentId(tournament.id);
        if (chatRoomId == null) continue;
        
        // 채팅방 정보 가져오기
        final chatRoomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
        if (!chatRoomDoc.exists) continue;
        
        // 모든 참가자에게 채팅방 만료 알림
        await _sendSystemMessage(
          chatRoomId,
          '내전 종료 시간(2시간)이 지나 채팅방이 곧 삭제됩니다.',
        );
        
        // 참가자들에게 푸시 알림 전송
        final chatRoom = ChatRoomModel.fromFirestore(chatRoomDoc);
        for (final participantId in chatRoom.participantIds) {
          try {
            await _messagingService.sendNotification(
              userId: participantId,
              title: '채팅방 만료 알림',
              body: '${tournament.title} 내전의 채팅방이 종료되었습니다.',
            );
          } catch (e) {
            debugPrint('Error sending notification to user $participantId: $e');
          }
        }
        
        // 채팅방 및 메시지 삭제
        await _firestore.collection('chatRooms').doc(chatRoomId).delete();
        
        final messagesSnapshot = await _firestore
            .collection('messages')
            .where('chatRoomId', isEqualTo: chatRoomId)
            .get();
        
        final batch = _firestore.batch();
        for (final messageDoc in messagesSnapshot.docs) {
          batch.delete(messageDoc.reference);
        }
        await batch.commit();
        
        debugPrint('Deleted expired chat room $chatRoomId for tournament ${tournament.id}');
      }
    } catch (e) {
      debugPrint('Error cleaning up expired tournament chat rooms: $e');
    }
  }
}
