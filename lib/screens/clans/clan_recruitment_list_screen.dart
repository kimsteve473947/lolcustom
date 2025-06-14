import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';

import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/models/clan_recruitment_post_model.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:provider/provider.dart';

class ClanRecruitmentListScreen extends StatefulWidget {
  const ClanRecruitmentListScreen({Key? key}) : super(key: key);

  @override
  State<ClanRecruitmentListScreen> createState() => _ClanRecruitmentListScreenState();
}

class _ClanRecruitmentListScreenState extends State<ClanRecruitmentListScreen> {
  final ClanService _clanService = ClanService();
  final List<String> _filters = [
    '자유 랭크', '솔로 랭크', '칼바람 나락', '대회 준비', '내전', '초보 환영', '실력자만'
  ];
  String? _selectedFilter;

  void _showAddMenu() {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final myClan = appState.myClan;
    final isOwner = myClan?.ownerId == appState.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  title: const Text(
                    '어떤 걸 하시겠어요?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                ListTile(
                  title: Text('${myClan?.name ?? '내 클랜'} 멤버 모집 시작하기'),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/clans/recruit');
                  },
                  enabled: myClan != null && isOwner,
                ),
                const Divider(),
                ListTile(
                  title: const Text('새로운 팀 만들기'),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/clans/create');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('클랜원 모집'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '원하는 유형의 팀을 찾아보세요',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8.0,
              children: _filters.map((filter) {
                return ChoiceChip(
                  label: Text(filter),
                  selected: _selectedFilter == filter,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = selected ? filter : null;
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const Divider(height: 32),
          Expanded(
            child: StreamBuilder<List<ClanRecruitmentPostModel>>(
              stream: _clanService.getRecruitmentPostsStream(), // TODO: Implement this method
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('오류: ${snapshot.error}'));
                }
                final posts = snapshot.data ?? [];
                if (posts.isEmpty) {
                  return const Center(child: Text('모집 중인 클랜이 없습니다.'));
                }
                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    return _buildRecruitmentCard(posts[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildRecruitmentCard(ClanRecruitmentPostModel post) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // TODO: Use real clan emblem
            const CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey,
              child: Icon(Icons.shield, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(post.clanName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.people, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(post.applicantsCount.toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text('멤버 모집', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '모집 포지션: ${post.preferredPositions.join(', ')} / 티어: ${post.preferredTiers.join(', ')}',
                     style: const TextStyle(fontSize: 12, color: Colors.grey),
                     overflow: TextOverflow.ellipsis,
                  ),
                   const SizedBox(height: 8),
                  Text(
                    '조회 0 · 신청 ${post.applicantsCount}', // TODO: Implement view count
                     style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}