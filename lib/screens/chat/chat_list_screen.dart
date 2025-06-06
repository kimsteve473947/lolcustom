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

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = false;
  String? _errorMessage;
  List<ChatRoomModel> _chatRooms = [];
  
  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }
  
  Future<void> _loadChatRooms() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (appState.currentUser == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final chatRooms = await _firebaseService.getUserChatRooms(appState.currentUser!.uid);
      
      setState(() {
        _chatRooms = chatRooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '채팅방 목록을 불러오는 중 오류가 발생했습니다: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final currentUser = appState.currentUser;
    
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('채팅'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('로그인이 필요합니다'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  context.go('/login');
                },
                child: const Text('로그인하기'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
        ],
      ),
      body: _errorMessage != null
          ? ErrorView(
              errorMessage: _errorMessage!,
              onRetry: _loadChatRooms,
            )
          : _isLoading
              ? const LoadingIndicator()
              : _chatRooms.isEmpty
                  ? _buildEmptyState()
                  : _buildChatRoomsList(),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            '채팅 내역이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '내전에 참가하거나 용병에게 메시지를 보내면\n여기에 표시됩니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              context.go('/tournaments');
            },
            child: const Text('내전 찾아보기'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChatRoomsList() {
    final currentUserId = Provider.of<AppStateProvider>(context).currentUser!.uid;
    
    return RefreshIndicator(
      onRefresh: _loadChatRooms,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _chatRooms.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final chatRoom = _chatRooms[index];
          final otherParticipantId = chatRoom.participantIds.firstWhere(
            (id) => id != currentUserId,
            orElse: () => currentUserId,
          );
          
          final otherParticipantName = chatRoom.participantNames[otherParticipantId] ?? '알 수 없음';
          final otherParticipantImage = chatRoom.participantProfileImages[otherParticipantId];
          final unreadCount = chatRoom.unreadCount[currentUserId] ?? 0;
          
          return ListTile(
            onTap: () {
              context.push('/chat/${chatRoom.id}');
            },
            leading: CircleAvatar(
              backgroundImage: otherParticipantImage != null
                  ? NetworkImage(otherParticipantImage)
                  : null,
              child: otherParticipantImage == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(
              chatRoom.type == ChatRoomType.direct
                  ? otherParticipantName
                  : chatRoom.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              chatRoom.lastMessageText ?? '메시지 없음',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unreadCount > 0
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (chatRoom.lastMessageTime != null)
                  Text(
                    _formatLastMessageTime(chatRoom.lastMessageTime!.toDate()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 4),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  String _formatLastMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      if (difference.inDays < 7) {
        // Within the week
        return DateFormat('E', 'ko_KR').format(dateTime);
      } else {
        // More than a week
        return DateFormat('MM/dd').format(dateTime);
      }
    } else if (difference.inHours > 0) {
      // Within the day
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      // Within the hour
      return '${difference.inMinutes}분 전';
    } else {
      // Just now
      return '방금 전';
    }
  }
}
