import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';

class MatchHomeScreen extends StatefulWidget {
  const MatchHomeScreen({Key? key}) : super(key: key);

  @override
  State<MatchHomeScreen> createState() => _MatchHomeScreenState();
}

class _MatchHomeScreenState extends State<MatchHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CarouselController _carouselController = CarouselController();
  Timer? _autoSlideTimer;
  int _currentCarouselIndex = 0;
  int _selectedDateIndex = 0;
  final List<DateTime> _dates = [];
  
  // 더미 프로모션 카드 데이터
  final List<Map<String, dynamic>> _promotionCards = [
    {
      'title': 'e스포츠 대회 2024',
      'imageUrl': 'https://via.placeholder.com/800x400/FF6B35/FFFFFF?text=e스포츠+대회+2024',
      'description': '국내 최대 e스포츠 대회에 참여하세요!'
    },
    {
      'title': '용병 모집중',
      'imageUrl': 'https://via.placeholder.com/800x400/3566FF/FFFFFF?text=용병+모집중',
      'description': '다양한 포지션의 용병을 모집합니다.'
    },
    {
      'title': '이벤트: 친구 초대',
      'imageUrl': 'https://via.placeholder.com/800x400/35FF83/000000?text=친구+초대+이벤트',
      'description': '친구를 초대하고 특별 보상을 받으세요!'
    },
  ];
  
  // 더미 매치 데이터
  final List<Map<String, dynamic>> _dummyMatches = [
    {
      'id': '1',
      'title': '민락동의 내전',
      'type': '단판',
      'status': '모집중',
      'datetime': DateTime.now().add(const Duration(hours: 2)),
    },
    {
      'id': '2',
      'title': '플래티넘 내전',
      'type': '3판 2선승',
      'status': '모집중',
      'datetime': DateTime.now().add(const Duration(hours: 5)),
    },
  ];
  
  List<Map<String, dynamic>> _filteredMatches = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupDates();
    _startAutoSlide();
    _filterMatchesByDate(_dates[_selectedDateIndex]);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _autoSlideTimer?.cancel();
    super.dispose();
  }
  
  // 날짜 리스트 초기화
  void _setupDates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 오늘 포함 2주치 날짜 생성 (오늘 기준 1주일 전부터 1주일 후까지)
    for (int i = -7; i <= 14; i++) {
      _dates.add(today.add(Duration(days: i)));
    }
  }
  
  // 자동 슬라이드 타이머 설정
  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_promotionCards.isNotEmpty) {
        final nextIndex = (_currentCarouselIndex + 1) % _promotionCards.length;
        _carouselController.animateToPage(nextIndex);
        setState(() {
          _currentCarouselIndex = nextIndex;
        });
      }
    });
  }
  
  // 날짜별 매치 필터링
  void _filterMatchesByDate(DateTime date) {
    // 실제로는 API 호출 또는 Firebase에서 데이터를 가져오게 됨
    // 여기서는 더미 데이터로 단순 필터링
    final selectedDate = DateTime(date.year, date.month, date.day);
    
    setState(() {
      _filteredMatches = _dummyMatches.where((match) {
        final matchDate = DateTime(
          match['datetime'].year,
          match['datetime'].month,
          match['datetime'].day,
        );
        return matchDate.isAtSameMomentAs(selectedDate);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          // Tab Bar
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: '개인 매칭'),
                Tab(text: '클랜 매칭'),
                Tab(text: '용병 찾기'),
              ],
            ),
          ),
          
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 개인 매칭 탭
                _buildPersonalMatchingTab(),
                
                // 클랜 매칭 탭 (임시 빈 화면)
                const Center(child: Text('클랜 매칭 준비 중')),
                
                // 용병 찾기 탭 (임시 빈 화면)
                const Center(child: Text('용병 찾기 준비 중')),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 개인 매칭 탭 내용
  Widget _buildPersonalMatchingTab() {
    return ListView(
      children: [
        // 프로모션 카드 영역 (Carousel)
        _buildPromotionCarousel(),
        
        // 날짜 선택기 (Date Selector)
        _buildDateSelector(),
        
        // 매치 리스트
        _buildMatchList(),
      ],
    );
  }
  
  // 프로모션 카드 캐러셀
  Widget _buildPromotionCarousel() {
    return Column(
      children: [
        CarouselSlider(
          carouselController: _carouselController,
          options: CarouselOptions(
            height: 180,
            viewportFraction: 0.95,
            enlargeCenterPage: true,
            enableInfiniteScroll: true,
            autoPlay: false, // 수동으로 Timer로 제어
            onPageChanged: (index, reason) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
          ),
          items: _promotionCards.map((card) {
            return Builder(
              builder: (BuildContext context) {
                return Container(
                  width: MediaQuery.of(context).size.width,
                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: NetworkImage(card['imageUrl']),
                      fit: BoxFit.cover,
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
                          Colors.black.withOpacity(0.7),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          card['description'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
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
      height: 85,
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
              setState(() {
                _selectedDateIndex = index;
              });
              _filterMatchesByDate(date);
            },
            child: Container(
              width: 60,
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayFormat.format(date),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected 
                          ? Colors.white 
                          : isToday 
                              ? AppColors.primary 
                              : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    weekdayFormat.format(date),
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected 
                          ? Colors.white 
                          : isToday 
                              ? AppColors.primary 
                              : Colors.grey,
                    ),
                  ),
                  if (isToday && !isSelected)
                    const SizedBox(height: 4),
                  if (isToday && !isSelected)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  // 매치 리스트
  Widget _buildMatchList() {
    if (_filteredMatches.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.sports_esports_outlined,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              '이 날짜에 예정된 매치가 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      itemCount: _filteredMatches.length,
      itemBuilder: (context, index) {
        final match = _filteredMatches[index];
        final timeFormat = DateFormat('HH:mm');
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      timeFormat.format(match['datetime']),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, 
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        match['status'],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  match['title'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  match['type'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, 
                          vertical: 8,
                        ),
                      ),
                      child: const Text('상세 보기'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, 
                          vertical: 8,
                        ),
                      ),
                      child: const Text('참가 신청'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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