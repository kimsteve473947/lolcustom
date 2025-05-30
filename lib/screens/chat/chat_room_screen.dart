import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatRoomId;

  const ChatRoomScreen({
    Key? key,
    required this.chatRoomId,
  }) : super(key: key);

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  ChatRoomModel? _chatRoom;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadChatRoom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatRoom() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // This is a placeholder until we create a method to get a single chat room
      final chatRooms = await _firebaseService.getUserChatRooms(
        Provider.of<AppStateProvider>(context, listen: false).currentUser!.uid,
      );
      
      final room = chatRooms.firstWhere(
        (room) => room.id == widget.chatRoomId,
        orElse: () => throw Exception('Chat room not found'),
      );
      
      setState(() {
        _chatRoom = room;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load chat room: $e';
      });
    }
  }

  Future<void> _sendMessage() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (appState.currentUser == null || _chatRoom == null || _messageController.text.trim().isEmpty) {
      return;
    }

    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _isSending = true;
    });

    try {
      // Create a map of read status initialized to false for all participants
      Map<String, bool> readStatus = {};
      for (var participantId in _chatRoom!.participantIds) {
        readStatus[participantId] = participantId == appState.currentUser!.uid;
      }

      final message = MessageModel(
        id: '', // Will be set by Firestore
        chatRoomId: _chatRoom!.id,
        senderId: appState.currentUser!.uid,
        senderName: appState.currentUser!.nickname,
        senderProfileImageUrl: appState.currentUser!.profileImageUrl,
        text: messageText,
        readStatus: readStatus,
        timestamp: Timestamp.now(),
      );

      await _firebaseService.sendMessage(message);
      
      // Scroll to bottom after sending
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('메시지 전송 실패: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final currentUser = appState.currentUser;

    return Scaffold(
      appBar: _chatRoom != null ? AppBar(
        title: Text(
          _chatRoom!.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // TODO: Show chat info
            },
          ),
        ],
      ) : AppBar(
        title: const Text('채팅'),
      ),
      body: _errorMessage != null
          ? ErrorView(
              message: _errorMessage!,
              onRetry: _loadChatRoom,
            )
          : _isLoading
              ? const LoadingIndicator()
              : _chatRoom == null
                  ? const Center(child: Text('채팅방을 찾을 수 없습니다'))
                  : Column(
                      children: [
                        Expanded(
                          child: StreamBuilder<List<MessageModel>>(
                            stream: _firebaseService.getChatMessages(_chatRoom!.id),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                                return const LoadingIndicator();
                              }

                              if (snapshot.hasError) {
                                return ErrorView(
                                  message: '메시지를 불러오는 중 오류가 발생했습니다: ${snapshot.error}',
                                  onRetry: () => setState(() {}),
                                );
                              }

                              final messages = snapshot.data ?? [];
                              if (messages.isEmpty) {
                                return const Center(
                                  child: Text(
                                    '아직 메시지가 없습니다.\n첫 메시지를 보내보세요!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                controller: _scrollController,
                                reverse: true,
                                padding: const EdgeInsets.all(16),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final isCurrentUser = currentUser != null && message.senderId == currentUser.uid;
                                  final showAvatar = !isCurrentUser;
                                  
                                  // Group messages by date
                                  final showDateSeparator = index == messages.length - 1 || 
                                      !_isSameDay(messages[index].timestamp.toDate(), messages[index + 1].timestamp.toDate());
                                  
                                  return Column(
                                    children: [
                                      if (showDateSeparator)
                                        _buildDateSeparator(message.timestamp.toDate()),
                                      _buildMessageItem(message, isCurrentUser, showAvatar),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        _buildMessageInput(),
                      ],
                    ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(date.year, date.month, date.day);
    
    String text;
    if (messageDate == DateTime(now.year, now.month, now.day)) {
      text = '오늘';
    } else if (messageDate == yesterday) {
      text = '어제';
    } else {
      text = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(date);
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(MessageModel message, bool isCurrentUser, bool showAvatar) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showAvatar) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: message.senderProfileImageUrl != null
                  ? NetworkImage(message.senderProfileImageUrl!)
                  : null,
              child: message.senderProfileImageUrl == null
                  ? const Icon(Icons.person, size: 16)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          if (!isCurrentUser && !showAvatar)
            const SizedBox(width: 40), // Space for avatar alignment
          Column(
            crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isCurrentUser)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    message.senderName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isCurrentUser) ...[
                    Text(
                      _formatMessageTime(message.timestamp.toDate()),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCurrentUser ? AppColors.primary : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomLeft: isCurrentUser ? const Radius.circular(16) : const Radius.circular(4),
                        bottomRight: isCurrentUser ? const Radius.circular(4) : const Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (!isCurrentUser) ...[
                    const SizedBox(width: 4),
                    Text(
                      _formatMessageTime(message.timestamp.toDate()),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.primary,
            onPressed: () {
              // TODO: Show attachment options
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: '메시지를 입력하세요',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: _isSending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                : const Icon(Icons.send),
            color: AppColors.primary,
            onPressed: _isSending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }
} 