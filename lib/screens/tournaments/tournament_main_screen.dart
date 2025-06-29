import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/tournament_provider.dart';
import 'package:lol_custom_game_manager/screens/tournaments/match_list_tab.dart';
import 'package:lol_custom_game_manager/screens/college_league/college_league_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/services/evaluation_service.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';

// Adding temporary widgets until they're properly implemented
class ClanBattlesTab extends StatelessWidget {
  const ClanBattlesTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('클랜전 준비 중'),
    );
  }
}

class CollegeLeagueView extends StatelessWidget {
  const CollegeLeagueView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(
                  Icons.school,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '대학 대항전',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '같은 대학끼리 팀을 이뤄 경쟁하세요',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF999999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// DuoFinderView 클래스를 제거했습니다 (별도 라우트로 처리)

class TournamentMainScreen extends StatefulWidget {
  const TournamentMainScreen({Key? key}) : super(key: key);

  @override
  State<TournamentMainScreen> createState() => _TournamentMainScreenState();
}

class _TournamentMainScreenState extends State<TournamentMainScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController(viewportFraction: 1.0);
  int _currentPageIndex = 0;
  final EvaluationService _evaluationService = EvaluationService();
  List<Map<String, dynamic>> _pendingEvaluations = [];
  TabController? _personalMatchTabController;

  // 메뉴 아이템 정의 - 토스 스타일
  final List<Map<String, dynamic>> _menuItems = [
    {
      'title': '개인전',
      'subtitle': '일반전 · 경쟁전',
      'icon': Icons.person,
      'color': AppColors.primary,
    },
    {
      'title': '클랜전',
      'subtitle': '팀 vs 팀 매치',
      'icon': Icons.groups,
      'color': const Color(0xFF5C7CFA),
    },
    {
      'title': '대학 대항전',
      'subtitle': '같은 대학끼리 팀을 이뤄 경쟁',
      'icon': Icons.school,
      'color': const Color(0xFFFF6B6B),
    },
    {
      'title': '듀오 찾기',
      'subtitle': '함께할 파트너 검색',
      'icon': Icons.people,
      'color': const Color(0xFF51CF66),
    },
  ];
  
  @override
  void initState() {
    super.initState();
    _personalMatchTabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TournamentProvider>(context, listen: false);
      provider.selectDate(DateTime.now());
      _loadPendingEvaluations();
    });
  }
  
  Future<void> _loadPendingEvaluations() async {
    final currentUser = Provider.of<AppStateProvider>(context, listen: false).currentUser;
    if (currentUser != null) {
      final evaluations = await _evaluationService.getPendingEvaluations(currentUser.uid);
      if (mounted) {
        setState(() {
          _pendingEvaluations = evaluations;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _personalMatchTabController?.dispose();
    super.dispose();
  }
  
  void _navigateToPage(int index) {
    if (index == 2) {
      // 클랜전 화면으로 push 방식으로 이동 (스택 유지)
      context.push('/clan-battle');
    } else if (index == 3) {
      // 대학 대항전 화면으로 push 방식으로 이동 (스택 유지)
      context.push('/college-league');
    } else if (index == 4) {
      // 듀오 찾기 화면으로 push 방식으로 이동 (스택 유지)
      context.push('/duo-finder');
    } else {
      setState(() {
        _currentPageIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _buildCurrentPage(),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
  
  Widget _buildCurrentPage() {
    switch (_currentPageIndex) {
      case 0:
        return _buildMainMenu();
      case 1:
        return _buildPersonalMatchPage();
      default:
        return _buildMainMenu();
    }
  }
  
  Widget _buildMainMenu() {
    return Column(
      children: [
        _buildHeader('스크림져드', subtitle: 'LOL 스크림 매칭 플랫폼'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_pendingEvaluations.isNotEmpty) _buildEvaluationBanner(),
                _buildPromotionCard(),
                const SizedBox(height: 24),
                const Text(
                  '어떤 매치를 찾으시나요?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
              ),
            ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _menuItems.length,
                  itemBuilder: (context, index) {
                    final item = _menuItems[index];
                    return _buildMenuItem(item, index + 1);
                  },
                ),
                const SizedBox(height: 24),
                _buildQuickActions(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalMatchPage() {
    return Column(
      children: [
        _buildHeader('개인전'),
        Expanded(
          child: Column(
            children: [
              _buildProfileBanner(),
              _buildDateSelector(),
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _personalMatchTabController,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelColor: const Color(0xFF1A1A1A),
                  unselectedLabelColor: const Color(0xFF999999),
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: '일반전'),
                    Tab(text: '리그전'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _personalMatchTabController,
                  children: const [
                    MatchListTab(
                      tournamentType: TournamentType.casual,
                      gameCategory: GameCategory.individual,
                    ),
                    MatchListTab(
                      tournamentType: TournamentType.competitive,
                      gameCategory: GameCategory.individual,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildProfileBanner() {
    return Consumer<AppStateProvider>(
      builder: (context, appStateProvider, child) {
        final currentUser = appStateProvider.currentUser;
        
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(0.7),
                AppColors.primary.withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: currentUser?.profileImageUrl != null && currentUser!.profileImageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          currentUser.profileImageUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              ),
                            );
                          },
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser?.nickname ?? '게스트',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '개인전에 참여하고 실력을 증명하세요',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  // 전적 보기 화면으로 이동 (추후 구현)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('전적 보기 기능은 곧 추가될 예정입니다'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '전적 보기',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildHeader(String title, {String? subtitle}) {
              return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF0F0F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentPageIndex > 0)
            GestureDetector(
              onTap: () => _navigateToPage(0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // 로고 이미지를 불러올 수 없을 때 기본 UI
                    return Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'S',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.search,
                size: 24,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.notifications_none,
                    size: 24,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              if (_pendingEvaluations.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMenuItem(Map<String, dynamic> item, int pageIndex) {
    return GestureDetector(
      onTap: () => _navigateToPage(pageIndex),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
                ),
                child: Padding(
          padding: const EdgeInsets.all(20),
                  child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    item['icon'],
                    color: item['color'],
                    size: 24,
                  ),
                ),
              ),
              Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                    item['title'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                    item['subtitle'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
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
  
  Widget _buildPromotionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '🔥 HOT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '이번 주 인기 토너먼트',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '총 상금 500만원 • 참가자 128명',
                        style: TextStyle(
              color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '자세히 보기',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '빠른 실행',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildQuickActionItem(
                icon: Icons.add_circle_outline,
                title: '매치 생성',
                subtitle: '새로운 스크림 매치 만들기',
                onTap: () => _showCreateTournamentModal(),
              ),
              const Divider(height: 24),
              _buildQuickActionItem(
                icon: Icons.history,
                title: '최근 매치',
                subtitle: '참가했던 매치 기록 보기',
                onTap: () {},
              ),
              const Divider(height: 24),
              _buildQuickActionItem(
                icon: Icons.star_outline,
                title: '즐겨찾기',
                subtitle: '자주 참가하는 매치',
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildQuickActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFF666666),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFFCCCCCC),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDateSelector() {
    final provider = Provider.of<TournamentProvider>(context);
    final selectedDate = provider.selectedDate;
    
    final dates = <DateTime>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (int i = 0; i <= 14; i++) {
      dates.add(today.add(Duration(days: i)));
    }
    
    int selectedIndex = dates.indexWhere((date) =>
        date.year == selectedDate.year &&
        date.month == selectedDate.month &&
        date.day == selectedDate.day);
    if (selectedIndex == -1) selectedIndex = 0;
    
    return Container(
      height: 100,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF0F0F0),
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isToday = _isToday(date);
          final isSelected = index == selectedIndex;
          final weekdayFormat = DateFormat('E', 'ko_KR');
          final dayFormat = DateFormat('d');
          
          return GestureDetector(
            onTap: () {
              provider.selectDate(date);
            },
            child: Container(
              width: 64,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected 
                      ? AppColors.primary 
                    : isToday 
                        ? AppColors.primary.withOpacity(0.1)
                        : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayFormat.format(date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected 
                          ? Colors.white.withOpacity(0.8)
                          : isToday 
                              ? AppColors.primary 
                              : const Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayFormat.format(date),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isSelected 
                          ? Colors.white 
                          : isToday 
                              ? AppColors.primary 
                              : const Color(0xFF1A1A1A),
                    ),
                  ),
                  if (isToday && !isSelected) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }
  
  Widget? _buildFloatingActionButton() {
    switch (_currentPageIndex) {
      case 1: // 개인전
        if (_personalMatchTabController != null) {
          return AnimatedBuilder(
            animation: _personalMatchTabController!,
            builder: (context, child) {
              // 일반전 탭(index 0)일 때만 + 버튼 표시
              if (_personalMatchTabController!.index == 0) {
                return FloatingActionButton(
                  onPressed: () => context.push('/tournaments/create?type=individual'),
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.add, color: Colors.white),
                );
              }
              return const SizedBox.shrink(); // 리그전 탭에서는 버튼 숨김
            },
          );
        }
        return null;

      default:
        return null;
    }
  }
  
  void _showCreateTournamentModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 핸들바
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 제목
            const Text(
              '새 내전 만들기',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '어떤 유형의 내전을 만들고 싶나요?',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF999999),
              ),
            ),
            const SizedBox(height: 24),
            
            // 개인전 옵션
            _buildTournamentOption(
              icon: Icons.person,
              title: '개인전',
              description: '개인 참가자들이 모여서 하는 내전',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                context.push('/tournaments/create?type=individual');
              },
            ),
            const SizedBox(height: 16),
            
            // 클랜전 옵션
            _buildTournamentOption(
              icon: Icons.groups,
              title: '클랜전',
              description: '클랜 vs 클랜으로 진행하는 대항전',
              color: const Color(0xFF7B93FF),
              onTap: () {
                Navigator.pop(context);
                context.push('/tournaments/create?type=clan');
              },
            ),
            const SizedBox(height: 16),
            
            // 대학리그전 옵션
            _buildTournamentOption(
              icon: Icons.school,
              title: '대학리그전',
              description: '대학 인증을 받은 유저들이 참여하는 리그',
              color: const Color(0xFF07C160),
              onTap: () {
                Navigator.pop(context);
                context.push('/tournaments/create?type=university');
              },
            ),
            
            const SizedBox(height: 24),
            
            // 취소 버튼
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '취소',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF999999),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentOption({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFF999999),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEvaluationBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (_pendingEvaluations.isNotEmpty) {
            final evaluation = _pendingEvaluations.first;
            context.push(
              '/evaluation/${evaluation['tournamentId']}?isHost=${evaluation['isHost']}',
            ).then((_) {
              _loadPendingEvaluations();
            });
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.rate_review,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '평가 대기중인 경기가 ${_pendingEvaluations.length}개 있어요',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '경기 평가를 완료하고 신뢰도를 높여보세요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}