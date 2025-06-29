import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../constants/app_theme.dart';
import '../../../models/clan_model.dart';
import '../../../models/clan_application_model.dart';
import '../../../services/clan_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/clan_emblem_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_member_tab.dart';

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
  bool _isMember = false;
  bool _isOwner = false;
  bool _hasApplied = false;
  bool _isLoadingApplication = false;
  ClanApplicationModel? _currentApplication;

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
      final clan = await _clanService.getClan(widget.clanId);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.user;
      
      if (clan != null && currentUser != null) {
        final isMember = clan.members.contains(currentUser.uid);
        
        if (!isMember) {
          if (mounted) {
            context.go('/clans/public/${widget.clanId}');
          }
          return;
        }
        
        final isOwner = clan.ownerId == currentUser.uid;
        
        final applications = await _clanService.getUserApplications().first;
        final currentApplication = applications
            .where((app) => app.clanId == widget.clanId && app.status == ClanApplicationStatus.pending)
            .firstOrNull;
        
        if (mounted) {
          setState(() {
            _clan = clan;
            _isMember = isMember;
            _isOwner = isOwner;
            _hasApplied = currentApplication != null;
            _currentApplication = currentApplication;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          if (clan != null) {
            context.go('/clans/public/${widget.clanId}');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('클랜 정보를 찾을 수 없습니다')),
            );
            context.go('/clans');
          }
        }
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: LoadingIndicator()),
      );
    }

    if (_clan == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('클랜 정보'),
        ),
        body: const Center(
          child: Text('클랜 정보를 찾을 수 없습니다.'),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/clans');
                              }
                            },
                          ),
                          const Spacer(),
                          if (_isOwner)
                            _buildOwnerMenu(context),
                          _buildMemberMenu(context),
                        ],
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.2),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 3,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: ClanEmblemWidget(
                                emblemData: _clan!.emblem,
                                size: 56,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Text(
                            _clan!.name,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: 12),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildBadge(
                                icon: Icons.star_rounded,
                                text: 'Lv.${_clan!.level}',
                              ),
                              const SizedBox(width: 12),
                              _buildBadge(
                                icon: Icons.group_rounded,
                                text: '${_clan!.memberCount}/${_clan!.maxMembers}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: '오버뷰'),
                  Tab(text: '일정'),
                  Tab(text: '멤버'),
                ],
              ),
            ),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildScheduleTab(),
                  ClanMemberTab(
                    clanId: widget.clanId,
                    isOwner: _isOwner,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(
            title: '클랜 정보',
            icon: Icons.info_outline_rounded,
            children: [
              _buildInfoRow(
                icon: Icons.description_outlined,
                title: '클랜 설명',
                content: _clan!.description ?? '설명이 없습니다',
              ),
              const SizedBox(height: 16),
              _buildDiscordInfoRow(),
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoCard(
            title: '활동 정보',
            icon: Icons.schedule_rounded,
            children: [
              _buildInfoRow(
                icon: Icons.calendar_today_outlined,
                title: '활동 요일',
                content: _clan!.activityDays.isNotEmpty 
                    ? _clan!.activityDays.join(', ') 
                    : '미정',
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.access_time_outlined,
                title: '활동 시간',
                content: _clan!.activityTimes.isNotEmpty 
                    ? _clan!.activityTimes.map(_playTimeToString).join(', ') 
                    : '미정',
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoCard(
            title: '클랜 성향',
            icon: Icons.psychology_rounded,
            children: [
              _buildInfoRow(
                icon: Icons.people_outline,
                title: '선호 연령대',
                content: _clan!.ageGroups.isNotEmpty 
                    ? _clan!.ageGroups.map(_ageGroupToString).join(', ') 
                    : '모든 연령',
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.wc_outlined,
                title: '선호 성별',
                content: _genderPreferenceToString(_clan!.genderPreference),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.flag_outlined,
                title: '클랜 포커스',
                content: _clanFocusToString(_clan!.focus),
              ),
              const SizedBox(height: 20),
              _buildFocusRatingBar(_clan!.focusRating),
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoCard(
            title: '레벨 & 경험치',
            icon: Icons.trending_up_rounded,
            children: [
              _buildInfoRow(
                icon: Icons.star_outline,
                title: '현재 레벨',
                content: 'Lv. ${_clan!.level}',
              ),
              const SizedBox(height: 20),
              _buildXpBar(_clan!.xp, _clan!.xpToNextLevel),
            ],
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(
            title: '활동 요일',
            icon: Icons.calendar_today_rounded,
            children: [
              if (_clan!.activityDays.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _clan!.activityDays.map((day) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        day,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }).toList(),
                )
              else
                _buildEmptyState(
                  icon: Icons.calendar_today_outlined,
                  message: '활동 요일이 정해지지 않았습니다',
                ),
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoCard(
            title: '활동 시간대',
            icon: Icons.access_time_rounded,
            children: [
              if (_clan!.activityTimes.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _clan!.activityTimes.map((time) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.success.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _playTimeToString(time),
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }).toList(),
                )
              else
                _buildEmptyState(
                  icon: Icons.access_time_outlined,
                  message: '활동 시간대가 정해지지 않았습니다',
                ),
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoCard(
            title: '예정된 이벤트',
            icon: Icons.event_rounded,
            children: [
              _buildEmptyState(
                icon: Icons.event_available_outlined,
                message: '아직 예정된 이벤트가 없습니다',
                description: '클랜장이 이벤트를 등록하면 여기에 표시됩니다',
              ),
            ],
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.backgroundGrey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.textSecondary,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiscordInfoRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.backgroundGrey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.discord,
            color: AppColors.textSecondary,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '디스코드',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              if (_clan!.discordUrl != null && _clan!.discordUrl!.isNotEmpty)
                GestureDetector(
                  onTap: () => _launchUrl(_clan!.discordUrl!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5865F2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF5865F2).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      '디스코드 참여하기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5865F2),
                      ),
                    ),
                  ),
                )
              else
                const Text(
                  '등록된 디스코드가 없습니다',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.backgroundGrey,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFocusRatingBar(int rating) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '게임 집중도: ${rating >= 7 ? '실력 위주' : rating >= 4 ? '밸런스' : '친목 위주'}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.backgroundGrey,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.success, AppColors.warning, AppColors.error],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Positioned(
                left: (rating / 10.0) * (MediaQuery.of(context).size.width - 72),
                child: Container(
                  width: 16,
                  height: 16,
                  transform: Matrix4.translationValues(-8, -4, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '친목',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
            Text(
              '실력',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildXpBar(int currentXp, int maxXp) {
    final progress = maxXp > 0 ? currentXp / maxXp : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '경험치',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '$currentXp / $maxXp XP',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.backgroundGrey,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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

  Widget _buildOwnerMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings, color: Colors.white),
      onSelected: (value) async {
        if (value == 'manage') {
          await context.push('/clans/${widget.clanId}/manage');
          _loadClanDetails();
        } else if (value == 'transfer') {
          _transferOwnership(context);
        } else if (value == 'delete') {
          _deleteClan(context);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'manage',
          child: Text('클랜 관리'),
        ),
        const PopupMenuItem<String>(
          value: 'transfer',
          child: Text('소유자 위임'),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('클랜 삭제'),
        ),
      ],
    );
  }

  Widget _buildMemberMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (value) {
        if (value == 'leave') {
          _leaveClan(context);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'leave',
          child: Text('클랜 탈퇴'),
        ),
      ],
    );
  }

  void _leaveClan(BuildContext context) {
    if (_isOwner) {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('클랜 탈퇴 불가'),
            content: const Text('클랜 소유자는 [설정] 에서 [클랜 소유자 위임] 후 탈퇴할 수 있습니다.'),
            actions: <Widget>[
              TextButton(
                child: const Text('확인'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('클랜 탈퇴'),
          content: const Text('정말로 클랜을 탈퇴하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('탈퇴'),
              onPressed: () async {
                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  await _clanService.removeMember(widget.clanId, authProvider.user!.uid);
                  Navigator.of(dialogContext).pop();
                  context.go('/clans');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('클랜에서 탈퇴했습니다.')),
                  );
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('클랜 탈퇴 중 오류 발생: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteClan(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('클랜 삭제'),
          content: const Text('정말로 클랜을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                try {
                  await _clanService.deleteClan(widget.clanId);
                  Navigator.of(dialogContext).pop();
                  context.go('/clans');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('클랜을 삭제했습니다.')),
                  );
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('클랜 삭제 중 오류 발생: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _transferOwnership(BuildContext context) async {
    try {
      final members = await _clanService.getClanMembers(widget.clanId);
      final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
      final otherMembers = members.where((m) => m['uid'] != currentUser!.uid).toList();

      if (otherMembers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위임할 다른 멤버가 없습니다.')),
        );
        return;
      }

      _showTransferOwnershipDialog(context, otherMembers);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('멤버 정보를 불러오는 중 오류 발생: $e')),
      );
    }
  }

  void _showTransferOwnershipDialog(BuildContext context, List<Map<String, dynamic>> members) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('소유자 위임'),
          content: SizedBox(
            width: double.minPositive,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return ListTile(
                  title: Text(member['displayName']),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _confirmTransfer(context, member['uid'], member['displayName']);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _confirmTransfer(BuildContext context, String newOwnerId, String newOwnerName) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('소유자 위임 확인'),
          content: Text('$newOwnerName 님에게 클랜 소유권을 위임하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('위임'),
              onPressed: () async {
                try {
                  await _clanService.transferClanOwnership(widget.clanId, newOwnerId);
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('클랜 소유권을 위임했습니다.')),
                  );
                  _loadClanDetails();
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('소유권 위임 중 오류 발생: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}