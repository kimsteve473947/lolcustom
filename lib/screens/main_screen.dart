import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/screens/chat/chat_list_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_list_screen.dart';
import 'package:lol_custom_game_manager/screens/my_page/my_page_screen.dart';
import 'package:lol_custom_game_manager/screens/rankings/rankings_screen.dart';
import 'package:lol_custom_game_manager/screens/tournaments/tournament_main_screen.dart';
import 'package:lol_custom_game_manager/screens/college_league/college_league_screen.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
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
    
    // 대학 대항전 화면일 때는 내전 탭을 선택된 것으로 표시
    final displayIndex = widget.child is CollegeLeagueScreen ? 0 : _currentIndex;
    
    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: displayIndex,
        onTap: (index) {
          if (widget.child != null) {
            // child가 있을 때는 항상 해당 탭의 메인 화면으로 이동
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
            // 현재 선택된 탭과 클릭한 탭이 같으면 해당 메인 화면으로 이동
            if (_currentIndex == index) {
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
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
  
  Widget? _buildFloatingActionButton() {
    // 모든 화면에서 기본 FAB 표시하지 않음
    return null;
  }
} 