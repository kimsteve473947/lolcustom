import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:lol_custom_game_manager/widgets/clan_emblem_widget.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';

class ClanPublicProfileScreen extends StatefulWidget {
  final String clanId;

  const ClanPublicProfileScreen({Key? key, required this.clanId}) : super(key: key);

  @override
  _ClanPublicProfileScreenState createState() => _ClanPublicProfileScreenState();
}

class _ClanPublicProfileScreenState extends State<ClanPublicProfileScreen> {
  final ClanService _clanService = ClanService();
  late Future<ClanModel?> _clanFuture;
  String _averageTier = '계산 중...';

  @override
  void initState() {
    super.initState();
    _clanFuture = _clanService.getClan(widget.clanId);
    _fetchAverageTier();
  }

  Future<void> _fetchAverageTier() async {
    try {
      final tier = await _clanService.getAverageTier(widget.clanId);
      if (mounted) {
        setState(() {
          _averageTier = tier;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _averageTier = '정보 없음';
        });
      }
    }
  }

  void _applyToClan(ClanModel clan) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    try {
      await _clanService.applyClanWithDetails(clanId: clan.id, message: "클랜 가입을 신청합니다!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클랜 가입 신청이 완료되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('클랜 정보'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<ClanModel?>(
        future: _clanFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('클랜 정보를 불러올 수 없습니다.'));
          }

          final clan = snapshot.data!;
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final isMember = clan.members.contains(authProvider.user?.uid);

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0), // Button space
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(clan),
                    const SizedBox(height: 24),
                    _buildDescriptionCard(clan),
                    const SizedBox(height: 16),
                    _buildPreferenceCard(clan),
                     const SizedBox(height: 16),
                    _buildActivityCard(clan),
                  ],
                ),
              ),
              if (!isMember)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () => _applyToClan(clan),
                      child: const Text('가입 신청하기'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(ClanModel clan) {
    return Row(
      children: [
        ClanEmblemWidget(emblemData: clan.emblem, size: 80),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(clan.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('레벨 ${clan.level} | 멤버 ${clan.memberCount}/${clan.maxMembers}', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionCard(ClanModel clan) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('클랜 소개'),
            const SizedBox(height: 8),
            Text(clan.description ?? '클랜 설명이 없습니다.', style: const TextStyle(fontSize: 16, height: 1.5)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPreferenceCard(ClanModel clan) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             _buildSectionTitle('클랜 성향'),
             const SizedBox(height: 16),
            _infoRow(Icons.shield_outlined, '평균 티어', _averageTier),
            _infoRow(Icons.wc_outlined, '선호 성별', _genderPreferenceToString(clan.genderPreference)),
            _infoRow(Icons.people_outline, '선호 연령대', clan.ageGroups.isNotEmpty ? clan.ageGroups.map(_ageGroupToString).join(', ') : '모든 연령'),
            const SizedBox(height: 8),
            _buildFocusRatingBar(clan.focusRating),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(ClanModel clan) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('활동 정보'),
            const SizedBox(height: 16),
            _infoRow(Icons.calendar_today_outlined, '활동 요일', clan.activityDays.isNotEmpty ? clan.activityDays.join(', ') : '미정'),
            _infoRow(Icons.access_time_outlined, '활동 시간', clan.activityTimes.isNotEmpty ? clan.activityTimes.map(_playTimeToString).join(', ') : '미정'),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 22),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 16, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildFocusRatingBar(int rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          const Icon(Icons.balance, color: Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LinearProgressIndicator(
                  value: rating / 10.0,
                  backgroundColor: Colors.grey.shade300,
                  color: Color.lerp(Colors.blue, Colors.red, rating / 10.0),
                  minHeight: 6,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('친목', style: TextStyle(fontSize: 12)),
                    Text('실력', style: TextStyle(fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _playTimeToString(PlayTimeType type) {
    switch (type) {
      case PlayTimeType.morning: return '아침';
      case PlayTimeType.daytime: return '낮';
      case PlayTimeType.evening: return '저녁';
      case PlayTimeType.night: return '심야';
      default: return '';
    }
  }

  String _ageGroupToString(AgeGroup group) {
    switch (group) {
      case AgeGroup.teens: return '10대';
      case AgeGroup.twenties: return '20대';
      case AgeGroup.thirties: return '30대';
      case AgeGroup.fortyPlus: return '40대 이상';
      default: return '';
    }
  }

  String _genderPreferenceToString(GenderPreference preference) {
    switch (preference) {
      case GenderPreference.male: return '남성';
      case GenderPreference.female: return '여성';
      case GenderPreference.any: return '남녀 모두';
      default: return '';
    }
  }
}