import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/screens/tournaments/match_list_tab.dart';
import 'package:lol_custom_game_manager/screens/tournaments/mercenary_search_tab.dart';
import 'package:go_router/go_router.dart';

class TournamentMainScreen extends StatefulWidget {
  const TournamentMainScreen({Key? key}) : super(key: key);

  @override
  State<TournamentMainScreen> createState() => _TournamentMainScreenState();
}

class _TournamentMainScreenState extends State<TournamentMainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내전'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: '매치 찾기'),
            Tab(text: '용병 찾기'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // 검색 기능 구현
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('검색 기능은 준비 중입니다')),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MatchListTab(),
          MercenarySearchTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 내전 생성 화면으로 이동
          context.push('/tournaments/create');
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
} 