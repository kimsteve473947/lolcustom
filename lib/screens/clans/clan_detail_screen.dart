import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:go_router/go_router.dart';

class ClanDetailScreen extends StatefulWidget {
  final String clanId;

  const ClanDetailScreen({Key? key, required this.clanId}) : super(key: key);

  @override
  State<ClanDetailScreen> createState() => _ClanDetailScreenState();
}

class _ClanDetailScreenState extends State<ClanDetailScreen> with SingleTickerProviderStateMixin {
  final ClanService _clanService = ClanService();
  late TabController _tabController;
  ClanModel? _clan;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadClanDetails();
  }

  Future<void> _loadClanDetails() async {
    try {
      final clan = await _clanService.getClan(widget.clanId);
      if (mounted) {
        setState(() {
          _clan = clan;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('클랜 정보를 불러오는 중 오류가 발생했습니다: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : _clan == null
              ? const Center(child: Text('클랜 정보를 찾을 수 없습니다.'))
              : _buildClanDetailBody(),
    );
  }

  Widget _buildClanDetailBody() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 250.0,
          floating: false,
          pinned: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(icon: const Icon(Icons.settings), onPressed: () { /* 설정 페이지로 이동 */ }),
            IconButton(icon: const Icon(Icons.more_vert), onPressed: () { /* 더보기 메뉴 */ }),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildHeader(),
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '오버뷰'),
              Tab(text: '일정'),
              Tab(text: '멤버'),
            ],
          ),
        ),
        SliverFillRemaining(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              const Center(child: Text('일정 정보가 여기에 표시됩니다.')),
              const Center(child: Text('멤버 목록이 여기에 표시됩니다.')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _clan!.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _clan!.description ?? '클랜 설명이 없습니다.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 여기에 엠블럼 위젯 추가
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('주요 멤버'),
          // 주요 멤버 위젯
          const SizedBox(height: 24),
          _buildSectionTitle('팀 정보'),
          _infoRow(Icons.location_on, '지역', '경기 성남시'), // 예시 데이터
          _infoRow(Icons.home, '홈 구장', '성남 분당 풋살파크'), // 예시 데이터
          _infoRow(Icons.schedule, '모임 시간', _clan!.activityTimes.map((e) => e.toString().split('.').last).join(', ')),
          _infoRow(Icons.people, '평균 나이', _clan!.ageGroups.map((e) => e.toString().split('.').last).join(', ')),
          _infoRow(Icons.link, '웹사이트', _clan!.discordUrl ?? '없음'),
          _infoRow(Icons.group, '멤버', '${_clan!.memberCount}/${_clan!.maxMembers}'),
          _infoRow(Icons.star, '레벨', 'Lv. ${_clan!.level}'),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}