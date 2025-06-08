import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/screens/chat/chat_list_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_list_screen.dart';
import 'package:lol_custom_game_manager/screens/my_page/my_page_screen.dart';
import 'package:lol_custom_game_manager/screens/rankings/rankings_screen.dart';
import 'package:lol_custom_game_manager/screens/tournaments/tournament_main_screen.dart';
import 'package:go_router/go_router.dart';

class MainScreen extends StatefulWidget {
  final int initialTabIndex;
  final Widget? child;
  
  const MainScreen({Key? key, this.initialTabIndex = 0, this.child}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  
  final List<Widget> _screens = const [
    TournamentMainScreen(),
    ClanListScreen(),
    ChatListScreen(),
    RankingsScreen(),
    MyPageScreen(),
  ];
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }
  
  @override
  Widget build(BuildContext context) {
    final body = widget.child ?? _screens[_currentIndex];
    
    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (widget.child != null) {
            switch (index) {
              case 0:
                context.go('/tournaments');
                break;
              case 1:
                context.go('/clans');
                break;
              case 2:
                context.go('/chat');
                break;
              case 3:
                context.go('/rankings');
                break;
              case 4:
                context.go('/mypage');
                break;
            }
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '내전',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: '클랜',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            activeIcon: Icon(Icons.chat),
            label: '채팅',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard_outlined),
            activeIcon: Icon(Icons.leaderboard),
            label: '랭킹',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'MY',
          ),
        ],
      ),
    );
  }
} 