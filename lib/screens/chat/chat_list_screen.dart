import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/utils/date_utils.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = true;
  String? _errorMessage;
  List<ChatRoomModel> _chatRooms = [];
  List<ChatRoomModel> _tournamentChatRooms = [];
  List<ChatRoomModel> _personalChatRooms = [];
  
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadChatRooms();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadChatRooms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      if (appState.currentUser == null) {
        setState(() {
          _errorMessage = '로그인이 필요합니다';
          _isLoading = false;
        });
        return;
      }
      
      // 모든 채팅방 가져오기
      final chatRooms = await _firebaseService.getUserChatRooms(appState.currentUser!.uid);
      
      // 디버그 로그
      debugPrint('Loaded ${chatRooms.length} chat rooms');
      for (final room in chatRooms) {
        debugPrint('Chat room: ${room.id}, title: ${room.title}, type: ${room.type}');
      }
      
      // 내전 채팅과 개인 채팅 분리
      final tournamentChatRooms = chatRooms
          .where((room) => room.type == ChatRoomType.tournamentRecruitment)
          .toList();
      
      final personalChatRooms = chatRooms
          .where((room) => room.type != ChatRoomType.tournamentRecruitment)
          .toList();
      
      setState(() {
        _chatRooms = chatRooms;
        _tournamentChatRooms = tournamentChatRooms;
        _personalChatRooms = personalChatRooms;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading chat rooms: $e');
      setState(() {
        _errorMessage = '채팅방 목록을 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChatRooms,
          ),
        ],
      ),
      body: _buildContent(),
    );
  }
  
  Widget _buildContent() {
    if (_isLoading) {
      return const LoadingIndicator();
    } else if (_errorMessage != null) {
      return ErrorView(
        errorMessage: _errorMessage!,
        onRetry: _loadChatRooms,
      );
    } else if (_chatRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '참여 중인 채팅방이 없습니다',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChatRooms,
              child: const Text('새로고침'),
            ),
            const SizedBox(height: 16),
            // 테스트용 버튼 추가
            ElevatedButton(
              onPressed: _createTestChatRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('테스트 채팅방 생성'),
            ),
          ],
        ),
      );
    } else {
      return RefreshIndicator(
        onRefresh: () async {
          await _loadChatRooms();
        },
        child: ListView.builder(
          itemCount: _chatRooms.length,
          itemBuilder: (context, index) {
            final chatRoom = _chatRooms[index];
            return _buildChatRoomItem(chatRoom);
          },
        ),
      );
    }
  }
  
  // 테스트용 채팅방 생성 메서드
  Future<void> _createTestChatRoom() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      if (appState.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
        return;
      }
      
      final currentUser = appState.currentUser!;
      
      // 채팅방 참가자 초기화 (현재 사용자만 포함)
      final participantIds = [currentUser.uid];
      final participantNames = {currentUser.uid: currentUser.nickname};
      final participantProfileImages = {currentUser.uid: currentUser.profileImageUrl};
      final unreadCount = {currentUser.uid: 0};
      
      // 채팅방 모델 생성
      final chatRoom = ChatRoomModel(
        id: '', // Firestore에서 자동 생성될 ID
        title: '테스트 채팅방 ${DateTime.now().millisecondsSinceEpoch}',
        participantIds: participantIds,
        participantNames: participantNames,
        participantProfileImages: participantProfileImages,
        unreadCount: unreadCount,
        type: ChatRoomType.direct,
        createdAt: Timestamp.now(),
        lastMessageTime: Timestamp.now(), // 메시지 정렬을 위해 마지막 메시지 시간 설정
      );
      
      // 채팅방 생성
      final chatRoomId = await FirebaseService().createChatRoom(chatRoom);
      debugPrint('Created test chat room with ID: $chatRoomId');
      
      // 시스템 메시지 전송
      final message = MessageModel(
        id: '',
        chatRoomId: chatRoomId,
        senderId: 'system',
        senderName: '시스템',
        text: '테스트 채팅방이 생성되었습니다.',
        readStatus: {},
        timestamp: Timestamp.now(),
        metadata: {'isSystem': true},
      );
      
      await FirebaseService().sendMessage(message);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('테스트 채팅방이 생성되었습니다. ID: $chatRoomId'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 채팅방 목록 새로고침
      await _loadChatRooms();
    } catch (e) {
      setState(() {
        _errorMessage = '채팅방 생성 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('채팅방 생성 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildChatRoomItem(ChatRoomModel chatRoom) {
    // 상대방 이름 표시 (자신 제외)
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    String displayName = chatRoom.title;
    String? displayImage;
    
    if (chatRoom.type == ChatRoomType.direct && appState.currentUser != null) {
      // 1:1 채팅인 경우 상대방 이름 표시
      final otherParticipants = chatRoom.participantIds
          .where((id) => id != appState.currentUser!.uid)
          .toList();
      
      if (otherParticipants.isNotEmpty) {
        final otherUserId = otherParticipants.first;
        displayName = chatRoom.participantNames[otherUserId] ?? '알 수 없음';
        displayImage = chatRoom.participantProfileImages[otherUserId];
      }
    }
    
    // 읽지 않은 메시지 수
    final unreadCount = appState.currentUser != null
        ? chatRoom.unreadCount[appState.currentUser!.uid] ?? 0
        : 0;
    
    // 마지막 메시지 시간
    String lastMessageTime = '';
    if (chatRoom.lastMessageTime != null) {
      final messageTime = chatRoom.lastMessageTime!.toDate();
      
      if (isToday(messageTime)) {
        // 오늘
        lastMessageTime = formatTime(messageTime);
      } else if (isYesterday(messageTime)) {
        // 어제
        lastMessageTime = '어제';
      } else {
        // 그 외
        lastMessageTime = formatDate(messageTime);
      }
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.2),
          backgroundImage: displayImage != null && displayImage.isNotEmpty && displayImage.startsWith('http') 
              ? NetworkImage(displayImage) 
              : null,
          child: displayImage == null || displayImage.isEmpty || !displayImage.startsWith('http')
              ? Icon(
                  chatRoom.type == ChatRoomType.tournamentRecruitment
                      ? Icons.group
                      : Icons.person,
                  color: AppColors.primary,
                )
              : null,
        ),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          chatRoom.lastMessageText ?? '새로운 채팅방',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              lastMessageTime,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        onTap: () {
          // 채팅 상세 화면으로 이동
          context.go('/chat/${chatRoom.id}');
        },
      ),
    );
  }
}
