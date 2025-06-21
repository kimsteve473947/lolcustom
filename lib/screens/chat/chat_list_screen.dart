import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/chat_service.dart';
import 'package:lol_custom_game_manager/services/tournament_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/utils/date_utils.dart';
import 'dart:ui';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  final TournamentService _tournamentService = TournamentService();
  final Map<String, TournamentModel?> _tournamentCache = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }
  
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    }
  }

  // 토너먼트 정보를 가져오는 함수
  Future<TournamentModel?> _getTournamentInfo(String tournamentId) async {
    if (_tournamentCache.containsKey(tournamentId)) {
      return _tournamentCache[tournamentId];
    }
    
    try {
      final tournament = await _tournamentService.getTournament(tournamentId);
      _tournamentCache[tournamentId] = tournament;
      return tournament;
    } catch (e) {
      print('Error fetching tournament $tournamentId: $e');
      _tournamentCache[tournamentId] = null;
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final allChatRooms = context.watch<List<ChatRoomModel>?>();

    if (appState.currentUser == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }
    
    if (allChatRooms == null) {
      return const Scaffold(body: LoadingIndicator());
    }

    final tournamentChatRooms = allChatRooms
        .where((room) => room.type == ChatRoomType.tournamentRecruitment)
        .toList();
    final personalChatRooms = allChatRooms
        .where((room) => room.type != ChatRoomType.tournamentRecruitment)
        .toList();

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatListView(context, tournamentChatRooms),
                _buildChatListView(context, personalChatRooms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top section with title and actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '채팅',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          // 검색 기능
                        },
                        icon: const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () {
                          // 메뉴
                        },
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Custom Tab Bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _tabController.animateTo(0);
                      },
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            '토너먼트',
                            style: TextStyle(
                              color: _selectedTabIndex == 0 ? AppColors.primary : Colors.white,
                              fontWeight: _selectedTabIndex == 0 ? FontWeight.bold : FontWeight.normal,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _tabController.animateTo(1);
                      },
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            '개인 메시지',
                            style: TextStyle(
                              color: _selectedTabIndex == 1 ? AppColors.primary : Colors.white,
                              fontWeight: _selectedTabIndex == 1 ? FontWeight.bold : FontWeight.normal,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom divider
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatListView(BuildContext context, List<ChatRoomModel> chatRooms) {
    if (chatRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedTabIndex == 0 ? Icons.groups_outlined : Icons.chat_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '참여 중인 채팅방이 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12),
      itemCount: chatRooms.length,
      itemBuilder: (context, index) {
        final chatRoom = chatRooms[index];
        return _buildChatRoomItem(context, chatRoom);
      },
    );
  }

  Widget _buildChatRoomItem(BuildContext context, ChatRoomModel chatRoom) {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    String displayName = chatRoom.title;
    String? displayImage;

    // 토너먼트 채팅방인 경우 제목에서 참가자 수 제거
    if (chatRoom.type == ChatRoomType.tournamentRecruitment) {
      // 제목에서 "(9/10)" 같은 패턴 제거
      displayName = chatRoom.title.replaceAll(RegExp(r'\s*\(\d+/\d+\)\s*$'), '');
    } else if (chatRoom.type == ChatRoomType.direct && appState.currentUser != null) {
      final otherUserId = chatRoom.participantIds.firstWhere((id) => id != appState.currentUser!.uid, orElse: () => '');
      if (otherUserId.isNotEmpty) {
        displayName = chatRoom.participantNames[otherUserId] ?? '알 수 없음';
        displayImage = chatRoom.participantProfileImages[otherUserId];
      }
    }

    final unreadCount = appState.currentUser != null ? chatRoom.unreadCount[appState.currentUser!.uid] ?? 0 : 0;
    final hasUnread = unreadCount > 0;

    String lastMessageTime = '';
    if (chatRoom.lastMessageTime != null) {
      lastMessageTime = formatRelativeTime(chatRoom.lastMessageTime!.toDate());
    }

    // Calculate participants string
    String participantsText = '${chatRoom.participantCount}명 참여중';
    if (chatRoom.type == ChatRoomType.direct) {
      participantsText = '1:1 대화';
    } else if (chatRoom.type == ChatRoomType.tournamentRecruitment) {
      participantsText = '${chatRoom.participantCount}/10명';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => context.push('/chat/${chatRoom.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: hasUnread 
                ? AppColors.primary.withOpacity(0.04) 
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Profile image with status indicator
                Stack(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: AppColors.primary.withOpacity(0.1),
                        image: displayImage != null && displayImage.isNotEmpty && displayImage.startsWith('http')
                            ? DecorationImage(
                                image: NetworkImage(displayImage),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: displayImage == null || displayImage.isEmpty || !displayImage.startsWith('http')
                          ? Icon(
                              chatRoom.type == ChatRoomType.tournamentRecruitment 
                                  ? Icons.groups_outlined 
                                  : Icons.person_outline,
                              color: AppColors.primary,
                              size: 28,
                            )
                          : null,
                    ),
                    if (hasUnread)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.5),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 9 ? '9+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 16,
                                      color: hasUnread ? AppColors.primary : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasUnread)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            lastMessageTime,
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnread ? AppColors.primary : Colors.grey.shade500,
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chatRoom.lastMessageText ?? '새로운 채팅방',
                        style: TextStyle(
                          color: hasUnread ? AppColors.primary : Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // 토너먼트 채팅방인 경우 주최자 정보 표시
                      if (chatRoom.type == ChatRoomType.tournamentRecruitment)
                        _buildTournamentChatRoomInfo(chatRoom, participantsText)
                      else
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _getChatRoomTypeColor(chatRoom.type).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getChatRoomTypeText(chatRoom.type),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getChatRoomTypeColor(chatRoom.type),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              participantsText,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 토너먼트 채팅방 정보를 표시하는 위젯
  Widget _buildTournamentChatRoomInfo(ChatRoomModel chatRoom, String participantsText) {
    return FutureBuilder<TournamentModel?>(
      future: _getTournamentInfo(chatRoom.tournamentId ?? ''),
      builder: (context, snapshot) {
        String hostName = '알 수 없음';
        
        if (snapshot.hasData && snapshot.data != null) {
          final tournament = snapshot.data!;
          hostName = tournament.hostNickname ?? tournament.hostName;
        }

        return Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: _getChatRoomTypeColor(chatRoom.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getChatRoomTypeText(chatRoom.type),
                style: TextStyle(
                  fontSize: 10,
                  color: _getChatRoomTypeColor(chatRoom.type),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              participantsText,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primary.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
              child: Text(
                '주최자: $hostName',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Color _getChatRoomTypeColor(ChatRoomType type) {
    switch (type) {
      case ChatRoomType.tournamentRecruitment:
        return Colors.indigo;
      case ChatRoomType.mercenaryOffer:
        return Colors.teal;
      case ChatRoomType.direct:
        return Colors.deepPurple;
      default:
        return AppColors.primary;
    }
  }
  
  String _getChatRoomTypeText(ChatRoomType type) {
    switch (type) {
      case ChatRoomType.tournamentRecruitment:
        return '토너먼트';
      case ChatRoomType.mercenaryOffer:
        return '용병 모집';
      case ChatRoomType.direct:
        return '1:1 대화';
      default:
        return '채팅방';
    }
  }
}
