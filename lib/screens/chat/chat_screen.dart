import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/chat_model.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;

  const ChatScreen({
    Key? key,
    required this.chatRoomId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = true;
  bool _isSendingMessage = false;
  ChatRoomModel? _chatRoom;
  List<ChatMessageModel> _messages = [];
  String? _currentUserId;
  
  @override
  void initState() {
    super.initState();
    _initChat();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _initChat() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      _currentUserId = appState.currentUser?.uid;
      
      if (_currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
        Navigator.pop(context);
        return;
      }
      
      // 채팅방 정보 로드
      final chatRoom = await _firebaseService.getChatRoom(widget.chatRoomId);
      
      if (chatRoom == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('채팅방을 찾을 수 없습니다')),
        );
        Navigator.pop(context);
        return;
      }
      
      // 메시지 읽음 처리
      await _firebaseService.markMessagesAsRead(widget.chatRoomId, _currentUserId!);
      
      setState(() {
        _chatRoom = chatRoom;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('채팅 초기화 중 오류가 발생했습니다: $e')),
      );
    }
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    
    if (message.isEmpty || _currentUserId == null || _chatRoom == null) {
      return;
    }
    
    setState(() {
      _isSendingMessage = true;
    });
    
    try {
      // 메시지 전송
      await _firebaseService.sendChatMessage(
        widget.chatRoomId,
        message,
        _currentUserId!,
        'text',
      );
      
      // 채팅방 업데이트
      final unreadCount = Map<String, dynamic>.from(_chatRoom!.unreadCount);
      
      // 다른 참가자들의 안 읽은 메시지 수 증가
      for (final participantId in _chatRoom!.participantIds) {
        if (participantId != _currentUserId) {
          unreadCount[participantId] = (unreadCount[participantId] ?? 0) + 1;
        }
      }
      
      await _firebaseService.createOrUpdateChatRoom(
        widget.chatRoomId,
        {
          'lastMessageText': message,
          'lastMessageTime': Timestamp.now(),
          'lastMessageSenderId': _currentUserId,
          'unreadCount': unreadCount,
        },
      );
      
      // 메시지 입력창 초기화 및 스크롤
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('메시지 전송 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        _isSendingMessage = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? const LoadingIndicator()
          : Column(
              children: [
                Expanded(child: _buildMessageList()),
                _buildMessageInput(),
              ],
            ),
    );
  }
  
  AppBar _buildAppBar() {
    if (_isLoading || _chatRoom == null || _currentUserId == null) {
      return AppBar(
        title: const Text('채팅'),
      );
    }
    
    final otherUser = _chatRoom!.getOtherParticipant(_currentUserId!);
    
    return AppBar(
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: otherUser?['profileImageUrl'] != null
                ? NetworkImage(otherUser!['profileImageUrl'])
                : null,
            child: otherUser?['profileImageUrl'] == null
                ? const Icon(Icons.person, size: 18)
                : null,
          ),
          const SizedBox(width: 8),
          Text(_chatRoom!.getChatRoomTitle(_currentUserId!)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            // 채팅방 메뉴 (나가기, 신고 등)
          },
        ),
      ],
    );
  }
  
  Widget _buildMessageList() {
    return StreamBuilder<List<ChatMessageModel>>(
      stream: _firebaseService.getChatMessages(widget.chatRoomId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _messages.isEmpty) {
          return const LoadingIndicator();
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('메시지를 불러오는 중 오류가 발생했습니다: ${snapshot.error}'),
          );
        }
        
        _messages = snapshot.data ?? [];
        
        if (_messages.isEmpty) {
          return const Center(
            child: Text('메시지가 없습니다. 첫 메시지를 보내보세요!'),
          );
        }
        
        // 날짜별로 메시지 그룹화
        final Map<String, List<ChatMessageModel>> messagesByDate = {};
        
        for (final message in _messages) {
          final date = DateFormat('yyyy-MM-dd').format(message.createdAt.toDate());
          messagesByDate.putIfAbsent(date, () => []);
          messagesByDate[date]!.add(message);
        }
        
        // 날짜 정렬
        final sortedDates = messagesByDate.keys.toList()
          ..sort((a, b) => b.compareTo(a));
        
        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.all(16),
          itemCount: sortedDates.length,
          itemBuilder: (context, dateIndex) {
            final date = sortedDates[dateIndex];
            final dateMessages = messagesByDate[date]!;
            
            return Column(
              children: [
                _buildDateDivider(date),
                ...dateMessages.map((message) => _buildMessageItem(message)).toList(),
                if (dateIndex == sortedDates.length - 1)
                  const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }
  
  Widget _buildDateDivider(String date) {
    final now = DateTime.now();
    final messageDate = DateFormat('yyyy-MM-dd').parse(date);
    final difference = now.difference(messageDate).inDays;
    
    String dateText;
    if (difference == 0) {
      dateText = '오늘';
    } else if (difference == 1) {
      dateText = '어제';
    } else {
      dateText = DateFormat('yyyy년 M월 d일').format(messageDate);
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.grey.shade300,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageItem(ChatMessageModel message) {
    final isCurrentUser = message.senderId == _currentUserId;
    final isSystemMessage = message.type == 'system';
    
    if (isSystemMessage) {
      return _buildSystemMessage(message);
    }
    
    final messageTime = DateFormat('HH:mm').format(message.createdAt.toDate());
    
    if (isCurrentUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              messageTime,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  message.message,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      final sender = _chatRoom?.getParticipantInfo(message.senderId);
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: sender?['profileImageUrl'] != null
                  ? NetworkImage(sender!['profileImageUrl'])
                  : null,
              child: sender?['profileImageUrl'] == null
                  ? const Icon(Icons.person, size: 16)
                  : null,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sender?['nickname'] ?? '알 수 없는 사용자',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.6,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(message.message),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      messageTime,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }
  }
  
  Widget _buildSystemMessage(ChatMessageModel message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.message,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: () {
              // 이미지 첨부 기능
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: '메시지를 입력하세요',
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: _isSendingMessage
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send, color: AppColors.primary),
            onPressed: _isSendingMessage ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
} 