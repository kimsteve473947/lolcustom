import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/models/clan_application_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart' as CustomAuth;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClanListScreen extends StatefulWidget {
  const ClanListScreen({Key? key}) : super(key: key);

  @override
  State<ClanListScreen> createState() => _ClanListScreenState();
}

class _ClanListScreenState extends State<ClanListScreen> {
  final ClanService _clanService = ClanService();
  ClanModel? _userClan;
  bool _isLoading = true;
  bool _isUserClanOwner = false;
  
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _loadUserClan();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = GoRouter.of(context);
    final uri = route.routeInformationProvider.value.uri;
    if (uri.queryParameters['refresh'] == 'true') {
      _loadUserClan();
    }
  }
  
  Future<void> _loadUserClan() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 현재 사용자의 클랜 정보 가져오기
      final clan = await _clanService.getCurrentUserClan();
      
      // 현재 사용자가 클랜장인지 확인
      bool isOwner = false;
      if (clan != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          isOwner = clan.ownerId == user.uid;
        }
      }
      
      if (mounted) {
        setState(() {
          _userClan = clan;
          _isUserClanOwner = isOwner;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('클랜 정보를 불러오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<CustomAuth.AuthProvider>(context);
    final isLoggedIn = authProvider.isLoggedIn;
    
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserClan,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroSection(),
                        
                        // 내 클랜 정보 (클랜이 있는 경우)
                        if (_userClan != null)
                          _buildUserClanSection(_userClan!, _isUserClanOwner),
                          
                        _buildRecruitingClansSection(),
                        _buildClanTournamentsSection(),
                        
                        // 로그인한 경우에만 신청 내역 표시
                        if (isLoggedIn)
                          _buildApplicationHistorySection(),
                          
                        const SizedBox(height: 80), // Bottom padding for safe area
                      ],
                    ),
                  ),
                  if (_userClan == null && authProvider.isLoggedIn)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: () {
                          context.push('/clans/create');
                        },
                        backgroundColor: Colors.orange,
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildHeroSection() {
    return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
            AppColors.primaryLight,
              ],
            ),
          ),
      child: SafeArea(
        bottom: false,
          child: Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단 네비게이션
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                      '클랜',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                        fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.search, color: Colors.white, size: 22),
                      onPressed: () {
                        context.push('/clans/search');
                      },
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                    ),
                          child: IconButton(
                            icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('알림 기능은 준비 중입니다'),
                                  backgroundColor: AppColors.info,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                        );
                      },
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
              
              const SizedBox(height: 40),
        
              // Hero 콘텐츠
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _userClan != null
                    ? _isUserClanOwner
                              ? '클랜을 성장시켜보세요'
                              : '함께 성장하는 클랜'
                          : '나만의 클랜을 만들어보세요',
                style: const TextStyle(
                  color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _userClan != null
                          ? '멤버들과 함께 더 높은 곳으로'
                          : '동료들과 함께 시작하는 여정',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 24),
              if (_userClan == null)
                ElevatedButton(
                  onPressed: () {
                    context.push('/clans/create');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                          elevation: 0,
                          minimumSize: const Size(160, 48),
                    shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    '클랜 만들기',
                    style: TextStyle(
                      fontSize: 16,
                            fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildUserClanSection(ClanModel clan, bool isOwner) {
    return Container(
      color: AppColors.backgroundGrey,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '내 클랜',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (isOwner)
                TextButton.icon(
                  onPressed: () {
                    context.push('/clan/${clan.id}/manage');
                  },
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('관리'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              debugPrint('클랜 상세 페이지로 이동: ${clan.id}');
              context.push('/clans/${clan.id}');
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.border,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                            width: 3,
                          ),
                        ),
                        child: _buildClanEmblem(clan),
                      ),
                      const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                          clan.name,
                          style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                          ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textTertiary,
                                ),
                              ],
                        ),
                            const SizedBox(height: 6),
                        Text(
                              '${clan.description}',
                          style: TextStyle(
                            fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          ),
                      ),
                    ],
                        ),
                  const SizedBox(height: 20),
                  // 통계 정보
                            Container(
                    padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                      color: AppColors.backgroundGrey,
                      borderRadius: BorderRadius.circular(16),
                              ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          icon: Icons.people_rounded,
                          value: '${clan.memberCount}',
                          label: '멤버',
                          color: AppColors.primary,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.divider,
                        ),
                        _buildStatItem(
                          icon: Icons.military_tech_rounded,
                          value: isOwner ? '클랜장' : '클랜원',
                          label: '내 역할',
                          color: isOwner ? AppColors.warning : AppColors.info,
                                ),
                            Container(
                          width: 1,
                          height: 40,
                          color: AppColors.divider,
                        ),
                        _buildStatItem(
                          icon: Icons.trending_up_rounded,
                          value: clan.focus == ClanFocus.casual ? '친목' : 
                                 clan.focus == ClanFocus.competitive ? '실력' : '균형',
                          label: '성향',
                          color: AppColors.success,
                                ),
                      ],
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
  
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
              ),
            ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
      ),
        ),
      ],
    );
  }
  
  Widget _buildClanEmblem(ClanModel clan) {
    if (clan.emblem is String && (clan.emblem as String).startsWith('http')) {
      // 이미지 URL인 경우
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: NetworkImage(clan.emblem as String),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else if (clan.emblem is Map) {
      // 기본 엠블럼인 경우
      final emblem = clan.emblem as Map;
      final Color backgroundColor = emblem['backgroundColor'] as Color? ?? AppColors.primary;
      final String symbol = emblem['symbol'] as String? ?? 'sports_soccer';
      
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            _getIconData(symbol),
            color: Colors.white,
            size: 30,
          ),
        ),
      );
    } else {
      // 기본 아이콘
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.groups,
            color: Colors.white,
            size: 30,
          ),
        ),
      );
    }
  }
  
  Widget _buildRecruitingClansSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              '멤버 모집중',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            child: StreamBuilder<List<ClanModel>>(
              stream: _clanService.getClans(onlyRecruiting: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('오류가 발생했습니다: ${snapshot.error}'),
                  );
                }
                
                final clans = snapshot.data ?? [];
                
                if (clans.isEmpty) {
                  return Center(
                    child: Text(
                      '현재 모집중인 클랜이 없습니다',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  );
                }
                
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: clans.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    return _buildClanCard(clans[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClanCard(ClanModel clan) {
    final authProvider = Provider.of<CustomAuth.AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    final isMember = currentUser != null && clan.members.contains(currentUser.uid);

    return GestureDetector(
      onTap: () {
        if (isMember) {
          context.push('/clans/${clan.id}');
        } else {
          context.push('/clans/public/${clan.id}');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
        width: 180,
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단 색상 배너
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
            _buildClanEmblem(clan),
            const SizedBox(height: 12),
                  Text(
                clan.name,
                style: const TextStyle(
                      fontWeight: FontWeight.w700,
                  fontSize: 16,
                      color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                    textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
                    '멤버 ${clan.memberCount}/${clan.maxMembers}',
              style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
              ),
            ),
                  const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFocusBadge(clan.focus),
                      const SizedBox(width: 8),
                      if (clan.isRecruiting)
                Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                  ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '모집중',
                    style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
                        ),
                    ],
              ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFocusBadge(ClanFocus focus) {
    Color color;
    String label;
    IconData icon;
    
    switch (focus) {
      case ClanFocus.casual:
        color = AppColors.success;
        label = '친목';
        icon = Icons.favorite_rounded;
        break;
      case ClanFocus.competitive:
        color = AppColors.error;
        label = '실력';
        icon = Icons.local_fire_department_rounded;
        break;
      case ClanFocus.balanced:
        color = AppColors.info;
        label = '균형';
        icon = Icons.balance_rounded;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
        label,
        style: TextStyle(
          color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildClanTournamentsSection() {
    return Container(
      color: AppColors.backgroundGrey,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '클랜 활동',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '다양한 활동으로 클랜을 성장시켜보세요',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildActivityCard(
                  '클랜 토너먼트',
                  Icons.emoji_events_rounded,
                  AppColors.warning,
                  '준비중',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActivityCard(
                  '게스트 모집',
                  Icons.person_add_rounded,
                  AppColors.info,
                  '준비중',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActivityCard(
                  '클랜 찾기',
                  Icons.group_add_rounded,
                  AppColors.primary,
                  null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(String title, IconData icon, Color color, String? badge) {
    return GestureDetector(
      onTap: () {
        if (title == '클랜 찾기') {
          context.push('/clans/recruitment-list');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title 기능은 준비 중입니다'),
              backgroundColor: AppColors.info,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
              icon,
                    size: 24,
              color: color,
                  ),
                ),
                if (badge != null)
                  Transform.translate(
                    offset: const Offset(8, -8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationHistorySection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 토스 스타일의 섹션 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '진행중인 신청',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              // 더보기 버튼 제거 (진행중인 것만 보여주므로 불필요)
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<ClanApplicationModel>>(
            stream: _clanService.getUserApplications(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                );
              }
              
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '신청 내역을 불러오는 중 오류가 발생했습니다',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              // pending 상태인 신청만 필터링
              final applications = snapshot.data ?? [];
              final pendingApplications = applications
                  .where((app) => app.status == ClanApplicationStatus.pending)
                  .toList();
              
              if (pendingApplications.isEmpty) {
                return _buildEmptyStateWidget();
              }
              
              return Column(
                children: pendingApplications.map((application) {
                  return TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: _buildApplicationItem(application),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyStateWidget() {
                return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  decoration: BoxDecoration(
        color: AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.borderLight,
          width: 1,
        ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.group_add_outlined,
              size: 32,
              color: AppColors.textTertiary,
            ),
                      ),
          const SizedBox(height: 20),
                      Text(
            '진행중인 신청이 없어요',
                        style: TextStyle(
                          fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
            '새로운 클랜을 찾아 신청해보세요',
                        style: TextStyle(
                          fontSize: 14,
              color: AppColors.textSecondary,
                        ),
                      ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              // 클랜 찾기 화면으로 이동
              context.push('/clans/recruitment-list');
            },
            icon: const Icon(Icons.search, size: 18),
            label: const Text('클랜 찾아보기'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildApplicationItem(ClanApplicationModel application) {
    return FutureBuilder<ClanModel?>(
      future: _clanService.getClan(application.clanId),
      builder: (context, snapshot) {
        final clan = snapshot.data;
        
        return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.border,
              width: 1,
            ),
              boxShadow: [
                BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 10,
                offset: const Offset(0, 2),
                ),
              ],
            ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                // 클랜 상세 페이지로 이동
                if (clan != null) {
                  context.push('/clans/${clan.id}');
                }
              },
              onLongPress: () {
                // 길게 누르면 신청 취소 다이얼로그 표시
                _showCancelApplicationDialog(application);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                    // 클랜 엠블럼
                  Container(
                      width: 56,
                      height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                        color: AppColors.backgroundGrey,
                        border: Border.all(
                          color: AppColors.border,
                          width: 1,
                        ),
                    ),
                      child: clan != null 
                          ? _buildSmallClanEmblem(clan)
                          : const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                        clan?.name ?? '불러오는 중...',
                        style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                          fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              // 상태 배지 - 진행중만 표시하므로 동일한 스타일
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: AppColors.warning,
                                        shape: BoxShape.circle,
                        ),
                      ),
                                    const SizedBox(width: 6),
                      Text(
                                      '검토중',
                        style: TextStyle(
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: AppColors.textTertiary,
                  ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(application.appliedAt),
                    style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              if (clan != null) ...[
                                Icon(
                                  Icons.people_outline,
                                  size: 14,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${clan.memberCount}/${clan.maxMembers}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 액션 힌트
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                      size: 20,
                  ),
              ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildSmallClanEmblem(ClanModel clan) {
    if (clan.emblem is String && (clan.emblem as String).startsWith('http')) {
      return ClipOval(
        child: Image.network(
          clan.emblem as String,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultEmblem();
          },
        ),
      );
    } else if (clan.emblem is Map) {
      final emblem = clan.emblem as Map;
      final Color backgroundColor = emblem['backgroundColor'] as Color? ?? AppColors.primary;
      final String symbol = emblem['symbol'] as String? ?? 'sports_soccer';
      
      return Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            _getIconData(symbol),
            color: Colors.white,
            size: 24,
          ),
        ),
      );
    }
    
    return _buildDefaultEmblem();
  }
  
  Widget _buildDefaultEmblem() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.groups,
          color: AppColors.primary,
          size: 24,
        ),
      ),
    );
  }
  
  void _showCancelApplicationDialog(ClanApplicationModel application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          '신청 취소',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          '클랜 가입 신청을 취소하시겠습니까?',
          style: TextStyle(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '아니요',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _clanService.cancelClanApplication(application.id);
                if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('신청이 취소되었습니다'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                );
                }
              } catch (e) {
                if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('취소 실패: $e'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                );
                }
              }
            },
            child: Text(
              '네, 취소합니다',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year}/${date.month}/${date.day}';
  }
  
  IconData _getIconData(String symbol) {
    final Map<String, IconData> iconMap = {
      'shield': Icons.shield,
      'star': Icons.star,
      'sports_soccer': Icons.sports_soccer,
      'sports_basketball': Icons.sports_basketball,
      'sports_baseball': Icons.sports_baseball,
      'sports_football': Icons.sports_football,
      'sports_volleyball': Icons.sports_volleyball,
      'sports_tennis': Icons.sports_tennis,
      'whatshot': Icons.whatshot,
      'bolt': Icons.bolt,
      'pets': Icons.pets,
      'favorite': Icons.favorite,
      'stars': Icons.stars,
      'military_tech': Icons.military_tech,
      'emoji_events': Icons.emoji_events,
      'local_fire_department': Icons.local_fire_department,
      'public': Icons.public,
      'cruelty_free': Icons.cruelty_free,
      'emoji_nature': Icons.emoji_nature,
      'rocket_launch': Icons.rocket_launch,
    };
    
    return iconMap[symbol] ?? Icons.star;
  }
}