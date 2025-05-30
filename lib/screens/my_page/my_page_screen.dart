import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/widgets/rating_item.dart';
import 'package:lol_custom_game_manager/widgets/tournament_card.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({Key? key}) : super(key: key);

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = false;
  String? _errorMessage;
  List<TournamentModel> _myTournaments = [];
  List<TournamentModel> _joinedTournaments = [];
  List<RatingModel> _myRatings = [];
  
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _loadData();
      }
    });
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (appState.currentUser == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // This is a placeholder until we implement the actual data loading
      await Future.delayed(const Duration(milliseconds: 800));
      
      switch (_tabController.index) {
        case 0:
          // Load my tournaments
          setState(() {
            _myTournaments = _getMockTournaments(appState.currentUser!.uid, 5);
            _isLoading = false;
          });
          break;
        case 1:
          // Load joined tournaments
          setState(() {
            _joinedTournaments = _getMockTournaments("other_host_id", 8);
            _isLoading = false;
          });
          break;
        case 2:
          // Load my ratings
          setState(() {
            _myRatings = _getMockRatings(appState.currentUser!.uid, 10);
            _isLoading = false;
          });
          break;
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }
  
  // TODO: Replace with actual API calls
  List<TournamentModel> _getMockTournaments(String hostId, int count) {
    final List<TournamentModel> mockTournaments = [];
    for (int i = 1; i <= count; i++) {
      mockTournaments.add(
        TournamentModel(
          id: 'tournament$i',
          hostUid: hostId,
          hostNickname: '주최자$i',
          startsAt: Timestamp.fromDate(DateTime.now().add(Duration(days: i))),
          location: '민락축구장 $i번 구장',
          isPaid: i % 3 == 0,
          price: i % 3 == 0 ? 10000 : null,
          slotsByRole: {
            'top': 2,
            'jungle': 2,
            'mid': 2,
            'adc': 2,
            'support': 2,
          },
          filledSlotsByRole: {
            'top': i % 3,
            'jungle': (i + 1) % 3,
            'mid': (i + 2) % 3,
            'adc': i % 2,
            'support': (i + 1) % 2,
          },
          status: i % 4 == 0 ? TournamentStatus.completed : 
                 i % 4 == 1 ? TournamentStatus.inProgress : 
                 i % 4 == 2 ? TournamentStatus.full : 
                 TournamentStatus.open,
          createdAt: Timestamp.now(),
        ),
      );
    }
    return mockTournaments;
  }
  
  List<RatingModel> _getMockRatings(String targetUid, int count) {
    final List<RatingModel> mockRatings = [];
    for (int i = 1; i <= count; i++) {
      mockRatings.add(
        RatingModel(
          id: 'rating$i',
          tournamentId: 'tournament$i',
          targetUid: targetUid,
          raterUid: 'rater$i',
          raterName: '평가자$i',
          stars: 3 + (i % 3),
          comment: i % 2 == 0 ? '좋은 플레이어입니다! 추천합니다.' : null,
          createdAt: Timestamp.fromDate(DateTime.now().subtract(Duration(days: i * 2))),
        ),
      );
    }
    return mockRatings;
  }
  
  void _signOut() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await appState.signOut();
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final currentUser = appState.currentUser;
    
    if (currentUser == null) {
      return const Center(child: Text('로그인이 필요합니다'));
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '마이페이지',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProfileHeader(currentUser),
          const SizedBox(height: 8),
          _buildStatusCards(currentUser),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: '내가 주최한 내전'),
              Tab(text: '참여한 내전'),
              Tab(text: '받은 평가'),
            ],
          ),
          Expanded(
            child: _errorMessage != null
                ? ErrorView(
                    message: _errorMessage!,
                    onRetry: _loadData,
                  )
                : _isLoading
                    ? const LoadingIndicator()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMyTournaments(),
                          _buildJoinedTournaments(),
                          _buildMyRatings(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfileHeader(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: user.profileImageUrl != null
                ? NetworkImage(user.profileImageUrl!)
                : null,
            child: user.profileImageUrl == null
                ? const Icon(Icons.person, size: 40)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.nickname,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (user.tier != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user.tier!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    if (user.isPremium)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.workspace_premium,
                              size: 12,
                              color: Colors.amber,
                            ),
                            SizedBox(width: 2),
                            Text(
                              'PREMIUM',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.riotId ?? '라이엇 계정 연동 필요',
                  style: TextStyle(
                    fontSize: 14,
                    color: user.riotId != null
                        ? AppColors.textSecondary
                        : AppColors.error,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (user.averageRating != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user.averageRating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                    ],
                    Row(
                      children: [
                        const Icon(
                          Icons.date_range,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '가입: ${DateFormat('yyyy.MM.dd').format(user.joinedAt.toDate())}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusCards(UserModel user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatusCard(
              title: '보유 크레딧',
              value: '${NumberFormat('#,###').format(user.credits)}',
              icon: Icons.monetization_on_outlined,
              color: Colors.green,
              onTap: () {
                // TODO: Navigate to credits screen
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatusCard(
              title: '프리미엄',
              value: user.isPremium ? '구독 중' : '미구독',
              icon: Icons.workspace_premium,
              color: Colors.amber,
              onTap: () {
                // TODO: Navigate to premium subscription screen
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMyTournaments() {
    if (_myTournaments.isEmpty) {
      return _buildEmptyState('주최한 내전이 없습니다', '내전을 만들어보세요!');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myTournaments.length,
      itemBuilder: (context, index) {
        final tournament = _myTournaments[index];
        return _buildTournamentItem(tournament);
      },
    );
  }
  
  Widget _buildJoinedTournaments() {
    if (_joinedTournaments.isEmpty) {
      return _buildEmptyState('참여한 내전이 없습니다', '내전에 참여해보세요!');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _joinedTournaments.length,
      itemBuilder: (context, index) {
        final tournament = _joinedTournaments[index];
        return _buildTournamentItem(tournament);
      },
    );
  }
  
  Widget _buildMyRatings() {
    if (_myRatings.isEmpty) {
      return _buildEmptyState('받은 평가가 없습니다', '내전에 참여하고 평가를 받아보세요!');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myRatings.length,
      itemBuilder: (context, index) {
        final rating = _myRatings[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rating.raterName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('yyyy.MM.dd').format(rating.createdAt.toDate()),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < rating.stars ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    ),
                  ),
                ),
                if (rating.comment != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    rating.comment!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildTournamentItem(TournamentModel tournament) {
    String statusText;
    Color statusColor;
    
    switch (tournament.status) {
      case TournamentStatus.open:
        statusText = '모집 중';
        statusColor = AppColors.success;
        break;
      case TournamentStatus.full:
        statusText = '모집 완료';
        statusColor = AppColors.primary;
        break;
      case TournamentStatus.inProgress:
        statusText = '진행 중';
        statusColor = AppColors.warning;
        break;
      case TournamentStatus.completed:
        statusText = '완료됨';
        statusColor = AppColors.textSecondary;
        break;
      case TournamentStatus.cancelled:
        statusText = '취소됨';
        statusColor = AppColors.error;
        break;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          context.push('/tournaments/${tournament.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    DateFormat('M월 d일 (E) HH:mm', 'ko_KR').format(tournament.startsAt.toDate()),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tournament.location,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (tournament.isPaid) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${NumberFormat('#,###').format(tournament.price ?? 0)}원',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '${tournament.totalFilledSlots}/${tournament.totalSlots}명 참가',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.sports_soccer_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
} 