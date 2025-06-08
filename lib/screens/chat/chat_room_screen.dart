import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
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
  bool _isLoading = true;
  String? _errorMessage;
  List<MessageModel> _messages = [];
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
      // Load chat room details
      final chatRoomDoc = await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(widget.chatRoomId)
          .get();
      
      if (!chatRoomDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = '채팅방을 찾을 수 없습니다';
        });
        return;
      }
      
      final chatRoom = ChatRoomModel.fromFirestore(chatRoomDoc);
      
      // Load messages
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('messages')
          .where('chatRoomId', isEqualTo: widget.chatRoomId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      
      final messages = messagesSnapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
      
      // Mark messages as read
      final currentUser = Provider.of<AppStateProvider>(context, listen: false).currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(widget.chatRoomId)
            .update({
              'unreadCount.${currentUser.uid}': 0,
            });
      }
      
      setState(() {
        _chatRoom = chatRoom;
        _messages = messages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '채팅방 정보를 불러오는 중 오류가 발생했습니다: $e';
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    
    final currentUser = Provider.of<AppStateProvider>(context, listen: false).currentUser;
    if (currentUser == null || _chatRoom == null) return;
    
    setState(() {
      _isSending = true;
    });
    
    try {
      // Create read status map (all participants have not read the message)
      final readStatus = <String, bool>{};
      for (final participantId in _chatRoom!.participantIds) {
        readStatus[participantId] = participantId == currentUser.uid;
      }
      
      // Create message model
      final newMessage = MessageModel(
        id: '',  // Will be set by Firestore
        chatRoomId: widget.chatRoomId,
        senderId: currentUser.uid,
        senderName: currentUser.nickname,
        senderProfileImageUrl: currentUser.profileImageUrl,
        text: message,
        readStatus: readStatus,
        timestamp: Timestamp.now(),
      );
      
      // Send message and get ID
      final messageId = await _firebaseService.sendMessage(newMessage);
      
      // Update unread count for all participants except sender
      final batch = FirebaseFirestore.instance.batch();
      final chatRoomRef = FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(widget.chatRoomId);
      
      // Update last message in chat room
      batch.update(chatRoomRef, {
        'lastMessageText': message,
        'lastMessageTime': Timestamp.now(),
      });
      
      // Update unread count for each participant
      for (final participantId in _chatRoom!.participantIds) {
        if (participantId != currentUser.uid) {
          batch.update(chatRoomRef, {
            'unreadCount.$participantId': FieldValue.increment(1),
          });
        }
      }
      
      await batch.commit();
      
      // Clear input
      _messageController.clear();
      
      // Add message to list
      setState(() {
        _messages.insert(0, newMessage.copyWith(id: messageId));
        _isSending = false;
      });
      
      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('메시지를 보내는 중 오류가 발생했습니다: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() {
        _isSending = false;
      });
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

  void _viewTournament(String tournamentId) {
    context.push('/tournaments/$tournamentId');
  }

  void _handleBackNavigation() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // 스택에 이전 화면이 없으면 메인 화면으로 이동
      context.go('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AppStateProvider>(context).currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('채팅'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBackNavigation(),
          ),
        ),
        body: const Center(
          child: Text('로그인이 필요합니다'),
        ),
      );
    }
    
    return WillPopScope(
      onWillPop: () async {
        _handleBackNavigation();
        return false;
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _isLoading
            ? const LoadingIndicator()
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : Column(
                    children: [
                      if (_chatRoom != null && _chatRoom!.type == ChatRoomType.tournamentRecruitment && _chatRoom!.tournamentId != null)
                        _buildTournamentBanner(_chatRoom!.tournamentId!),
                      Expanded(
                        child: _buildMessagesList(currentUser.uid),
                      ),
                      _buildInputArea(),
                    ],
                  ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_chatRoom == null) {
      return AppBar(
        title: const Text('채팅'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBackNavigation(),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      );
    }
    
    final currentUser = Provider.of<AppStateProvider>(context).currentUser!;
    String displayTitle = _chatRoom!.title;
    Widget? leadingTitle;
    
    // 내전 채팅방인 경우 토너먼트 정보 표시
    if (_chatRoom!.type == ChatRoomType.tournamentRecruitment) {
      final tournamentId = _chatRoom!.tournamentId;
      if (tournamentId != null) {
        displayTitle = _chatRoom!.title;
      }
    } 
    // 1:1 채팅인 경우 상대방 이름 표시
    else if (_chatRoom!.type == ChatRoomType.direct) {
      final otherParticipantId = _chatRoom!.participantIds.firstWhere(
        (id) => id != currentUser.uid,
        orElse: () => currentUser.uid,
      );
      
      final otherParticipantName = _chatRoom!.participantNames[otherParticipantId] ?? '알 수 없음';
      final otherParticipantImage = _chatRoom!.participantProfileImages[otherParticipantId];
      
      displayTitle = otherParticipantName;
      
      if (otherParticipantImage != null && otherParticipantImage.isNotEmpty && otherParticipantImage.startsWith('http')) {
        leadingTitle = CircleAvatar(
          backgroundImage: NetworkImage(otherParticipantImage),
          radius: 16,
        );
      } else {
        leadingTitle = const CircleAvatar(
          child: Icon(Icons.person),
          radius: 16,
        );
      }
    }
    
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _handleBackNavigation(),
      ),
      title: Row(
        children: [
          if (leadingTitle != null) ...[
            leadingTitle,
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              displayTitle,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        if (_chatRoom!.type == ChatRoomType.tournamentRecruitment && _chatRoom!.tournamentId != null)
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _viewTournament(_chatRoom!.tournamentId!),
          ),
      ],
    );
  }

  Widget _buildMessagesList(String currentUserId) {
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          '아직 대화가 없습니다\n메시지를 보내 대화를 시작하세요',
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isCurrentUser = message.senderId == currentUserId;
        final showAvatar = index == _messages.length - 1 || 
                           _messages[index + 1].senderId != message.senderId;
        
        return _buildMessageItem(message, isCurrentUser, showAvatar);
      },
    );
  }

  Widget _buildMessageItem(MessageModel message, bool isCurrentUser, bool showAvatar) {
    final time = DateFormat('HH:mm').format(message.timestamp.toDate());
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser && showAvatar)
            CircleAvatar(
              radius: 16,
              backgroundImage: message.senderProfileImageUrl != null && 
                              message.senderProfileImageUrl!.isNotEmpty && 
                              message.senderProfileImageUrl!.startsWith('http')
                  ? NetworkImage(message.senderProfileImageUrl!)
                  : null,
              child: message.senderProfileImageUrl == null || 
                    message.senderProfileImageUrl!.isEmpty || 
                    !message.senderProfileImageUrl!.startsWith('http')
                  ? const Icon(Icons.person, size: 16)
                  : null,
            )
          else if (!isCurrentUser && !showAvatar)
            const SizedBox(width: 32),
            
          const SizedBox(width: 8),
          
          if (!isCurrentUser && showAvatar)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                _buildMessageBubble(message.text, isCurrentUser),
              ],
            )
          else
            _buildMessageBubble(message.text, isCurrentUser),
            
          const SizedBox(width: 8),
          
          Text(
            time,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isCurrentUser) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppColors.primary : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isCurrentUser ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
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
                hintText: '메시지 입력...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
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

  Widget _buildTournamentBanner(String tournamentId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sports_esports,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '이 채팅방은 내전과 연결되어 있습니다',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _viewTournament(tournamentId),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('내전 살펴보기'),
          ),
        ],
      ),
    );
  }
} 