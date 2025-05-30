import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/screens/chat/chat_list_screen.dart';
import 'package:lol_custom_game_manager/screens/mercenaries/mercenary_list_screen.dart';
import 'package:lol_custom_game_manager/screens/my_page/my_page_screen.dart';
import 'package:lol_custom_game_manager/screens/rankings/rankings_screen.dart';
import 'package:lol_custom_game_manager/screens/tournaments/tournament_list_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  
  const MainScreen({
    Key? key,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  late PageController _pageController;
  
  final List<Widget> _screens = [
    const TournamentListScreen(),  // 용병구함
    const MercenaryListScreen(),   // 용병있음
    const ChatListScreen(),        // 메시지
    const RankingsScreen(),        // 랭킹
    const MyPageScreen(),          // MY
  ];
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
  
  void _onItemTapped(int index) {
    // PageView 애니메이션 적용
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const NeverScrollableScrollPhysics(), // 스와이프로 페이지 전환 비활성화
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: '용병구함',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_search),
            label: '용병있음',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: '메시지',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard_outlined),
            label: '랭킹',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'MY',
          ),
        ],
      ),
    );
  }
} 