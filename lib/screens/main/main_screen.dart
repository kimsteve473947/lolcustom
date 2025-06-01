import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/screens/chat/chat_list_screen.dart';
import 'package:lol_custom_game_manager/screens/mercenaries/mercenaries_screen.dart';
import 'package:lol_custom_game_manager/screens/my_page/my_page_screen.dart';
import 'package:lol_custom_game_manager/screens/rankings/rankings_screen.dart';
import 'package:lol_custom_game_manager/screens/tournaments/tournament_list_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final Widget? child;

  const MainScreen({
    Key? key,
    this.initialIndex = 0,
    this.child,
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }
  
  final List<Widget> _screens = [
    const TournamentListScreen(),
    const MercenariesScreen(),
    const ChatListScreen(),
    const RankingsScreen(),
    const MyPageScreen(),
  ];
  
  final List<String> _paths = [
    '/tournaments',
    '/mercenaries',
    '/chat',
    '/rankings',
    '/mypage',
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child ?? _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index != _currentIndex) {
            setState(() => _currentIndex = index);
            context.go(_paths[index]);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_soccer),
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