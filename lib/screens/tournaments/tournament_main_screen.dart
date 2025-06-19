import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/tournament_provider.dart';
import 'package:lol_custom_game_manager/screens/tournaments/match_list_tab.dart';
import 'package:lol_custom_game_manager/screens/tournaments/mercenary_search_tab.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/services/evaluation_service.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';

// Adding a temporary ClanBattlesTab widget until it's properly implemented
class ClanBattlesTab extends StatelessWidget {
  const ClanBattlesTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('클랜전 준비 중'),
    );
  }
}

class TournamentMainScreen extends StatefulWidget {
  const TournamentMainScreen({Key? key}) : super(key: key);

  @override
  State<TournamentMainScreen> createState() => _TournamentMainScreenState();
}

class _TournamentMainScreenState extends State<TournamentMainScreen> {
  final PageController _pageController = PageController(viewportFraction: 1.0);
  int _currentPageIndex = 0;
  final EvaluationService _evaluationService = EvaluationService();
  List<Map<String, dynamic>> _pendingEvaluations = [];
  
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
      'title': '용병 찾기',
      'subtitle': '실력있는 플레이어 매칭',
      'icon': Icons.shield,
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
    super.dispose();
  }

  void _navigateToPage(int index) {
    setState(() {
      _currentPageIndex = index;
    });
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
      case 2:
        return _buildClanBattlePage();
      case 3:
        return _buildMercenaryFinderPage();
      case 4:
        return _buildDuoFinderPage();
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
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                _buildDateSelector(),
                Container(
                  color: Colors.white,
                  child: TabBar(
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
                      Tab(text: '경쟁전'),
                    ],
                  ),
                ),
                const Expanded(
                  child: TabBarView(
                    children: [
                      MatchListTab(tournamentType: TournamentType.casual),
                      MatchListTab(tournamentType: TournamentType.competitive),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildClanBattlePage() {
    return Column(
      children: [
        _buildHeader('클랜전'),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.groups,
                      size: 40,
                      color: Color(0xFFCCCCCC),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '클랜전 준비 중',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '곧 만나볼 수 있어요!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildMercenaryFinderPage() {
    return Column(
      children: [
        _buildHeader('용병 찾기'),
        const Expanded(
          child: MercenaryFinderView(),
        ),
      ],
    );
  }
  
  Widget _buildDuoFinderPage() {
    return Column(
      children: [
        _buildHeader('듀오 찾기'),
        const Expanded(
          child: DuoFinderView(),
        ),
      ],
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
                onTap: () => context.push('/tournaments/create'),
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
      case 2: // 클랜전
        return FloatingActionButton(
          onPressed: () async {
            final result = await context.push('/tournaments/create');
            if (result is TournamentModel) {
              final provider = Provider.of<TournamentProvider>(context, listen: false);
              await Future.delayed(const Duration(milliseconds: 500));
              await provider.selectDate(result.startsAt.toDate());
            }
          },
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        );
      case 3: // 용병 찾기
        return FloatingActionButton.extended(
          onPressed: () => context.push('/mercenaries/register'),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            '용병 등록',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case 4: // 듀오 찾기
        return null; // DuoFinderView에 자체 FAB가 있음
      default:
        return null;
    }
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