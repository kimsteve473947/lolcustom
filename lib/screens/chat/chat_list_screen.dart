import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = false;
  String? _errorMessage;
  List<ChatRoomModel> _chatRooms = [];
  
  late TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index;
      });
      _loadChatRooms();
    });
    _loadChatRooms();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      
      // Filter chat rooms based on the selected tab
      List<ChatRoomModel> filteredRooms = chatRooms.where((room) {
        if (_selectedTab == 0) {
          return room.type == ChatRoomType.tournamentRecruitment;
        } else {
          return room.type == ChatRoomType.mercenaryOffer;
        }
      }).toList();
      
      setState(() {
        _chatRooms = filteredRooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load chat rooms: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '메시지',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: '용병구함'),
            Tab(text: '용병있음'),
          ],
        ),
      ),
      body: _errorMessage != null
          ? ErrorView(
              message: _errorMessage!,
              onRetry: _loadChatRooms,
            )
          : _isLoading
              ? const LoadingIndicator()
              : _chatRooms.isEmpty
                  ? _buildEmptyState()
                  : _buildChatRoomsList(),
    );
  }

  Widget _buildChatRoomsList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _chatRooms.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final chatRoom = _chatRooms[index];
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        final currentUserId = appState.currentUser?.uid;
        final unreadCount = currentUserId != null ? chatRoom.unreadCount[currentUserId] ?? 0 : 0;
        
        return ListTile(
          onTap: () {
            context.push('/chat/${chatRoom.id}');
          },
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.2),
            child: Icon(
              _selectedTab == 0 ? Icons.sports_soccer : Icons.person_search,
              color: AppColors.primary,
            ),
          ),
          title: Text(
            chatRoom.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: chatRoom.lastMessageText != null
              ? Text(
                  chatRoom.lastMessageText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                )
              : const Text(
                  '새로운 채팅방이 생성되었습니다',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (chatRoom.lastMessageTime != null)
                Text(
                  _formatLastMessageTime(chatRoom.lastMessageTime!),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 4),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedTab == 0 ? Icons.sports_soccer : Icons.person_search,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedTab == 0 ? '용병구함 채팅이 없습니다' : '용병있음 채팅이 없습니다',
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '메시지를 받으면 여기에 표시됩니다',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays < 7) {
      return DateFormat('E', 'ko_KR').format(dateTime);
    } else {
      return DateFormat('MM/dd').format(dateTime);
    }
  }
} 