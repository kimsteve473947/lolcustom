import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';

class ClanDetailScreen extends StatefulWidget {
  final String clanId;
  
  const ClanDetailScreen({
    Key? key,
    required this.clanId,
  }) : super(key: key);

  @override
  State<ClanDetailScreen> createState() => _ClanDetailScreenState();
}

class _ClanDetailScreenState extends State<ClanDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadClanDetails();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadClanDetails() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // TODO: 클랜 상세 정보 로드 로직 구현
      await Future.delayed(const Duration(seconds: 1)); // 임시 딜레이
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('클랜 정보 로드 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('클랜 정보'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '정보'),
            Tab(text: '멤버'),
            Tab(text: '활동'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(),
                _buildMembersTab(),
                _buildActivitiesTab(),
              ],
            ),
    );
  }
  
  Widget _buildInfoTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.groups, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            '샘플 클랜',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '리그 오브 레전드를 함께 즐기는 클랜입니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '클랜 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _infoRow('생성일', '2023년 9월 15일'),
          _infoRow('클랜 레벨', 'Lv. 3'),
          _infoRow('멤버수', '15명'),
        ],
      ),
    );
  }
  
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMembersTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '아직 등록된 멤버가 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActivitiesTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '아직 활동 내역이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
} 