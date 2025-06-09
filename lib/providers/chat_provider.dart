import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/models/chat_model.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/services/chat_service.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/services/tournament_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;
  final FirebaseService _firebaseService;
  final TournamentService _tournamentService;

  List<ChatRoomModel> _chatRooms = [];
  List<ChatRoomModel> _tournamentChatRooms = [];
  List<ChatRoomModel> _personalChatRooms = [];
  Map<String, List<MessageModel>> _messages = {};
  Map<String, List<Map<String, dynamic>>> _chatRoomMembers = {};
  
  bool _isLoading = false;
  String? _error;
  
  // 생성자를 통한 의존성 주입
  ChatProvider({
    ChatService? chatService,
    FirebaseService? firebaseService,
    TournamentService? tournamentService,
  })  : _chatService = chatService ?? ChatService(),
        _firebaseService = firebaseService ?? FirebaseService(),
        _tournamentService = tournamentService ?? TournamentService();
  
  // Getters
  List<ChatRoomModel> get chatRooms => _chatRooms;
  List<ChatRoomModel> get tournamentChatRooms => _tournamentChatRooms;
  List<ChatRoomModel> get personalChatRooms => _personalChatRooms;
  Map<String, List<MessageModel>> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 사용자의 채팅방 목록 로드
  Future<void> loadUserChatRooms(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final chatRooms = await _firebaseService.getUserChatRooms(userId);
      
      // 디버그 로그
      debugPrint('Loaded ${chatRooms.length} chat rooms');
      
      // 내전 채팅과 개인 채팅 분리
      final tournamentChatRooms = chatRooms
          .where((room) => room.type == ChatRoomType.tournamentRecruitment)
          .toList();
      
      final personalChatRooms = chatRooms
          .where((room) => room.type != ChatRoomType.tournamentRecruitment)
          .toList();
      
      _chatRooms = chatRooms;
      _tournamentChatRooms = tournamentChatRooms;
      _personalChatRooms = personalChatRooms;
      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading chat rooms: $e');
      _error = '채팅방 목록을 불러오는 중 오류가 발생했습니다: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // 토너먼트 생성 후 채팅방 목록 새로고침
  Future<void> refreshChatRoomsAfterTournamentCreation(String tournamentId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    
    debugPrint('=== 토너먼트 생성 후 채팅방 목록 새로고침 시작 ===');
    
    // 사용자의 모든 채팅방 다시 로드
    await loadUserChatRooms(currentUserId);
    
    debugPrint('채팅방 목록 새로고침 완료: ${_chatRooms.length}개 채팅방, ${_tournamentChatRooms.length}개 토너먼트 채팅방');
    
    // 특정 토너먼트 채팅방 확인 (채팅방 ID가 토너먼트 ID와 동일)
    try {
      // 먼저 Firestore에서 직접 채팅방 문서 확인
      final chatRoomDoc = await FirebaseFirestore.instance.collection('chatRooms').doc(tournamentId).get();
      
      if (chatRoomDoc.exists) {
        debugPrint('토너먼트 채팅방 존재 확인: ID=$tournamentId');
        
        // 캐시된 목록에 없으면 다시 로드
        if (!_chatRooms.any((room) => room.id == tournamentId)) {
          debugPrint('캐시에 해당 채팅방이 없어 목록 새로고침');
          await loadUserChatRooms(currentUserId);
        }
      } else {
        debugPrint('!!! 경고: 토너먼트 채팅방이 Firestore에 존재하지 않음: ID=$tournamentId !!!');
      }
      
      debugPrint('토너먼트 채팅방 목록 새로고침 완료: ID=$tournamentId');
    } catch (e) {
      debugPrint('토너먼트 채팅방 확인 중 오류: $e');
    }
  }

  // 토너먼트에 대한 채팅방 가져오기 또는 생성
  Future<String?> getOrCreateTournamentChatRoom(
    TournamentModel tournament,
    UserModel currentUser,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final chatRoomId = await _chatService.getOrCreateTournamentChatRoom(
        tournament,
        currentUser,
      );
      
      _isLoading = false;
      notifyListeners();
      return chatRoomId;
    } catch (e) {
      debugPrint('Error in getOrCreateTournamentChatRoom: $e');
      _error = '채팅방 연결 중 오류가 발생했습니다: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // 채팅방 메시지 로드
  Future<void> loadChatMessages(String chatRoomId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // 읽지 않은 메시지 카운트 초기화
      await _markMessagesAsRead(chatRoomId);
      
      // Stream 설정 - 실시간 업데이트
      _firebaseService.getChatMessages(chatRoomId).listen((messagesList) {
        _messages[chatRoomId] = messagesList;
        notifyListeners();
      });
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading chat messages: $e');
      _error = '메시지를 불러오는 중 오류가 발생했습니다: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // 채팅방 참가자 목록 로드
  Future<void> loadChatRoomMembers(String chatRoomId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final members = await _chatService.getChatRoomMembers(chatRoomId);
      _chatRoomMembers[chatRoomId] = members;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading chat room members: $e');
      _error = '참가자 목록을 불러오는 중 오류가 발생했습니다: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // 특정 채팅방의 참가자 목록 가져오기
  List<Map<String, dynamic>> getChatRoomMembers(String chatRoomId) {
    return _chatRoomMembers[chatRoomId] ?? [];
  }

  // 메시지 전송
  Future<bool> sendMessage(
    String chatRoomId,
    String text,
    UserModel sender,
  ) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // 채팅방 정보 가져오기
      final chatRoomDoc = await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
      
      if (!chatRoomDoc.exists) {
        _error = '채팅방을 찾을 수 없습니다';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      final chatRoom = ChatRoomModel.fromFirestore(chatRoomDoc);
      
      // 읽음 상태 생성
      final readStatus = <String, bool>{};
      for (final participantId in chatRoom.participantIds) {
        readStatus[participantId] = participantId == sender.uid;
      }
      
      // 메시지 모델 생성
      final message = MessageModel(
        id: '',
        chatRoomId: chatRoomId,
        senderId: sender.uid,
        senderName: sender.nickname,
        senderProfileImageUrl: sender.profileImageUrl,
        text: text,
        readStatus: readStatus,
        timestamp: Timestamp.now(),
      );
      
      // 메시지 전송
      await _firebaseService.sendMessage(message);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      _error = '메시지를 보내는 중 오류가 발생했습니다: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 읽지 않은 메시지 수 초기화
  Future<void> _markMessagesAsRead(String chatRoomId) async {
    try {
      // Firebase에서 현재 사용자의 UID 가져오기
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      // 읽지 않은 메시지 수 초기화
      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(chatRoomId)
          .update({
            'unreadCount.${currentUser.uid}': 0,
          });
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  // 채팅방 나가기 (토너먼트 신청 취소 포함)
  Future<bool> leaveTournamentChatRoom(
    String chatRoomId,
    UserModel user,
    BuildContext context,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // 채팅방 정보 가져오기
      final chatRoomDoc = await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
      
      if (!chatRoomDoc.exists) {
        _error = '채팅방을 찾을 수 없습니다';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      final chatRoom = ChatRoomModel.fromFirestore(chatRoomDoc);
      
      // 토너먼트 ID 확인
      if (chatRoom.tournamentId == null) {
        _error = '토너먼트 정보를 찾을 수 없습니다';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // 토너먼트 정보 가져오기
      final tournament = await _tournamentService.getTournament(chatRoom.tournamentId!);
      if (tournament == null) {
        _error = '토너먼트 정보를 찾을 수 없습니다';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // 사용자 역할 찾기
      String userRole = 'unknown';
      for (final role in ['top', 'jungle', 'mid', 'adc', 'support']) {
        final participants = tournament.participantsByRole[role] ?? [];
        if (participants.contains(user.uid)) {
          userRole = role;
          break;
        }
      }
      
      // 확인 다이얼로그 표시
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('채팅방 나가기'),
          content: const Text('나가면 토너먼트 신청이 취소됩니다. 계속하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('확인', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ) ?? false;
      
      if (!confirmed) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // 채팅방 나가기 처리
      await _chatService.leaveTournamentChatRoom(
        chatRoomId,
        chatRoom.tournamentId!,
        user,
        userRole,
      );
      
      // 채팅방 목록 다시 로드
      await loadUserChatRooms(user.uid);
      
      return true;
    } catch (e) {
      debugPrint('Error leaving chat room: $e');
      _error = '채팅방을 나가는 중 오류가 발생했습니다: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
} 