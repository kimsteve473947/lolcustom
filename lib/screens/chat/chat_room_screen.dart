import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/chat_model.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/chat_service.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late Future<ChatRoomModel> _chatRoomFuture;
  bool _isSending = false;
  TournamentModel? _tournament;
  bool _isLoadingDiscord = false;

  @override
  void initState() {
    super.initState();
    _chatRoomFuture = _loadChatRoomDetails();
    _markAsRead();
  }

  Future<ChatRoomModel> _loadChatRoomDetails() async {
    final doc = await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .get();
    if (!doc.exists) {
      throw Exception('채팅방을 찾을 수 없습니다.');
    }
    
    final chatRoom = ChatRoomModel.fromFirestore(doc);
    
    // 토너먼트 채팅방인 경우 토너먼트 정보 로드
    if (chatRoom.type == ChatRoomType.tournamentRecruitment && chatRoom.tournamentId != null) {
      try {
        _tournament = await FirebaseService().getTournament(chatRoom.tournamentId!);
      } catch (e) {
        debugPrint('토너먼트 정보 로드 실패: $e');
      }
    }
    
    return chatRoom;
  }

  Future<void> _markAsRead() async {
    final currentUser = Provider.of<AppStateProvider>(context, listen: false).currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(widget.chatRoomId)
          .update({'unreadCount.${currentUser.uid}': 0});
    }
  }

  Future<void> _sendMessage(ChatRoomModel chatRoom) async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final currentUser = Provider.of<AppStateProvider>(context, listen: false).currentUser;
    if (currentUser == null) return;

    setState(() => _isSending = true);

    final message = MessageModel(
      id: '', // Firestore will generate
      chatRoomId: widget.chatRoomId,
      senderId: currentUser.uid,
      senderName: currentUser.nickname,
      senderProfileImageUrl: currentUser.profileImageUrl,
      text: messageText,
      readStatus: { for (var id in chatRoom.participantIds) id : id == currentUser.uid },
      timestamp: Timestamp.now(),
    );

    try {
      await FirebaseService().sendMessage(message);
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('전송 실패'),
            content: Text('메시지 전송에 실패했습니다: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
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

  // 채팅방 나가기 확인 및 처리
  Future<void> _leaveChatRoom() async {
    final currentUser = Provider.of<AppStateProvider>(context, listen: false).currentUser;
    if (currentUser == null) return;

    final chatRoom = await _chatRoomFuture;
    final tournament = chatRoom.tournamentId != null
        ? await FirebaseService().getTournament(chatRoom.tournamentId!)
        : null;

    bool isHost = tournament != null && tournament.hostId == currentUser.uid;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isHost ? '토너먼트 삭제' : '채팅방 나가기'),
        content: Text(isHost
            ? '주최자는 토너먼트를 삭제 후 채팅방을 나갈 수 있습니다. 토너먼트를 삭제하시겠습니까?'
            : '채팅방을 나가면 채팅 목록에서 사라집니다. 정말 나가시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isHost ? '삭제' : '나가기', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        if (isHost && tournament != null) {
          // 주최자인 경우 토너먼트 삭제
          await appState.deleteTournament(tournament.id);
          if (mounted) {
            // 성공 메시지는 AlertDialog보다는 SnackBar가 더 적합할 수 있으나, 일관성을 위해 변경
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('알림'),
                content: const Text('토너먼트가 성공적으로 취소되었습니다.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('확인'),
                  ),
                ],
              ),
            );
            context.go('/main'); // 삭제 완료 후 메인 화면으로 이동
          }
        } else if (chatRoom.type == ChatRoomType.tournamentRecruitment && tournament != null) {
          // 일반 참가자인 경우 토너먼트에서 나가기
          final userRole = tournament.participantsByRole.entries
              .firstWhere((entry) => entry.value.contains(currentUser.uid), orElse: () => const MapEntry('', <String>[]))
              .key;
          if (userRole.isNotEmpty) {
            // 토너먼트 채팅방에서 나가기 처리 (채팅방 + 토너먼트 모두 처리)
            await _chatService.leaveTournamentChatRoom(
              widget.chatRoomId,
              tournament.id,
              currentUser,
              userRole
            );
          }
          context.pop(); // 현재 채팅방 화면 닫기
        } else {
          // 일반 채팅방 나가기
          await _chatService.leaveChatRoom(widget.chatRoomId, currentUser.uid);
          context.pop(); // 현재 채팅방 화면 닫기
        }
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('오류'),
              content: Text('처리 중 오류가 발생했습니다: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      }
    }
  }
  
  // 뒤로 가기 - 애니메이션 없이 즉시 이동
  void _navigateBack() {
    if (mounted) {
      context.go('/chat');
    }
  }

  // 채팅방 멤버 목록 모달 표시
  void _showMembersModal(ChatRoomModel chatRoom) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getTournamentMembersWithRoles(chatRoom),
          builder: (context, snapshot) {
            final members = snapshot.data ?? [];
            final isLoading = !snapshot.hasData;
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // 드래그 핸들
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '참가자 목록',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // 참가자 수 - 토너먼트의 경우 총 슬롯 수를 함께 표시
                        Text(
                          chatRoom.type == ChatRoomType.tournamentRecruitment
                              ? '${members.length}/${chatRoom.participantIds.length}' // TODO: Fix total slots
                              : '${members.length}',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  isLoading
                      ? const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : members.isEmpty
                          ? const Expanded(
                              child: Center(
                                child: Text(
                                  '참가자가 없습니다',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            )
                          : Expanded(
                              child: ListView.builder(
                                itemCount: members.length,
                                itemBuilder: (context, index) {
                                  final member = members[index];
                                  final isHost = member['isHost'] ?? false;
                                  
                                  return ListTile(
                                    onTap: () {
                                      Navigator.of(context).pop(); // Close the modal
                                      context.push('/profile/${member['userId']}');
                                    },
                                    leading: Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundImage: member['profileImageUrl'] != null
                                              ? NetworkImage(member['profileImageUrl'])
                                              : null,
                                          backgroundColor: member['profileImageUrl'] == null
                                              ? Colors.grey.shade200
                                              : null,
                                          child: member['profileImageUrl'] == null
                                              ? const Icon(Icons.person, color: Colors.grey)
                                              : null,
                                        ),
                                        if (isHost)
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 1.5),
                                              ),
                                              child: Icon(
                                                Icons.star,
                                                size: 10,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          member['nickname'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (isHost)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '주최자',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      '${_getRoleNameKorean(member['role'] ?? '')}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    trailing: member['role'] != null
                                        ? _buildRoleChip(member['role'])
                                        : null,
                                  );
                                },
                              ),
                            ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 토너먼트 멤버 정보를 역할과 함께 가져오는 메서드
  Future<List<Map<String, dynamic>>> _getTournamentMembersWithRoles(ChatRoomModel chatRoom) async {
    try {
      List<Map<String, dynamic>> result = [];
      
      if (chatRoom.tournamentId != null) {
        final tournamentDoc = await FirebaseFirestore.instance.collection('tournaments').doc(chatRoom.tournamentId).get();
        if(tournamentDoc.exists) {
          final tournament = TournamentModel.fromFirestore(tournamentDoc);
          for (String userId in tournament.participants) {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
            if (userDoc.exists) {
              String? role;
              for (var entry in tournament.participantsByRole.entries) {
                if (entry.value.contains(userId)) {
                  role = entry.key;
                  break;
                }
              }
              final userData = userDoc.data() as Map<String, dynamic>;
              result.add({
                'userId': userId,
                'nickname': userData['nickname'] ?? 'Unknown',
                'profileImageUrl': userData['profileImageUrl'],
                'role': role,
                'isHost': userId == tournament.hostId,
              });
            }
          }
        }
      } else {
        for (String userId in chatRoom.participantIds) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            result.add({
              'userId': userId,
              'nickname': userData['nickname'] ?? 'Unknown',
              'profileImageUrl': userData['profileImageUrl'],
              'createdAt': Timestamp.now(),
            });
          }
        }
      }
      
      return result;
    } catch (e) {
      debugPrint('멤버 정보 가져오기 오류: $e');
      return [];
    }
  }

  // 역할 이름을 한글로 변환
  String _getRoleNameKorean(String role) {
    switch (role.toLowerCase()) {
      case 'top':
        return '탑';
      case 'jungle':
        return '정글';
      case 'mid':
        return '미드';
      case 'adc':
        return '원딜';
      case 'support':
        return '서폿';
      default:
        return role;
    }
  }

  // 역할 칩 위젯
  Widget _buildRoleChip(String role) {
    Color chipColor;
    String roleName = _getRoleNameKorean(role);
    
    switch (role.toLowerCase()) {
      case 'top':
        chipColor = Colors.red.shade200;
        break;
      case 'jungle':
        chipColor = Colors.green.shade200;
        break;
      case 'mid':
        chipColor = Colors.blue.shade200;
        break;
      case 'adc':
        chipColor = Colors.amber.shade200;
        break;
      case 'support':
        chipColor = Colors.purple.shade200;
        break;
      default:
        chipColor = Colors.grey.shade200;
    }
    
    return Chip(
      label: Text(roleName),
      backgroundColor: chipColor,
      labelStyle: const TextStyle(fontSize: 12),
      visualDensity: VisualDensity.compact,
    );
  }

  // 참가자 수를 표시하는 메서드
  String _getParticipantCountDisplay() {
    // 토너먼트가 있고, 채팅방이 토너먼트 타입인 경우
    // This method is no longer reliable as _tournament and _chatRoom are gone.
    // The logic is moved inside the widgets.
    return '';
    
    return '0/10명';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatRoomModel>(
      future: _chatRoomFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorView(
              errorMessage: snapshot.error?.toString() ?? '채팅방을 불러올 수 없습니다.',
              onRetry: () => setState(() {
                _chatRoomFuture = _loadChatRoomDetails();
              }),
            ),
          );
        }

        final chatRoom = snapshot.data!;
        
        return Scaffold(
          appBar: _buildAppBar(context, chatRoom),
          body: Column(
            children: [
              // Discord 버튼 (조건에 맞을 때만 표시)
              _buildDiscordButton(chatRoom),
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: _chatService.getMessagesStream(widget.chatRoomId),
                  builder: (context, messagesSnapshot) {
                    if (messagesSnapshot.connectionState == ConnectionState.waiting && !messagesSnapshot.hasData) {
                      return const LoadingIndicator();
                    }
                    if (messagesSnapshot.hasError) {
                      return ErrorView(errorMessage: '메시지를 불러오는 중 오류 발생: ${messagesSnapshot.error}');
                    }
                    final messages = messagesSnapshot.data ?? [];
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isCurrentUser = message.senderId == Provider.of<AppStateProvider>(context, listen: false).currentUser?.uid;
                        final isSystemMessage = message.senderId == 'system';
                        return _buildMessageItem(message, isCurrentUser, isSystemMessage);
                      },
                    );
                  },
                ),
              ),
              _buildMessageInput(chatRoom),
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, ChatRoomModel chatRoom) {
    String title = chatRoom.title;
    if (chatRoom.type == ChatRoomType.direct) {
      final currentUser = Provider.of<AppStateProvider>(context, listen: false).currentUser;
      final otherUserId = chatRoom.participantIds.firstWhere((id) => id != currentUser?.uid, orElse: () => '');
      title = chatRoom.participantNames[otherUserId] ?? '상대방';
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        onPressed: () => _navigateBack(),
      ),
      title: GestureDetector(
        onTap: () => _showMembersModal(chatRoom),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (chatRoom.type == ChatRoomType.tournamentRecruitment)
                    Text(
                      '${chatRoom.participantIds.length}명',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 개발자 전용 새로고침 버튼
            if (Provider.of<AppStateProvider>(context, listen: false).currentUser?.email == 'kimjh473954@gmail.com')
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.blue),
                onPressed: () {
                  setState(() {
                    // StreamBuilder를 강제로 새로고침
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🔄 메시지 새로고침 중...')),
                  );
                },
              ),
            const Icon(Icons.people, color: Colors.grey),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.black),
          onPressed: () => _leaveChatRoom(),
        ),
      ],
    );
  }

  Widget _buildMessageInput(ChatRoomModel chatRoom) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 3,
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: '메시지 입력...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onSubmitted: (_) => _sendMessage(chatRoom),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _isSending
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              onPressed: _isSending ? null : () => _sendMessage(chatRoom),
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(
    MessageModel message,
    bool isCurrentUser,
    bool isSystemMessage,
  ) {
    final timestamp = DateFormat('HH:mm').format(message.timestamp.toDate());
    
    // 시스템 메시지
    if (isSystemMessage) {
      debugPrint('System message: ${message.text}');
      debugPrint('System message metadata: ${message.metadata}');
      
      // Discord 초대링크 메시지 특별 처리
      if (message.metadata != null && message.metadata!['type'] == 'discord_invite') {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16.0),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF5865F2).withOpacity(0.1),
                border: Border.all(color: const Color(0xFF5865F2).withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.discord,
                        size: 24,
                        color: const Color(0xFF5865F2),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Discord 채널이 생성되었습니다!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5865F2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // 텍스트 채팅 링크
                  if (message.metadata!['discordInvites'] != null) ...[
                    _buildDiscordLinkButton(
                      '💬 텍스트 채팅방 입장하기',
                      message.metadata!['discordInvites']['text'],
                      isPrimary: true,
                    ),
                    const SizedBox(height: 8),
                    
                    // 음성 채팅 링크들
                    Row(
                      children: [
                        Expanded(
                          child: _buildDiscordLinkButton(
                            '🎤 A팀 음성',
                            message.metadata!['discordInvites']['voice1'],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDiscordLinkButton(
                            '🎤 B팀 음성',
                            message.metadata!['discordInvites']['voice2'],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }
      
      // Discord 버튼 메시지 특별 처리 (이전 버전 호환)
      if (message.metadata != null && message.metadata!['type'] == 'discord_button') {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16.0),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.discord,
                    size: 32,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _getDiscordInviteLink(message.metadata!['tournamentId']),
                    icon: const Icon(Icons.link, color: Colors.white),
                    label: const Text(
                      'Discord 초대링크 받기',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      
      // 일반 시스템 메시지 처리
      // 원본 메시지 텍스트
      String displayText = message.text;
      
      try {
        // 참가 메시지 처리
        if (displayText.contains('님이 채팅방에 참가했습니다')) {
          // 1. 메타데이터에서 역할 정보 확인
          String? role;
          int? currentCount;
          int? totalSlots;
          
          if (message.metadata != null) {
            role = message.metadata!['role'] as String?;
            currentCount = message.metadata!['currentCount'] as int?;
            totalSlots = message.metadata!['totalSlots'] as int?;
            debugPrint('Found metadata - role: $role, currentCount: $currentCount, totalSlots: $totalSlots');
    }
    
          // 2. 닉네임 추출
          final nicknameEndIndex = displayText.indexOf('님이 채팅방에 참가했습니다');
          if (nicknameEndIndex > 0) {
            final nickname = displayText.substring(0, nicknameEndIndex);
    
            // 3. 역할 정보 추가
            if (role != null && role != 'unknown') {
              final roleDisplayName = _getRoleNameKorean(role);
              displayText = "$nickname[$roleDisplayName]님이 채팅방에 참가했습니다";
              debugPrint('Added role to message: $displayText');
      }
            
            // 4. 인원수 추가
            // 메타데이터의 인원수 사용
            if (currentCount != null && totalSlots != null) {
              displayText = "$displayText ($currentCount/$totalSlots)";
              debugPrint('Added count from metadata: $displayText');
            } 
            // This part is simplified as _tournament is not available directly.
            // The count from metadata should be prioritized.
          }
        }
      } catch (e) {
        debugPrint('Error processing system message: $e');
      }
      
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Text(
              displayText,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
          ),
          textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    
    // 메시지 발신자의 역할 정보 가져오기
    String? senderRole;
    // This logic needs to be adapted as _tournament is not a state variable anymore.
    // For simplicity, we'll omit the role and host status for now in this refactoring.
    // String? senderRole; // 중복 선언 제거
    bool isHost = false;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 발신자 프로필 이미지 (자신의 메시지는 표시 안함)
          if (!isCurrentUser)
            GestureDetector(
              onTap: () => context.push('/profile/${message.senderId}'),
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    child: CircleAvatar(
                radius: 16,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: message.senderProfileImageUrl != null
                    ? NetworkImage(message.senderProfileImageUrl!)
                    : null,
                      child: message.senderProfileImageUrl == null
                          ? const Icon(Icons.person, size: 16, color: Colors.grey)
                    : null,
                    ),
                  ),
                  if (isHost)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: const Icon(
                          Icons.star,
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
          const SizedBox(width: 8),
          
          // 메시지 내용 영역
            Column(
            crossAxisAlignment:
                isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // 발신자 이름 (자신의 메시지는 표시 안함)
              if (!isCurrentUser)
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 2.0),
                  child: Row(
              children: [
                Text(
                  message.senderName,
                        style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                  ),
                ),
                      if (senderRole != null)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: _getRoleColor(senderRole).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '(${_getRoleNameKorean(senderRole)})',
                            style: TextStyle(
                              fontSize: 10,
                              color: _getRoleColor(senderRole),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (isHost)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.star,
                            size: 12,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              
              // 메시지 말풍선 + 시간
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 시간 (자신의 메시지는 오른쪽에 표시)
                  if (isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(right: 4.0, bottom: 4.0),
                      child: Text(
                        timestamp,
                        style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
      ),

                  // 메시지 말풍선
                  Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 10.0,
                    ),
      decoration: BoxDecoration(
                      color: isCurrentUser
                          ? AppColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isCurrentUser
                            ? const Radius.circular(16)
                            : const Radius.circular(4),
                        bottomRight: isCurrentUser
                            ? const Radius.circular(4)
                            : const Radius.circular(16),
                      ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
          ),
        ],
      ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  
                  // 시간 (상대방 메시지는 왼쪽에 표시)
                  if (!isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                      child: Text(
                        timestamp,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                    ),
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

  // 역할에 따른 색상 반환
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'top':
        return Colors.red;
      case 'jungle':
        return Colors.green;
      case 'mid':
        return Colors.blue;
      case 'adc':
        return Colors.amber.shade800;
      case 'support':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // Discord 초대링크 받기 (토너먼트 문서에서 직접 읽어오기)
  Future<void> _getDiscordInviteLink(String tournamentId) async {
    if (_isLoadingDiscord) return;
    
    setState(() => _isLoadingDiscord = true);
    
    try {
      // 토너먼트 문서에서 Discord 채널 정보 직접 읽어오기
      final tournamentDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentId)
          .get();
      
      if (!tournamentDoc.exists) {
        throw Exception('토너먼트를 찾을 수 없습니다');
      }
      
      final tournamentData = tournamentDoc.data() as Map<String, dynamic>;
      final discordChannels = tournamentData['discordChannels'] as Map<String, dynamic>?;
      
      if (discordChannels == null || discordChannels.isEmpty) {
        throw Exception('Discord 채널이 아직 생성되지 않았습니다');
      }
      
      // 초대링크가 모두 있는지 확인
      final textChannelInvite = discordChannels['textChannelInvite'] as String?;
      final voiceChannel1Invite = discordChannels['voiceChannel1Invite'] as String?;
      final voiceChannel2Invite = discordChannels['voiceChannel2Invite'] as String?;
      
      if (textChannelInvite == null || voiceChannel1Invite == null || voiceChannel2Invite == null) {
        throw Exception('Discord 초대링크가 완전하지 않습니다');
      }
      
      // Discord 초대링크 팝업 표시
      if (mounted) {
        _showDiscordInviteDialog({
          'textChannelInvite': textChannelInvite,
          'voiceChannel1Invite': voiceChannel1Invite,
          'voiceChannel2Invite': voiceChannel2Invite,
        });
      }
      
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('오류'),
            content: Text('Discord 초대링크를 가져오는데 실패했습니다:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDiscord = false);
      }
    }
  }

  // Discord 초대링크 팝업 표시 (텍스트 채팅만)
  void _showDiscordInviteDialog(Map<String, dynamic> channelData) {
    final textChannelInvite = channelData['textChannelInvite'] as String?;
    
    if (textChannelInvite == null || textChannelInvite.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('오류'),
          content: const Text('Discord 초대링크를 찾을 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF5865F2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.chat,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Discord 초대링크',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🎯 토너먼트 Discord 채널이 생성되었습니다!\n\n💬 아래 링크를 터치해서 Discord 채팅방에 입장하세요:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            // 텍스트 채팅 링크 (클릭 가능)
            InkWell(
              onTap: () async {
                Navigator.of(context).pop();
                final uri = Uri.parse(textChannelInvite);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  // 링크를 열 수 없는 경우 클립보드에 복사
                  Clipboard.setData(ClipboardData(text: textChannelInvite));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('링크를 열 수 없어 클립보드에 복사했습니다')),
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF5865F2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF5865F2).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.chat,
                          color: const Color(0xFF5865F2),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '💬 텍스트 채팅방 입장하기',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5865F2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      textChannelInvite,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5865F2),
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          size: 14,
                          color: Colors.grey,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '터치해서 Discord 열기',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // Discord 초대링크 받기 버튼 표시 조건 확인
  bool _shouldShowDiscordButton(ChatRoomModel chatRoom) {
    if (chatRoom.type != ChatRoomType.tournamentRecruitment || _tournament == null) {
      return false;
    }
    
    // 10명 달성 + Discord 채널 생성됨
    final participantCount = _tournament!.participants?.length ?? 0;
    final hasDiscordChannels = _tournament!.discordChannels != null && 
                              _tournament!.discordChannels!['textChannelId'] != null;
    
    return participantCount >= 10 && hasDiscordChannels;
  }

  // Discord 초대링크 받기 버튼 UI
  Widget _buildDiscordButton(ChatRoomModel chatRoom) {
    if (!_shouldShowDiscordButton(chatRoom)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF5865F2).withOpacity(0.1),
          border: Border.all(color: const Color(0xFF5865F2).withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5865F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.discord,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎯 토너먼트 10명 달성!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5865F2),
                        ),
                      ),
                      Text(
                        'Discord 채널이 생성되었습니다',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoadingDiscord ? null : () => _getDiscordInviteLink(_tournament!.id),
                icon: _isLoadingDiscord 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
                label: Text(_isLoadingDiscord ? '초대링크 가져오는 중...' : 'Discord 초대링크 받기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5865F2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Discord 링크 버튼 위젯
  Widget _buildDiscordLinkButton(String label, String? inviteLink, {bool isPrimary = false}) {
    if (inviteLink == null || inviteLink.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(inviteLink);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          // 링크를 열 수 없는 경우 클립보드에 복사
          Clipboard.setData(ClipboardData(text: inviteLink));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Discord 링크가 복사되었습니다')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary 
              ? const Color(0xFF5865F2) 
              : const Color(0xFF5865F2).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF5865F2).withOpacity(isPrimary ? 1 : 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : const Color(0xFF5865F2),
                fontWeight: FontWeight.bold,
                fontSize: isPrimary ? 14 : 12,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new,
              size: isPrimary ? 16 : 14,
              color: isPrimary ? Colors.white : const Color(0xFF5865F2),
            ),
          ],
        ),
      ),
    );
  }
}