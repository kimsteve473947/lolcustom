import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_member_tab.dart';
import 'package:lol_custom_game_manager/widgets/clan_emblem_widget.dart';
import 'dart:ui';

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
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/clans');
              }
            },
          ),
          actions: [
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final isOwner = authProvider.user?.uid == _clan?.ownerId;
                if (isOwner) {
                  return IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () async {
                      await context.push('/clans/${widget.clanId}/manage');
                      _loadClanDetails();
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
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
              ClanMemberTab(
                clanId: _clan!.id,
                isOwner: context.read<AuthProvider>().user?.uid == _clan!.ownerId,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFE0E0E0), // 임시로 직접 색상 코드 사용
            ),
          ),
          // Frosted glass effect
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              color: Colors.black.withOpacity(0.1),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 50.0), // Space for the TabBar
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClanEmblemWidget(
                    emblemData: _clan!.emblem,
                    size: 100,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _clan!.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black54, offset: Offset(1, 1))],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lv. ${_clan!.level}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.8),
                      shadows: const [Shadow(blurRadius: 1, color: Colors.black26, offset: Offset(1, 1))],
                    ),
                  ),
                ],
              ),
            ),
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
          _buildSectionTitle('클랜 정보'),
          _infoRow(Icons.shield_outlined, '클랜명', _clan!.name),
          _infoRow(Icons.description_outlined, '클랜 설명', _clan!.description ?? '없음'),
          _buildDiscordRow(),
          const SizedBox(height: 24),
          _buildSectionTitle('활동 정보'),
          _infoRow(Icons.calendar_today_outlined, '활동 요일', _clan!.activityDays.isNotEmpty ? _clan!.activityDays.join(', ') : '미정'),
          _infoRow(Icons.access_time_outlined, '활동 시간', _clan!.activityTimes.isNotEmpty ? _clan!.activityTimes.map(_playTimeToString).join(', ') : '미정'),
          const SizedBox(height: 24),
          _buildSectionTitle('클랜 성향'),
          _infoRow(Icons.people_outline, '선호 연령대', _clan!.ageGroups.isNotEmpty ? _clan!.ageGroups.map(_ageGroupToString).join(', ') : '모든 연령'),
          _infoRow(Icons.wc_outlined, '선호 성별', _genderPreferenceToString(_clan!.genderPreference)),
          _infoRow(Icons.flag_outlined, '클랜 포커스', _clanFocusToString(_clan!.focus)),
          _buildFocusRatingBar(_clan!.focusRating),
          const SizedBox(height: 24),
          _buildSectionTitle('멤버 및 레벨'),
          _infoRow(Icons.group_outlined, '멤버', '${_clan!.memberCount} / ${_clan!.maxMembers}'),
          _infoRow(Icons.star_outline, '레벨', 'Lv. ${_clan!.level}'),
          _buildXpBar(_clan!.xp, _clan!.xpToNextLevel),
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

  String _clanFocusToString(ClanFocus focus) {
    switch (focus) {
      case ClanFocus.casual: return '친목 위주';
      case ClanFocus.competitive: return '실력 위주';
      case ClanFocus.balanced: return '균형';
      default: return '';
    }
  }

  Widget _buildFocusRatingBar(int rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          const Icon(Icons.balance, color: Colors.grey),
          const SizedBox(width: 16),
          const SizedBox(
            width: 100,
            child: Text('성향', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LinearProgressIndicator(
                  value: rating / 10.0,
                  backgroundColor: Colors.grey.shade300,
                  color: Color.lerp(Colors.blue, Colors.red, rating / 10.0),
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

  Widget _buildXpBar(int currentXp, int xpToNextLevel) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          const Icon(Icons.trending_up, color: Colors.grey),
          const SizedBox(width: 16),
          const SizedBox(
            width: 100,
            child: Text('경험치', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LinearProgressIndicator(
                  value: currentXp / xpToNextLevel,
                  backgroundColor: Colors.grey.shade300,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  '$currentXp / $xpToNextLevel XP',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
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
  Widget _buildDiscordRow() {
    final discordUrl = _clan?.discordUrl;
    final bool hasUrl = discordUrl != null && discordUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(Icons.discord, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: Text('디스코드', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
          ),
          Expanded(
            child: InkWell(
              onTap: hasUrl ? () async {
                if (discordUrl != null) {
                  final uri = Uri.parse(discordUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('링크를 열 수 없습니다: $discordUrl')),
                    );
                  }
                }
              } : null,
              child: Text(
                hasUrl ? discordUrl : '없음',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: hasUrl ? Colors.blue : Colors.black,
                  decoration: hasUrl ? TextDecoration.underline : TextDecoration.none,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ],
      ),
    );
  }
}