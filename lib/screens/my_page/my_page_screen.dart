import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/friendship_model.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart' as CustomAuth;
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/friendship_service.dart';
import 'package:lol_custom_game_manager/services/user_service.dart';
import 'package:lol_custom_game_manager/widgets/calendar/user_calendar_widget.dart';
import 'package:lol_custom_game_manager/screens/my_page/tournaments_by_date_screen.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/screens/mercenaries/mercenary_edit_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({Key? key}) : super(key: key);

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> with SingleTickerProviderStateMixin {
  final FriendshipService _friendshipService = FriendshipService();
  final UserService _userService = UserService();
  late TabController _tabController;
  int _selectedTabIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _syncUserData();
    _tabController = TabController(length: 3, vsync: this);
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

  Future<void> _syncUserData() async {
    final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
    try {
      await appStateProvider.syncCurrentUser();
    } catch (e) {
      debugPrint('MyPageScreen - 사용자 데이터 동기화 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<CustomAuth.AuthProvider>(context);
    final appStateProvider = Provider.of<AppStateProvider>(context);
    final user = appStateProvider.currentUser;

    if (!authProvider.isLoggedIn || user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('로그인이 필요합니다'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('로그인하기'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _syncUserData,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                backgroundColor: AppColors.primary,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildProfileHeader(user),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                    onPressed: () {
                      // TODO: 설정 화면으로 이동
                    },
                  ),
                ],
              ),
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppColors.primary,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.people_alt_outlined),
                        text: '친구',
                      ),
                      Tab(
                        icon: Icon(Icons.calendar_today),
                        text: '일정',
                      ),
                      Tab(
                        icon: Icon(Icons.person),
                        text: '활동',
                      ),
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildFriendsTab(user),
              _buildCalendarTab(),
              _buildActivityTab(appStateProvider, authProvider),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProfileHeader(UserModel user) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  backgroundImage: user.profileImageUrl.isNotEmpty ? NetworkImage(user.profileImageUrl) : null,
                  child: user.profileImageUrl.isEmpty ? const Icon(Icons.person, size: 40, color: AppColors.primary) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nickname, 
                        style: const TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        UserModel.tierToString(user.tier), 
                        style: const TextStyle(
                          fontSize: 15, 
                          color: Colors.white70
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email, 
                        style: const TextStyle(
                          fontSize: 14, 
                          color: Colors.white70
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 36,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.push('/my-page/edit-profile');
                },
                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                label: const Text('프로필 수정', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab(UserModel user) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFriendRequestList(user.uid),
        const SizedBox(height: 16),
        _buildFriendList(user.uid),
      ],
    );
  }

  Widget _buildCalendarTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('내 내전 일정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 16),
                UserCalendarWidget(
                  onDateSelected: (selectedDate) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => TournamentsByDateScreen(selectedDate: selectedDate),
                    ));
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTab(AppStateProvider appStateProvider, CustomAuth.AuthProvider authProvider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                  child: Text('내 활동', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
                  title: const Text('용병 등록 / 수정'),
                  onTap: () => context.push('/mercenary-edit'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                  child: Text('개발자 도구', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: AppColors.primary),
                  title: const Text('관리자 도구'),
                  onTap: () => context.push('/admin'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('로그아웃'),
                  content: const Text('정말 로그아웃 하시겠습니까?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
                    TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('로그아웃')),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await authProvider.signOut();
                context.go('/login');
              }
            },
            icon: const Icon(Icons.exit_to_app),
            label: const Text('로그아웃'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade100,
              foregroundColor: Colors.red.shade700,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendRequestList(String userId) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('받은 친구 요청', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const Spacer(),
                StreamBuilder<List<Friendship>>(
                  stream: _friendshipService.getReceivedFriendRequests(userId),
                  builder: (context, snapshot) {
                    final count = snapshot.hasData ? snapshot.data!.length : 0;
                    if (count > 0) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Friendship>>(
              stream: _friendshipService.getReceivedFriendRequests(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('받은 친구 요청이 없습니다.'),
                    ),
                  );
                }
                final requests = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return FutureBuilder<UserModel?>(
                      future: _userService.getUser(request.requesterId),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) return const SizedBox.shrink();
                        final requester = userSnapshot.data!;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: requester.profileImageUrl.isNotEmpty ? NetworkImage(requester.profileImageUrl) : null,
                            child: requester.profileImageUrl.isEmpty ? const Icon(Icons.person) : null,
                          ),
                          title: Text('${requester.nickname} 님의 친구 요청'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                child: const Text('수락'),
                                onPressed: () => _friendshipService.acceptFriendRequest(request.id),
                              ),
                              TextButton(
                                child: const Text('거절', style: TextStyle(color: Colors.red)),
                                onPressed: () => _friendshipService.rejectOrRemoveFriend(request.id),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendList(String userId) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('친구 목록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const Spacer(),
                StreamBuilder<List<UserModel>>(
                  stream: _friendshipService.getFriends(userId),
                  builder: (context, snapshot) {
                    final count = snapshot.hasData ? snapshot.data!.length : 0;
                    return Text(
                      '$count명',
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<UserModel>>(
              stream: _friendshipService.getFriends(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('친구가 없습니다.'),
                    ),
                  );
                }
                final friends = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: friend.profileImageUrl.isNotEmpty ? NetworkImage(friend.profileImageUrl) : null,
                        child: friend.profileImageUrl.isEmpty ? const Icon(Icons.person) : null,
                      ),
                      title: Text(friend.nickname),
                      subtitle: Text(UserModel.tierToString(friend.tier), style: TextStyle(color: Colors.grey.shade600)),
                      onTap: () => context.push('/profile/${friend.uid}'),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}