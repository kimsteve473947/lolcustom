import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/models/chat_model.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService;

  ChatService({FirebaseService? firebaseService})
      : _firebaseService = firebaseService ?? FirebaseService();

  /// 토너먼트 ID에 해당하는 채팅방을 가져오거나 생성합니다.
  Future<String> getOrCreateTournamentChatRoom(
    TournamentModel tournament,
    UserModel currentUser,
  ) async {
    try {
      // 토너먼트 ID로 채팅방 조회
      final chatRoomsSnapshot = await _firestore
          .collection('chatRooms')
          .where('tournamentId', isEqualTo: tournament.id)
          .limit(1)
          .get();

      // 이미 채팅방이 존재하면 해당 ID 반환
      if (chatRoomsSnapshot.docs.isNotEmpty) {
        final chatRoomId = chatRoomsSnapshot.docs.first.id;
        
        // 사용자가 채팅방에 참여하지 않은 경우 참가자 목록에 추가
        await _addUserToChatRoomIfNeeded(chatRoomId, currentUser, tournament);
        
        return chatRoomId;
      }

      // 채팅방이 없으면 새로 생성
      return await _createTournamentChatRoom(tournament, currentUser);
    } catch (e) {
      debugPrint('Error in getOrCreateTournamentChatRoom: $e');
      throw Exception('채팅방 조회/생성 중 오류가 발생했습니다: $e');
    }
  }

  /// 토너먼트에 대한 채팅방을 생성합니다.
  Future<String> _createTournamentChatRoom(
    TournamentModel tournament,
    UserModel currentUser,
  ) async {
    // 채팅방 제목 생성: "[토너먼트 제목] – MM.dd HH:mm (참여자수/10)"
    final startDateTime = tournament.startsAt.toDate();
    final formattedDate = DateFormat('MM.dd HH:mm').format(startDateTime);
    final participantCount = tournament.participants.length;
    final chatRoomTitle = 
        "${tournament.title} – $formattedDate ($participantCount/${tournament.totalSlots})";

    // 참가자 초기화 (주최자 및 현재 참가자 포함)
    final participantIds = List<String>.from(tournament.participants);
    if (!participantIds.contains(currentUser.uid)) {
      participantIds.add(currentUser.uid);
    }

    // 참가자 정보 초기화
    final participantNames = <String, String>{};
    final participantProfileImages = <String, String?>{};
    final unreadCount = <String, int>{};

    // 현재 사용자 정보 추가
    participantNames[currentUser.uid] = currentUser.nickname;
    participantProfileImages[currentUser.uid] = currentUser.profileImageUrl;
    unreadCount[currentUser.uid] = 0;

    // 다른 참가자 정보 추가 (주최자 포함)
    for (final participantId in participantIds) {
      if (participantId != currentUser.uid) {
        final participantDoc = await _firestore
            .collection('users')
            .doc(participantId)
            .get();
        
        if (participantDoc.exists) {
          final userData = participantDoc.data() as Map<String, dynamic>;
          participantNames[participantId] = userData['nickname'] ?? 'Unknown';
          participantProfileImages[participantId] = userData['profileImageUrl'];
          unreadCount[participantId] = 0;
        }
      }
    }

    // 채팅방 모델 생성
    final chatRoom = ChatRoomModel(
      id: '', // Firestore에서 자동 생성될 ID
      title: chatRoomTitle,
      participantIds: participantIds,
      participantNames: participantNames,
      participantProfileImages: participantProfileImages,
      unreadCount: unreadCount,
      type: ChatRoomType.tournamentRecruitment,
      tournamentId: tournament.id,
      createdAt: Timestamp.now(),
      lastMessageTime: Timestamp.now(),
    );

    // 채팅방 생성
    final chatRoomId = await _firebaseService.createChatRoom(chatRoom);

    // 시스템 메시지 전송 (채팅방 생성 알림)
    await _sendSystemMessage(
      chatRoomId,
      "토너먼트 채팅방이 생성되었습니다. 참가자분들과 자유롭게 대화하세요.",
    );

    return chatRoomId;
  }

  /// 사용자가 채팅방에 참여하지 않은 경우 참가자 목록에 추가합니다.
  Future<void> _addUserToChatRoomIfNeeded(
    String chatRoomId,
    UserModel user,
    TournamentModel tournament,
  ) async {
    final chatRoomDoc = await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .get();
    
    if (!chatRoomDoc.exists) return;
    
    final chatRoom = ChatRoomModel.fromFirestore(chatRoomDoc);
    
    // 이미 참가자인 경우 추가 작업 불필요
    if (chatRoom.participantIds.contains(user.uid)) return;
    
    // 참가자 정보 업데이트
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'participantIds': FieldValue.arrayUnion([user.uid]),
      'participantNames.${user.uid}': user.nickname,
      'participantProfileImages.${user.uid}': user.profileImageUrl,
      'unreadCount.${user.uid}': 0,
    });
    
    // 시스템 메시지 전송 (참가자 입장 알림)
    final participantCount = chatRoom.participantIds.length + 1;
    await _sendSystemMessage(
      chatRoomId,
      "${user.nickname}님이 입장했습니다. ($participantCount/${tournament.totalSlots})",
    );
    
    // 채팅방 제목 업데이트 (참가자 수 반영)
    await _updateChatRoomTitle(chatRoomId, tournament, participantCount);
  }

  /// 사용자가 토너먼트 채팅방에 참가할 때 처리합니다.
  Future<void> joinTournamentChatRoom(
    String chatRoomId,
    String tournamentId,
    UserModel user,
    String userRole, // 사용자 역할 (top, jungle, mid, adc, support)
  ) async {
    // 채팅방 정보 가져오기
    final chatRoomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
    if (!chatRoomDoc.exists) {
      throw Exception('채팅방을 찾을 수 없습니다.');
    }
    
    final chatRoom = ChatRoomModel.fromFirestore(chatRoomDoc);
    
    // 토너먼트 정보 가져오기
    final tournamentDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
    if (!tournamentDoc.exists) {
      throw Exception('토너먼트 정보를 찾을 수 없습니다.');
    }
    
    final tournament = TournamentModel.fromFirestore(tournamentDoc);
    
    // 이미 참가자인 경우 추가 작업 불필요
    if (chatRoom.participantIds.contains(user.uid)) return;
    
    // 참가자 정보 업데이트
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'participantIds': FieldValue.arrayUnion([user.uid]),
      'participantNames.${user.uid}': user.nickname,
      'participantProfileImages.${user.uid}': user.profileImageUrl,
      'unreadCount.${user.uid}': 0,
    });
    
    // 시스템 메시지 전송 (참가자 입장 알림)
    final participantCount = chatRoom.participantIds.length + 1;
    await _sendSystemMessage(
      chatRoomId,
      "${user.nickname}[${_getRoleDisplayName(userRole)}]님이 채팅방에 참가했습니다. ($participantCount/${tournament.totalSlots})",
      metadata: {
        'isSystem': true,
        'action': 'join',
        'role': userRole,
        'currentCount': participantCount,
        'totalSlots': tournament.totalSlots,
      },
    );
    
    // 채팅방 제목 업데이트 (참가자 수 반영)
    await _updateChatRoomTitle(chatRoomId, tournament, participantCount);
  }

  /// 사용자가 채팅방을 나갈 때 처리합니다.
  Future<void> leaveTournamentChatRoom(
    String chatRoomId,
    String tournamentId,
    UserModel user,
    String userRole, // 사용자 역할 (top, jungle, mid, adc, support)
  ) async {
    try {
      // 1. 채팅방에서 사용자 제거
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'participantIds': FieldValue.arrayRemove([user.uid]),
        'participantNames.${user.uid}': FieldValue.delete(),
        'participantProfileImages.${user.uid}': FieldValue.delete(),
        'unreadCount.${user.uid}': FieldValue.delete(),
      });
      
      // 2. 토너먼트 정보 가져오기
      final tournamentDoc = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .get();
      
      if (!tournamentDoc.exists) {
        throw Exception('토너먼트를 찾을 수 없습니다.');
      }
      
      final tournament = TournamentModel.fromFirestore(tournamentDoc);
      
      // 3. 채팅방 참가자 수 가져오기
      final chatRoomDoc = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
      
      if (!chatRoomDoc.exists) {
        throw Exception('채팅방을 찾을 수 없습니다.');
      }
      
      final chatRoom = ChatRoomModel.fromFirestore(chatRoomDoc);
      final newParticipantCount = chatRoom.participantIds.length;
      
      // 4. 시스템 메시지 전송 (참가자 퇴장 알림)
      await _sendSystemMessage(
        chatRoomId,
        "${user.nickname}[${_getRoleDisplayName(userRole)}]님이 방을 나갔습니다. ($newParticipantCount/${tournament.totalSlots})",
        metadata: {
          'isSystem': true,
          'action': 'leave',
          'role': userRole,
          'currentCount': newParticipantCount,
          'totalSlots': tournament.totalSlots,
        },
      );
      
      // 5. 채팅방 제목 업데이트 (참가자 수 반영)
      await _updateChatRoomTitle(chatRoomId, tournament, newParticipantCount);
      
      // 6. 애플리케이션 문서 찾기 및 삭제
      final applicationsSnapshot = await _firestore
          .collection('applications')
          .where('tournamentId', isEqualTo: tournamentId)
          .where('userUid', isEqualTo: user.uid)
          .get();
      
      for (final doc in applicationsSnapshot.docs) {
        await doc.reference.delete();
      }

      // 7. 토너먼트에서도 참가자 제거 (가장 중요한 수정사항)
      await _firebaseService.leaveTournamentByRole(tournamentId, userRole);
      
    } catch (e) {
      debugPrint('Error in leaveTournamentChatRoom: $e');
      throw Exception('채팅방 나가기 중 오류가 발생했습니다: $e');
    }
  }

  /// 채팅방 제목을 업데이트합니다.
  Future<void> _updateChatRoomTitle(
    String chatRoomId,
    TournamentModel tournament,
    int participantCount,
  ) async {
    final startDateTime = tournament.startsAt.toDate();
    final formattedDate = DateFormat('MM.dd HH:mm').format(startDateTime);
    final chatRoomTitle = 
        "${tournament.title} – $formattedDate ($participantCount/${tournament.totalSlots})";
    
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'title': chatRoomTitle,
      'participantCount': participantCount,
    });
  }

  /// 시스템 메시지를 전송합니다.
  Future<void> _sendSystemMessage(
    String chatRoomId, 
    String content, 
    {Map<String, dynamic>? metadata}
  ) async {
    final defaultMetadata = {'isSystem': true};
    final finalMetadata = metadata != null 
        ? {...defaultMetadata, ...metadata} 
        : defaultMetadata;
    
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
    
    await _firebaseService.sendMessage(message);
  }

  /// 역할명을 표시용 문자열로 변환합니다.
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

  /// 채팅방 참가자 목록을 가져옵니다.
  Future<List<Map<String, dynamic>>> getChatRoomMembers(String chatRoomId) async {
    try {
      final chatRoomDoc = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
      
      if (!chatRoomDoc.exists) {
        throw Exception('채팅방을 찾을 수 없습니다.');
      }
      
      final chatRoom = ChatRoomModel.fromFirestore(chatRoomDoc);
      
      // 토너먼트 ID가 없는 경우 기본 참가자 정보만 반환
      if (chatRoom.tournamentId == null) {
        return chatRoom.participantIds.map((uid) {
          return {
            'uid': uid,
            'nickname': chatRoom.participantNames[uid] ?? 'Unknown',
            'profileImageUrl': chatRoom.participantProfileImages[uid],
            'role': null,
          };
        }).toList();
      }
      
      // 토너먼트 정보 가져오기
      final tournamentDoc = await _firestore
          .collection('tournaments')
          .doc(chatRoom.tournamentId)
          .get();
      
      if (!tournamentDoc.exists) {
        throw Exception('토너먼트를 찾을 수 없습니다.');
      }
      
      final tournament = TournamentModel.fromFirestore(tournamentDoc);
      
      // 역할별 참가자 맵 생성
      final roleMap = <String, String>{};
      
      for (final role in ['top', 'jungle', 'mid', 'adc', 'support']) {
        final participants = tournament.participantsByRole[role] ?? [];
        for (final uid in participants) {
          roleMap[uid] = role;
        }
      }
      
      // 참가자 정보 + 역할 정보 반환
      return chatRoom.participantIds.map((uid) {
        return {
          'uid': uid,
          'nickname': chatRoom.participantNames[uid] ?? 'Unknown',
          'profileImageUrl': chatRoom.participantProfileImages[uid],
          'role': roleMap[uid],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error in getChatRoomMembers: $e');
      throw Exception('채팅방 멤버 정보를 가져오는 중 오류가 발생했습니다: $e');
    }
  }

  /// 1:1 채팅방을 가져오거나 생성합니다.
  Future<String> getOrCreateDirectChatRoom(String currentUserId, String otherUserId) async {
    // 두 사용자 ID를 정렬하여 고유한 채팅방 ID 생성
    List<String> userIds = [currentUserId, otherUserId]..sort();
    String chatRoomId = 'dm_${userIds[0]}_${userIds[1]}';

    final chatRoomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();

    // 채팅방이 이미 존재하면 ID 반환 (필요시 'hiddenFor'에서 사용자 제거)
    if (chatRoomDoc.exists) {
      final chatRoom = ChatRoomModel.fromFirestore(chatRoomDoc);
      if (chatRoom.hiddenFor.contains(currentUserId)) {
        // 사용자가 나갔던 방이면 다시 활성화
        await _firestore.collection('chatRooms').doc(chatRoomId).update({
          'hiddenFor': FieldValue.arrayRemove([currentUserId])
        });
      }
      return chatRoomId;
    }

    // 채팅방이 없으면 새로 생성
    final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
    final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();

    if (!currentUserDoc.exists || !otherUserDoc.exists) {
      throw Exception('사용자 정보를 찾을 수 없습니다.');
    }

    final currentUser = UserModel.fromFirestore(currentUserDoc);
    final otherUser = UserModel.fromFirestore(otherUserDoc);

    final chatRoom = ChatRoomModel(
      id: chatRoomId,
      title: otherUser.nickname, // 상대방 닉네임을 채팅방 제목으로
      participantIds: userIds,
      participantNames: {
        currentUserId: currentUser.nickname,
        otherUserId: otherUser.nickname,
      },
      participantProfileImages: {
        currentUserId: currentUser.profileImageUrl,
        otherUserId: otherUser.profileImageUrl,
      },
      unreadCount: {
        currentUserId: 0,
        otherUserId: 0,
      },
      type: ChatRoomType.direct,
      createdAt: Timestamp.now(),
      lastMessageTime: Timestamp.now(),
    );

    await _firestore.collection('chatRooms').doc(chatRoomId).set(chatRoom.toFirestore());

    return chatRoomId;
  }

  // 채팅방 나가기 (내 목록에서 숨기기)
  Future<void> leaveChatRoom(String chatRoomId, String userId) async {
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'hiddenFor': FieldValue.arrayUnion([userId])
    });
  }

  // 사용자가 참여하고 있는 채팅방 목록 가져오기 (숨김 처리된 방 제외)
  Stream<List<ChatRoomModel>> getUserChatRooms(String userId) {
    return _firestore
        .collection('chatRooms')
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatRoomModel.fromFirestore(doc))
          .where((chatRoom) => !chatRoom.hiddenFor.contains(userId))
          .toList();
   });
 }

 // 특정 채팅방의 메시지 목록을 실시간으로 가져오기
 Stream<List<MessageModel>> getMessagesStream(String chatRoomId) {
   debugPrint('🔍 [CHAT SERVICE] Loading messages for chatRoomId: $chatRoomId');
   
   return _firestore
       .collection('messages')
       .where('chatRoomId', isEqualTo: chatRoomId)
       .orderBy('timestamp', descending: true)
       .snapshots()
       .map((snapshot) {
         final messages = snapshot.docs
             .map((doc) => MessageModel.fromFirestore(doc))
             .toList();
         
         debugPrint('🔍 [CHAT SERVICE] Loaded ${messages.length} messages for chatRoomId: $chatRoomId');
         
         // Discord 메시지 디버깅
         for (final message in messages) {
           // 모든 메시지 기본 정보 출력
           debugPrint('🔍 [MESSAGE DEBUG] ID: ${message.id}, senderId: ${message.senderId}, hasMetadata: ${message.metadata != null}');
           
           if (message.senderId == 'system' && message.metadata != null && message.metadata!['type'] == 'discord_channels') {
             debugPrint('🎯 [DISCORD MESSAGE FOUND] Message ID: ${message.id}');
             debugPrint('🎯 [DISCORD MESSAGE FOUND] Content: ${message.text}');
             debugPrint('🎯 [DISCORD MESSAGE FOUND] Metadata: ${message.metadata}');
           }
           
           // 특정 메시지 ID 검색 (Firebase Functions에서 저장한 ID)
           if (message.id == 'H8UVCw2VseCBNwMlQqp4') {
             debugPrint('🎯 [FIREBASE MESSAGE FOUND] Found message with ID H8UVCw2VseCBNwMlQqp4');
             debugPrint('🎯 [FIREBASE MESSAGE FOUND] SenderId: ${message.senderId}');
             debugPrint('🎯 [FIREBASE MESSAGE FOUND] Text: ${message.text}');
             debugPrint('🎯 [FIREBASE MESSAGE FOUND] Metadata: ${message.metadata}');
           }
           
           // 최신 Firebase Functions 메시지 ID 검색
           if (message.id == 'WWgg1Q4PS1MqfE3MUBdL') {
             debugPrint('🎯 [LATEST DISCORD MESSAGE] Found latest message with ID WWgg1Q4PS1MqfE3MUBdL');
             debugPrint('🎯 [LATEST DISCORD MESSAGE] SenderId: ${message.senderId}');
             debugPrint('🎯 [LATEST DISCORD MESSAGE] Text: ${message.text}');
             debugPrint('🎯 [LATEST DISCORD MESSAGE] Metadata: ${message.metadata}');
           }
           
           // 가장 최신 Firebase Functions 메시지 ID 검색
           if (message.id == 'v4Ucp1QHMc88KbAfsoWU') {
             debugPrint('🎯 [NEWEST DISCORD MESSAGE] Found newest message with ID v4Ucp1QHMc88KbAfsoWU');
             debugPrint('🎯 [NEWEST DISCORD MESSAGE] SenderId: ${message.senderId}');
             debugPrint('🎯 [NEWEST DISCORD MESSAGE] Text: ${message.text}');
             debugPrint('🎯 [NEWEST DISCORD MESSAGE] Metadata: ${message.metadata}');
           }
           
           // 초최신 Firebase Functions 메시지 ID 검색 
           if (message.id == 'eSlllYMCk05WBMNlYQbS') {
             debugPrint('🎯 [SUPER LATEST DISCORD MESSAGE] Found super latest message with ID eSlllYMCk05WBMNlYQbS');
             debugPrint('🎯 [SUPER LATEST DISCORD MESSAGE] SenderId: ${message.senderId}');
             debugPrint('🎯 [SUPER LATEST DISCORD MESSAGE] Text: ${message.text}');
             debugPrint('🎯 [SUPER LATEST DISCORD MESSAGE] Metadata: ${message.metadata}');
           }
           
           // 울트라 최신 Firebase Functions 메시지 ID 검색 
           if (message.id == 'uRKT0o8vmE0m7wc6jSS4') {
             debugPrint('🎯 [ULTRA LATEST DISCORD MESSAGE] Found ultra latest message with ID uRKT0o8vmE0m7wc6jSS4');
             debugPrint('🎯 [ULTRA LATEST DISCORD MESSAGE] SenderId: ${message.senderId}');
             debugPrint('🎯 [ULTRA LATEST DISCORD MESSAGE] Text: ${message.text}');
             debugPrint('🎯 [ULTRA LATEST DISCORD MESSAGE] Metadata: ${message.metadata}');
           }
           
           // 최최신 Firebase Functions 메시지 ID 검색 
           if (message.id == 'h3WkDErR8vTmEm85Voi5') {
             debugPrint('🎯 [NEWEST DISCORD MESSAGE] Found newest message with ID h3WkDErR8vTmEm85Voi5');
             debugPrint('🎯 [NEWEST DISCORD MESSAGE] SenderId: ${message.senderId}');
             debugPrint('🎯 [NEWEST DISCORD MESSAGE] Text: ${message.text}');
             debugPrint('🎯 [NEWEST DISCORD MESSAGE] Metadata: ${message.metadata}');
           }
           
           // 방금 Firebase Functions에서 저장한 메시지 ID 검색 
           if (message.id == 'E27uAld0BfeV9RBckxCx') {
             debugPrint('🎯 [CURRENT DISCORD MESSAGE] Found current message with ID E27uAld0BfeV9RBckxCx');
             debugPrint('🎯 [CURRENT DISCORD MESSAGE] SenderId: ${message.senderId}');
             debugPrint('🎯 [CURRENT DISCORD MESSAGE] Text: ${message.text}');
             debugPrint('🎯 [CURRENT DISCORD MESSAGE] Metadata: ${message.metadata}');
           }
           
           // 방금 Firebase Functions에서 저장한 메시지 ID 검색 
           if (message.id == 'n75Ph0wSN6NWERTnWJcK') {
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] Found latest message with ID n75Ph0wSN6NWERTnWJcK');
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] SenderId: ${message.senderId}');
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] Text: ${message.text}');
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] Metadata: ${message.metadata}');
           }
           
           // 방금 Firebase Functions에서 저장한 메시지 ID 검색 
           if (message.id == 'LWOE4QFlA3HA081y2LrI') {
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] Found latest message with ID LWOE4QFlA3HA081y2LrI');
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] SenderId: ${message.senderId}');
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] Text: ${message.text}');
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] Metadata: ${message.metadata}');
           }
           
           // 방금 Firebase Functions에서 저장한 메시지 ID 검색 
           if (message.id == 'zT7Cm70PaEiJplKtn1MK') {
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] Found latest message with ID zT7Cm70PaEiJplKtn1MK');
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] SenderId: ${message.senderId}');
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] Text: ${message.text}');
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] Metadata: ${message.metadata}');
           }
           
           // 방금 Firebase Functions에서 저장한 메시지 ID 검색 
           if (message.id == 'kZzpYvpnqfTmjm49RuNM') {
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] Found latest message with ID kZzpYvpnqfTmjm49RuNM');
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] SenderId: ${message.senderId}');
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] Text: ${message.text}');
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] Metadata: ${message.metadata}');
           }
           
           // Discord 버튼 메시지 타입 확인
           if (message.metadata != null && message.metadata!['type'] == 'discord_button') {
             debugPrint('🔘 [DISCORD BUTTON MESSAGE] Found Discord button message');
             debugPrint('🔘 [DISCORD BUTTON MESSAGE] ID: ${message.id}');
             debugPrint('🔘 [DISCORD BUTTON MESSAGE] Text: ${message.text}');
             debugPrint('🔘 [DISCORD BUTTON MESSAGE] Metadata: ${message.metadata}');
             debugPrint('🔘 [DISCORD BUTTON MESSAGE] HasButton: ${message.metadata!['hasButton']}');
           }
           
           // 최신 Firebase Functions 메시지 ID 검색 
           if (message.id == 'z8GWar3ZkAM5B5c0CPZg') {
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] Found latest message with ID z8GWar3ZkAM5B5c0CPZg');
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] SenderId: ${message.senderId}');
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] Text: ${message.text}');
             debugPrint('🎯🎯🎯 [FOUND LATEST DISCORD MESSAGE] Metadata: ${message.metadata}');
           }
           
           // 방금 Firebase Functions에서 저장한 메시지 ID 검색 
           if (message.id == 'YAktcm7pUZbuO5xwJYtF') {
             debugPrint('🎯🎯🎯 [FOUND DISCORD MESSAGE] Found latest Discord message with ID YAktcm7pUZbuO5xwJYtF');
             debugPrint('🎯🎯🎯 [FOUND DISCORD MESSAGE] SenderId: ${message.senderId}');
             debugPrint('🎯🎯🎯 [FOUND DISCORD MESSAGE] Text: ${message.text}');
             debugPrint('🎯🎯🎯 [FOUND DISCORD MESSAGE] Metadata: ${message.metadata}');
           }
         }
         
         return messages;
       });
 }
}