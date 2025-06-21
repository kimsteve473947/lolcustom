import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:lol_custom_game_manager/widgets/clan_emblem_widget.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:go_router/go_router.dart';

class ClanPublicProfileScreen extends StatefulWidget {
  final String clanId;

  const ClanPublicProfileScreen({Key? key, required this.clanId}) : super(key: key);

  @override
  _ClanPublicProfileScreenState createState() => _ClanPublicProfileScreenState();
}

class _ClanPublicProfileScreenState extends State<ClanPublicProfileScreen> {
  final ClanService _clanService = ClanService();
  late Future<ClanModel?> _clanFuture;
  String _averageTier = 'Unranked';
  bool _isLoading = false;
  bool _hasApplied = false;

  @override
  void initState() {
    super.initState();
    _clanFuture = _clanService.getClan(widget.clanId);
    _fetchAverageTier();
    _checkApplicationStatus();
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
          _averageTier = 'Unranked';
        });
      }
    }
  }

  Future<void> _checkApplicationStatus() async {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      try {
        final hasApplied = await _clanService.hasUserAppliedToClan(widget.clanId, user.uid);
        if (mounted) {
          setState(() {
            _hasApplied = hasApplied;
          });
        }
      } catch (e) {
        debugPrint('Error checking application status: $e');
      }
    }
  }

  void _applyToClan(ClanModel clan) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      _showSnackBar('로그인이 필요합니다', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _clanService.applyClanWithDetails(clanId: clan.id, message: "클랜 가입을 신청합니다!");
      
      if (mounted) {
        setState(() {
          _hasApplied = true;
        });
        _showSnackBar('클랜 가입 신청이 완료되었습니다', isError: false);
      }
    } catch (e) {
      _showSnackBar('가입 신청 중 오류가 발생했습니다', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _cancelClanApplication(ClanModel clan) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      _showSnackBar('로그인이 필요합니다', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _clanService.cancelClanApplicationByUser(widget.clanId, user.uid);
      
      if (mounted) {
        setState(() {
          _hasApplied = false;
        });
        _showSnackBar('클랜 가입 신청이 취소되었습니다', isError: false);
      }
    } catch (e) {
      _showSnackBar('가입 신청 취소 중 오류가 발생했습니다', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/clans');
            }
          },
        ),
        title: Text(
          '클랜 정보',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<ClanModel?>(
        future: _clanFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return _buildErrorState();
          }

          final clan = snapshot.data!;
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final isMember = clan.members.contains(authProvider.user?.uid);

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 120.0),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
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
              if (!isMember) _buildBottomButton(clan),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '클랜 정보를 불러올 수 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '네트워크 상태를 확인해주세요',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ClanModel clan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ClanEmblemWidget(emblemData: clan.emblem, size: 88),
          const SizedBox(height: 20),
          Text(
            clan.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '레벨 ${clan.level} | 멤버 ${clan.memberCount}/${clan.maxMembers}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(ClanModel clan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '클랜 소개',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            clan.description ?? '클랜 설명이 없습니다.',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceCard(ClanModel clan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '클랜 성향',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            Icons.shield_outlined,
            '평균 티어',
            _averageTier,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.wc_outlined,
            '선호 성별',
            _genderPreferenceToString(clan.genderPreference),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.people_outline,
            '선호 연령대',
            clan.ageGroups.isNotEmpty
                ? clan.ageGroups.map(_ageGroupToString).join(', ')
                : '모든 연령',
          ),
          const SizedBox(height: 20),
          _buildFocusRatingBar(clan.focusRating),
        ],
      ),
    );
  }

  Widget _buildActivityCard(ClanModel clan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '활동 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            '활동 요일',
            clan.activityDays.isNotEmpty ? clan.activityDays.join(', ') : '수, 일, 목, 금, 화, 월, 토',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.access_time_outlined,
            '활동 시간',
            clan.activityTimes.isNotEmpty
                ? clan.activityTimes.map(_playTimeToString).join(', ')
                : '낮, 저녁, 심야',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 18,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
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

  Widget _buildFocusRatingBar(int rating) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.balance,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '진력',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rating >= 7 ? '실력' : rating >= 4 ? '밸런스' : '친목',
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
        ),
        const SizedBox(height: 16),
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
                    colors: [Color(0xFF3B82F6), Color(0xFFEF4444)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Positioned(
                left: (rating / 10.0) * MediaQuery.of(context).size.width * 0.7,
                child: Container(
                  width: 16,
                  height: 16,
                  transform: Matrix4.translationValues(-8, -4, 0),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowLight,
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

  Widget _buildBottomButton(ClanModel clan) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: _hasApplied 
              ? _buildApplicationPendingWidget(clan)
              : _buildApplicationButton(clan),
        ),
      ),
    );
  }

  Widget _buildApplicationButton(ClanModel clan) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _applyToClan(clan),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          disabledBackgroundColor: AppColors.textTertiary,
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                '가입 신청하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildApplicationPendingWidget(ClanModel clan) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 가입 신청 중 상태 카드
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.warning.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.hourglass_empty,
                color: AppColors.warning,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '가입 신청 중',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '클랜장의 승인을 기다리고 있습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 취소 버튼
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => _showCancelApplicationDialog(clan),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
                    ),
                  )
                : Text(
                    '가입 신청 취소',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _showCancelApplicationDialog(ClanModel clan) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '가입 신청 취소',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Text(
            '클랜 가입 신청을 취소하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '아니요',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _cancelClanApplication(clan);
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
        );
      },
    );
  }

  String _playTimeToString(PlayTimeType type) {
    switch (type) {
      case PlayTimeType.morning:
        return '아침';
      case PlayTimeType.daytime:
        return '낮';
      case PlayTimeType.evening:
        return '저녁';
      case PlayTimeType.night:
        return '심야';
      default:
        return '';
    }
  }

  String _ageGroupToString(AgeGroup group) {
    switch (group) {
      case AgeGroup.teens:
        return '10대';
      case AgeGroup.twenties:
        return '20대';
      case AgeGroup.thirties:
        return '30대';
      case AgeGroup.fortyPlus:
        return '40대 이상';
      default:
        return '';
    }
  }

  String _genderPreferenceToString(GenderPreference preference) {
    switch (preference) {
      case GenderPreference.male:
        return '남성';
      case GenderPreference.female:
        return '여성';
      case GenderPreference.any:
        return '남녀 모두';
      default:
        return '';
    }
  }
}