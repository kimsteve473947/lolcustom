import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/providers/chat_provider.dart';
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

class _ChatRoomScreenState extends State<ChatRoomScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  ChatRoomModel? _chatRoom;
  TournamentModel? _tournament;
  bool _isLoading = true;
  String? _errorMessage;
  List<MessageModel> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller (간소화된 애니메이션 설정)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    // 애니메이션 즉시 완료
    _animationController.value = 1.0;
    
    _loadChatRoom();
    
    // ChatProvider를 통해 메시지 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.loadChatMessages(widget.chatRoomId);
      
      // 채팅방이 토너먼트 채팅방인 경우 멤버 정보 로드 및 토너먼트 정보 가져오기
      if (_chatRoom?.tournamentId != null) {
        chatProvider.loadChatRoomMembers(widget.chatRoomId);
        _loadTournamentInfo(_chatRoom!.tournamentId!);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // 토너먼트 정보 로드
  Future<void> _loadTournamentInfo(String tournamentId) async {
    try {
      final tournamentDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentId)
          .get();
      
      if (tournamentDoc.exists) {
        setState(() {
          _tournament = TournamentModel.fromFirestore(tournamentDoc);
        });
      }
    } catch (e) {
      debugPrint('Error loading tournament info: $e');
    }
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
      
      // 토너먼트 채팅방인 경우 토너먼트 정보도 로드
      if (chatRoom.tournamentId != null) {
        _loadTournamentInfo(chatRoom.tournamentId!);
      }
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
      // ChatProvider를 통해 메시지 전송
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final success = await chatProvider.sendMessage(
        widget.chatRoomId,
        message,
        currentUser,
      );
      
      if (success) {
        // Clear input
        _messageController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chatProvider.error ?? '메시지 전송 실패'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      
      setState(() {
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

  // 채팅방 나가기 확인 및 처리
  Future<void> _leaveChatRoom() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentUser = appState.currentUser;
    
    if (currentUser == null || _chatRoom == null) return;
    
    // 토너먼트 채팅방인 경우에만 신청 취소 다이얼로그 표시
    if (_chatRoom!.tournamentId != null) {
      final success = await chatProvider.leaveTournamentChatRoom(
        widget.chatRoomId,
        currentUser,
        context,
      );
      
      if (success) {
        // 채팅 목록 화면으로 이동
        if (mounted) {
          _navigateBack();
        }
      }
    } else {
      // 일반 채팅방은 단순 확인 후 나가기
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('채팅방 나가기'),
          content: const Text('채팅방을 나가시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('확인'),
            ),
          ],
        ),
      ) ?? false;
      
      if (confirmed) {
        _navigateBack();
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
  void _showMembersModal() {
    if (_chatRoom == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getTournamentMembersWithRoles(),
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
                          _tournament != null 
                              ? '${members.length}/${_tournament!.totalSlots}' 
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
                                  final isHost = _tournament != null && 
                                               _tournament!.hostId == member['userId'];
                                  
                                  return ListTile(
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
                                              child: const Icon(
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
  Future<List<Map<String, dynamic>>> _getTournamentMembersWithRoles() async {
    if (_chatRoom == null) return [];
    
    try {
      List<Map<String, dynamic>> result = [];
      
      // 토너먼트 채팅방인 경우 토너먼트 참가자 정보 가져오기
      if (_chatRoom!.tournamentId != null && _tournament != null) {
        // 토너먼트의 참가자 ID 목록과 역할 정보 가져오기
        final participants = _tournament!.participants;
        final participantsByRole = _tournament!.participantsByRole;
        
        // 각 참가자의 정보 가져오기
        for (String userId in participants) {
          // 사용자 정보 가져오기
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          
          if (userDoc.exists) {
            // 사용자의 역할 찾기
            String? role;
            for (var entry in participantsByRole.entries) {
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
              'createdAt': Timestamp.now(),
            });
          }
        }
      } else {
        // 일반 채팅방인 경우 채팅방 참가자 정보 가져오기
        for (String userId in _chatRoom!.participantIds) {
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
    if (_tournament != null && _chatRoom?.type == ChatRoomType.tournamentRecruitment) {
      // 토너먼트의 총 참가자 수와 총 슬롯 수 표시 (호스트 포함)
      return '${_tournament!.participants.length}/${_tournament!.totalSlots}명';
    } else if (_chatRoom != null) {
      // 일반 채팅방인 경우 참가자 수만 표시
      return '${_chatRoom!.participantIds.length}명';
    }
    
    return '0/10명';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _navigateBack();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: _navigateBack,
          ),
          title: _chatRoom != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _chatRoom!.title,
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_chatRoom!.tournamentId != null)
                      Text(
                        '참가자: ${_getParticipantCountDisplay()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                )
              : const Text('채팅방'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            // 멤버 보기 버튼
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: _showMembersModal,
              tooltip: '멤버 보기',
            ),
            // 토너먼트 정보 버튼 (토너먼트 채팅방인 경우)
            if (_chatRoom?.tournamentId != null)
              IconButton(
                icon: const Icon(Icons.sports_esports),
                onPressed: () => _viewTournament(_chatRoom!.tournamentId!),
                tooltip: '토너먼트 보기',
              ),
            // 채팅방 나가기 버튼
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _leaveChatRoom,
              tooltip: '채팅방 나가기',
            ),
          ],
        ),
        body: _isLoading
            ? const LoadingIndicator()
            : _errorMessage != null
                ? ErrorView(
                    errorMessage: _errorMessage!,
                    onRetry: _loadChatRoom,
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.grey.shade50,
                          Colors.grey.shade100,
                        ],
                      ),
                    ),
                    child: Column(
                    children: [
                        // 메시지 목록
                        Expanded(
                          child: Consumer<ChatProvider>(
                            builder: (context, chatProvider, child) {
                              final messages = chatProvider.messages[widget.chatRoomId] ?? _messages;
                              
                              return ListView.builder(
                                controller: _scrollController,
                                reverse: true,
                                padding: const EdgeInsets.all(12),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final isCurrentUser = message.senderId ==
                                      Provider.of<AppStateProvider>(context, listen: false)
                                          .currentUser
                                          ?.uid;
                                  final isSystemMessage = message.senderId == 'system';
                                  
                                  return _buildMessageItem(
                                    message,
                                    isCurrentUser,
                                    isSystemMessage,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        
                        // 메시지 입력 영역
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                offset: const Offset(0, -1),
                                blurRadius: 3,
                                color: Colors.black.withOpacity(0.1),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            child: Row(
                              children: [
                                // 메시지 입력 필드
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: TextField(
                                      controller: _messageController,
                                      decoration: InputDecoration(
                                        hintText: '메시지 입력...',
                                        hintStyle: TextStyle(color: Colors.grey.shade500),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                      ),
                                      minLines: 1,
                                      maxLines: 5,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => _sendMessage(),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(width: 8),
                                
                                // 전송 버튼
                                Material(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(24),
                                  child: InkWell(
                                    onTap: _isSending ? null : _sendMessage,
                                    borderRadius: BorderRadius.circular(24),
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                      ),
                                      child: _isSending
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.send,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                ),
                    ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
            // 토너먼트 정보에서 인원수 가져오기
            else if (_tournament != null) {
              final tCurrentCount = _tournament!.participants.length;
              final tTotalSlots = _tournament!.totalSlots;
              displayText = "$displayText ($tCurrentCount/$tTotalSlots)";
              debugPrint('Added count from tournament: $displayText');
            }
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
    if (_tournament != null) {
      for (var entry in _tournament!.participantsByRole.entries) {
        if (entry.value.contains(message.senderId)) {
          senderRole = entry.key;
          break;
        }
      }
    }
    
    // 호스트 여부 확인
    final isHost = _tournament != null && message.senderId == _tournament!.hostId;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 발신자 프로필 이미지 (자신의 메시지는 표시 안함)
          if (!isCurrentUser)
            Stack(
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
} 