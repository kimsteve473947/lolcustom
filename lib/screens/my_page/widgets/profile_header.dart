import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/widgets/trust_score_widget.dart';
import 'package:lol_custom_game_manager/widgets/host_trust_score_widget.dart';

class ProfileHeader extends StatefulWidget {
  final UserModel user;

  const ProfileHeader({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                    AppColors.primary.withOpacity(0.6),
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, // 콘텐츠 크기에 맞게 높이 조절
                    children: [
                      // Main Profile Section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Image with Level Badge
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 37,
                                  backgroundColor: Colors.white24,
                                  backgroundImage: widget.user.profileImageUrl.isNotEmpty
                                      ? NetworkImage(widget.user.profileImageUrl)
                                      : null,
                                  child: widget.user.profileImageUrl.isEmpty
                                      ? const Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                              // Level Badge
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.amber, Colors.amber.shade600],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${_calculateLevel()}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          
                          // User Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.user.nickname,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: _getTierColor(widget.user.tier),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            UserModel.tierToString(widget.user.tier),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (widget.user.statusMessage != null && widget.user.statusMessage!.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      widget.user.statusMessage!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.95),
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                Text(
                                  widget.user.email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Trust Score Section - Simplified Horizontal Layout
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header
                            Row(
                              children: [
                                Icon(
                                  Icons.shield,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  '신뢰도 점수',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '평가율 ${(widget.user.evaluationRate * 100).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Horizontal Score Layout
                            Row(
                              children: [
                                // Host Score
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => TrustScoreDetailDialog(
                                          hostScore: widget.user.hostScore,
                                          playerScore: widget.user.playerScore,
                                          evaluationRate: widget.user.evaluationRate,
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.primary.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.star,
                                                size: 16,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '주최자',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${widget.user.hostScore.toInt()}',
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: _getScoreColor(widget.user.hostScore),
                                            ),
                                          ),
                                          Text(
                                            _getScoreText(widget.user.hostScore),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _getScoreColor(widget.user.hostScore),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Player Score
                                Expanded(
                                  child: InkWell(
                                    onTap: () => context.go('/mypage/participant-trust'),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.blue.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.groups,
                                                size: 16,
                                                color: Colors.blue,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '참가자',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${widget.user.playerScore.toInt()}',
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: _getScoreColor(widget.user.playerScore),
                                            ),
                                          ),
                                          Text(
                                            _getScoreText(widget.user.playerScore),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _getScoreColor(widget.user.playerScore),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Stats Container
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            // Credits and Level Progress
                            Row(
                              children: [
                                // Credits (클릭 가능)
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => context.go('/mypage/credit-charge'),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withOpacity(0.3),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                Icons.monetization_on,
                                                color: Colors.amber[200],
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              '보유 크레딧',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${NumberFormat.decimalPattern().format(widget.user.credits)} C',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                Container(
                                  width: 1,
                                  height: 50,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                
                                // Level Progress
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.purple.withOpacity(0.3),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                Icons.trending_up,
                                                color: Colors.purple[200],
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '레벨 ${_calculateLevel()}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${widget.user.credits}/1000 EXP',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                          value: (widget.user.credits % 1000) / 1000,
                                          backgroundColor: Colors.white.withOpacity(0.3),
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[300]!),
                                          minHeight: 4,
                                        ),
                                      ],
                                    ),
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
              ),
            ),
          ),
        );
      },
    );
  }

  int _calculateLevel() {
    final credits = widget.user.credits;
    if (credits < 1000) return 1;
    if (credits < 2500) return 2;
    if (credits < 5000) return 3;
    if (credits < 10000) return 4;
    if (credits < 20000) return 5;
    if (credits < 35000) return 6;
    if (credits < 50000) return 7;
    if (credits < 75000) return 8;
    if (credits < 100000) return 9;
    return 10;
  }

  Color _getTierColor(PlayerTier tier) {
    switch (tier) {
      case PlayerTier.iron:
        return Colors.grey[600]!;
      case PlayerTier.bronze:
        return Colors.brown[400]!;
      case PlayerTier.silver:
        return Colors.blueGrey[400]!;
      case PlayerTier.gold:
        return Colors.amber[700]!;
      case PlayerTier.platinum:
        return Colors.teal[400]!;
      case PlayerTier.emerald:
        return Colors.green[500]!;
      case PlayerTier.diamond:
        return Colors.lightBlue[400]!;
      case PlayerTier.master:
        return Colors.purple[400]!;
      case PlayerTier.grandmaster:
        return Colors.red[500]!;
      case PlayerTier.challenger:
        return Colors.orange[400]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return const Color(0xFF4CAF50);
    if (score >= 70) return const Color(0xFFFFC107);
    if (score >= 50) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String _getScoreText(double score) {
    if (score >= 90) return '우수';
    if (score >= 70) return '양호';
    if (score >= 50) return '주의';
    return '위험';
  }
}