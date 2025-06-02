import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/screens/tournaments/match_list_tab.dart';
import 'package:lol_custom_game_manager/screens/tournaments/mercenary_search_tab.dart';
// Removed the import for clan_battles_tab.dart since it was deleted
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';

// Adding a temporary ClanBattlesTab widget until it's properly implemented
class ClanBattlesTab extends StatelessWidget {
  const ClanBattlesTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.group_work,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            '클랜전',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '준비 중입니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class TournamentMainScreen extends StatefulWidget {
  const TournamentMainScreen({Key? key}) : super(key: key);

  @override
  State<TournamentMainScreen> createState() => _TournamentMainScreenState();
}

class _TournamentMainScreenState extends State<TournamentMainScreen> with TickerProviderStateMixin {
  late TabController _mainTabController;
  final PageController _pageController = PageController(initialPage: 0, viewportFraction: 0.95);
  Timer? _autoSlideTimer;
  int _currentCarouselIndex = 0;
  int _selectedDateIndex = 0;
  final List<DateTime> _dates = [];
  DateTime? _selectedDate;
  
  // 더미 프로모션 카드 데이터
  final List<Map<String, dynamic>> _promotionCards = [
    {
      'title': 'e스포츠 대회 2024',
      'color': const Color(0xFFFF6B35),
      'textColor': Colors.white,
      'description': '국내 최대 e스포츠 대회에 참여하세요!'
    },
    {
      'title': '용병 모집중',
      'color': const Color(0xFF3566FF),
      'textColor': Colors.white,
      'description': '다양한 포지션의 용병을 모집합니다.'
    },
    {
      'title': '이벤트: 친구 초대',
      'color': const Color(0xFF35FF83),
      'textColor': Colors.black,
      'description': '친구를 초대하고 특별 보상을 받으세요!'
    },
  ];
  
  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 3, vsync: this);
    _setupDates();
    _startAutoSlide();
  }
  
  @override
  void dispose() {
    _mainTabController.dispose();
    _pageController.dispose();
    _autoSlideTimer?.cancel();
    super.dispose();
  }
  
  // 날짜 리스트 초기화 - 오늘부터 14일까지만 표시
  void _setupDates() {
    _dates.clear();
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 오늘부터 14일 후까지만 날짜 생성
    for (int i = 0; i <= 14; i++) {
      _dates.add(today.add(Duration(days: i)));
    }
    
    // 기본적으로 오늘 날짜 선택
    _selectedDateIndex = 0;
    _selectedDate = _dates[_selectedDateIndex];
  }
  
  // 자동 슬라이드 타이머 설정
  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (_promotionCards.isNotEmpty && _pageController.hasClients) {
        final nextIndex = (_currentCarouselIndex + 1) % _promotionCards.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }
  
  // 날짜 선택 시 호출되는 함수
  void _onDateSelected(int index) {
    setState(() {
      _selectedDateIndex = index;
      _selectedDate = _dates[_selectedDateIndex];
    });
    
    // 날짜 선택 정보 출력
    debugPrint('Selected date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}');
  }

  @override
  Widget build(BuildContext context) {
    // 매일 자정에 날짜 목록을 업데이트하기 위한 로직
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_dates.isNotEmpty && _dates[0].day != today.day) {
      // 날짜가 변경되었다면 날짜 목록 업데이트
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupDates();
      });
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '딜라',
          style: TextStyle(
            color: Color(0xFF1F1F1F),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF1F1F1F)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Color(0xFF1F1F1F)),
            onPressed: () {},
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // 메인 탭 바 (개인전/클랜전/용병 찾기)
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                      ),
                    ),
                    child: TabBar(
                      controller: _mainTabController,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.grey,
                      tabs: const [
                        Tab(text: '개인전'),
                        Tab(text: '클랜전'),
                        Tab(text: '용병 찾기'),
                      ],
                    ),
                  ),
                  
                  // 프로모션 카드 영역 (Carousel)
                  _buildPromotionCarousel(),
                  
                  // 날짜 선택기 (Date Selector)
                  _buildDateSelector(),
                ],
              ),
            ),
          ];
        },
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                controller: _mainTabController,
                children: [
                  // 개인전 탭
                  MatchListTab(selectedDate: _selectedDate),
                  
                  // 클랜전 탭
                  const ClanBattlesTab(),
                  
                  // 용병 찾기 탭
                  const MercenarySearchTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      // 내전 생성 버튼 추가
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 내전 생성 화면으로 이동 - 경로 수정
          context.push('/tournaments/create');
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  // 프로모션 카드 캐러셀
  Widget _buildPromotionCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _promotionCards.length,
            onPageChanged: (index) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final card = _promotionCards[index];
              return Container(
                width: MediaQuery.of(context).size.width,
                margin: const EdgeInsets.symmetric(horizontal: 5.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: card['color'],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      card['color'],
                      card['color'].withOpacity(0.8),
                    ],
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card['title'],
                        style: TextStyle(
                          color: card['textColor'],
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card['description'],
                        style: TextStyle(
                          color: card['textColor'],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        
        // Dot Indicator
        AnimatedSmoothIndicator(
          activeIndex: _currentCarouselIndex,
          count: _promotionCards.length,
          effect: const ExpandingDotsEffect(
            dotHeight: 8,
            dotWidth: 8,
            activeDotColor: AppColors.primary,
            dotColor: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
  
  // 날짜 선택기
  Widget _buildDateSelector() {
    return Container(
      height: 95,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
          bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _dates.length,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        itemBuilder: (context, index) {
          final date = _dates[index];
          final isToday = _isToday(date);
          final isSelected = index == _selectedDateIndex;
          
          // 요일 포맷 (월, 화, 수...)
          final weekdayFormat = DateFormat('E', 'ko_KR');
          final dayFormat = DateFormat('d');
          
          return GestureDetector(
            onTap: () {
              _onDateSelected(index);
            },
            child: Container(
              width: 65,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isToday && !isSelected 
                      ? AppColors.primary 
                      : isSelected 
                          ? AppColors.primary 
                          : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayFormat.format(date),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isSelected 
                            ? Colors.white 
                            : isToday 
                                ? AppColors.primary 
                                : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weekdayFormat.format(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected 
                            ? Colors.white 
                            : isToday 
                                ? AppColors.primary 
                                : Colors.grey,
                      ),
                    ),
                    if (isToday && !isSelected)
                      const SizedBox(height: 2),
                    if (isToday && !isSelected)
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  // 오늘 날짜인지 확인하는 유틸리티 함수
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }
}