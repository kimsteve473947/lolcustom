import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart' as CustomAuth;
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/screens/my_page/widgets/activity_tab.dart';
import 'package:lol_custom_game_manager/screens/my_page/widgets/calendar_tab.dart';
import 'package:lol_custom_game_manager/screens/my_page/widgets/credit_history_tab.dart';
import 'package:lol_custom_game_manager/screens/my_page/widgets/friends_tab.dart';
import 'package:lol_custom_game_manager/screens/my_page/widgets/profile_header.dart';
import 'package:lol_custom_game_manager/screens/my_page/credit_charge_screen.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';


class MyPageScreen extends StatefulWidget {
  const MyPageScreen({Key? key}) : super(key: key);

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  @override
  void initState() {
    super.initState();
    _syncUserData();
  }
  
  Future<void> _syncUserData() async {
    final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
    try {
      await appStateProvider.syncCurrentUser();
    } catch (e) {
      debugPrint('MyPageScreen - 사용자 데이터 동기화 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<CustomAuth.AuthProvider>(context);
    final appStateProvider = Provider.of<AppStateProvider>(context);
    final user = appStateProvider.currentUser;

    if (!authProvider.isLoggedIn || user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('로그인이 필요합니다'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('로그인하기'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _syncUserData,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // 토스 스타일 앱바
            SliverAppBar(
              expandedHeight: 0,
              floating: true,
              pinned: false,
              backgroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                '마이',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  color: const Color(0xFF1A1A1A),
                  onPressed: () {
                    context.push('/settings/fcm-test');
                  },
                ),
              ],
            ),
            
            // 프로필 섹션
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // 프로필 이미지
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _getTierColor(user.tier).withOpacity(0.3),
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child: user.profileImageUrl != null
                                ? Image.network(
                                    user.profileImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildDefaultAvatar(user),
                                  )
                                : _buildDefaultAvatar(user),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // 사용자 정보
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    user.nickname,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 티어 배지
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getTierColor(user.tier).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _getTierName(user.tier),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getTierColor(user.tier),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.statusMessage ?? '안녕하세요! 반갑습니다 👋',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 프로필 편집 버튼
                    InkWell(
                      onTap: () => context.go('/mypage/edit-profile'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            '프로필 편집',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 8),
            ),
            
            // 크레딧 섹션
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
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
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => context.go('/mypage/credit-charge'),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.account_balance_wallet_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '내 크레딧',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${user.credits.toStringAsFixed(0)} 크레딧',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '충전',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
            
            // 메뉴 섹션
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Text(
                        '내 활동',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    _buildMenuItem(
                      icon: Icons.emoji_events_outlined,
                      title: '내 토너먼트',
                      subtitle: '참가한 토너먼트 기록',
                      onTap: () {
                        // TODO: 내 토너먼트 화면
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.people_outline,
                      title: '클랜 관리',
                      subtitle: appStateProvider.myClan != null 
                          ? appStateProvider.myClan!.name
                          : '클랜에 가입하세요',
                      onTap: () {
                        if (appStateProvider.myClan != null) {
                          context.push('/clans/${appStateProvider.myClan!.id}');
                        }
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.star_outline,
                      title: '신뢰도 점수',
                      subtitle: '참가자 평가 ${user.playerScore.toStringAsFixed(1)}점',
                      badge: user.playerScore >= 90.0
                          ? '우수'
                          : null,
                      badgeColor: AppColors.success,
                      onTap: () => context.go('/mypage/participant-trust'),
                    ),
                    _buildMenuItem(
                      icon: Icons.shield_outlined,
                      title: '용병 프로필',
                      subtitle: '용병으로 활동하기',
                      onTap: () => context.push('/mercenaries/register'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
            
            // 기타 메뉴
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Text(
                        '기타',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    _buildMenuItem(
                      icon: Icons.history,
                      title: '크레딧 내역',
                      subtitle: '충전 및 사용 내역',
                      onTap: () {
                        // TODO: 크레딧 내역 화면
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.calendar_today_outlined,
                      title: '일정',
                      subtitle: '나의 토너먼트 일정',
                      onTap: () {
                        // TODO: 일정 화면
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.notifications_outlined,
                      title: '알림 설정',
                      subtitle: '푸시 알림 및 알림 설정',
                      onTap: () => context.push('/settings/fcm-test'),
                    ),
                    _buildMenuItem(
                      icon: Icons.help_outline,
                      title: '고객센터',
                      subtitle: '도움말 및 문의',
                      onTap: () {
                        // TODO: 고객센터 화면
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
            
            // 로그아웃
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: InkWell(
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          '로그아웃',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        content: const Text(
                          '정말 로그아웃 하시겠습니까?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text(
                              '취소',
                              style: TextStyle(
                                color: Color(0xFF666666),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              '로그아웃',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirmed == true) {
                      await authProvider.signOut();
                      if (mounted) {
                        context.go('/login');
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE0E0E0),
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        '로그아웃',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: const Color(0xFF666666),
                  size: 22,
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
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppColors.primary).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 11,
                              color: badgeColor ?? AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFCCCCCC),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDefaultAvatar(UserModel user) {
    return Container(
      color: _getTierColor(user.tier).withOpacity(0.1),
      child: Center(
        child: Text(
          user.nickname.isNotEmpty ? user.nickname[0] : '?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _getTierColor(user.tier),
          ),
        ),
      ),
    );
  }
  
  Color _getTierColor(PlayerTier tier) {
    switch (tier) {
      case PlayerTier.iron:
        return const Color(0xFF5C5C5C);
      case PlayerTier.bronze:
        return const Color(0xFF8B4513);
      case PlayerTier.silver:
        return const Color(0xFF808080);
      case PlayerTier.gold:
        return const Color(0xFFFFD700);
      case PlayerTier.platinum:
        return const Color(0xFF00CED1);
      case PlayerTier.emerald:
        return const Color(0xFF50C878);
      case PlayerTier.diamond:
        return const Color(0xFF00BFFF);
      case PlayerTier.master:
        return const Color(0xFF9370DB);
      case PlayerTier.grandmaster:
        return const Color(0xFFDC143C);
      case PlayerTier.challenger:
        return const Color(0xFFFFD700);
      case PlayerTier.unranked:
        return const Color(0xFF999999);
    }
  }
  
  String _getTierName(PlayerTier tier) {
    switch (tier) {
      case PlayerTier.iron:
        return '아이언';
      case PlayerTier.bronze:
        return '브론즈';
      case PlayerTier.silver:
        return '실버';
      case PlayerTier.gold:
        return '골드';
      case PlayerTier.platinum:
        return '플래티넘';
      case PlayerTier.emerald:
        return '에메랄드';
      case PlayerTier.diamond:
        return '다이아몬드';
      case PlayerTier.master:
        return '마스터';
      case PlayerTier.grandmaster:
        return '그랜드마스터';
      case PlayerTier.challenger:
        return '챌린저';
      case PlayerTier.unranked:
        return '언랭크';
    }
  }
}