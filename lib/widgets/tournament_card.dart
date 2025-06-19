import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/widgets/lane_icon_widget.dart';
import 'package:lol_custom_game_manager/widgets/host_trust_score_widget.dart';

class TournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  final VoidCallback? onTap;

  const TournamentCard({
    Key? key,
    required this.tournament,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // 상단 헤더 섹션
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildHostInfo(),
                  const SizedBox(height: 12),
                  _buildGameInfo(),
                ],
              ),
            ),
            // 하단 포지션 정보 섹션
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundGrey,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: _buildPositionInfo(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // 대회 이름에서 티어 정보 추출
    List<String> tierIconPaths = [];
    
    // 티어 확인 함수
    void checkAndAddTier(String tierName, String iconPath) {
      if (tournament.title.toLowerCase().contains(tierName)) {
        tierIconPaths.add(iconPath);
      }
    }
    
    // 각 티어 확인
    checkAndAddTier('플레티넘', 'assets/images/tiers/플레티넘로고.png');
    checkAndAddTier('플래티넘', 'assets/images/tiers/플레티넘로고.png');
    checkAndAddTier('다이아', 'assets/images/tiers/다이아로고.png');
    checkAndAddTier('골드', 'assets/images/tiers/골드로고.png');
    checkAndAddTier('실버', 'assets/images/tiers/실버로고.png');
    checkAndAddTier('브론즈', 'assets/images/tiers/브론즈로고.png');
    checkAndAddTier('아이언', 'assets/images/tiers/아이언로고.png');
    checkAndAddTier('에메랄드', 'assets/images/tiers/에메랄드로고.png');
    checkAndAddTier('마스터', 'assets/images/tiers/마스터로고.png');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목과 배지
        Row(
          children: [
            Expanded(
              child: Text(
                tournament.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // 티어 아이콘 또는 배지
            if (tierIconPaths.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: tierIconPaths.take(2).map((path) => 
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Image.asset(
                      path,
                      width: 24,
                      height: 24,
                    ),
                  )
                ).toList(),
              )
            else if (tournament.title.toLowerCase().contains('랜덤'))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '🎲 랜덤',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B47DC),
                  ),
                ),
              )
            else if (tournament.premiumBadge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '⭐ 프리미엄',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF9500),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // 시간 정보
        Row(
          children: [
            Icon(
              Icons.access_time,
              size: 16,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              DateFormat('M월 d일 (E) HH:mm', 'ko_KR').format(tournament.startsAt.toDate()),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            _buildStatusBadge(),
          ],
        ),
      ],
    );
  }

  Widget _buildHostInfo() {
    return Row(
      children: [
        // 주최자 프로필 이미지
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.backgroundGrey,
            image: tournament.hostProfileImageUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(tournament.hostProfileImageUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: tournament.hostProfileImageUrl.isEmpty
              ? Icon(
                  Icons.person,
                  size: 20,
                  color: AppColors.textTertiary,
                )
              : null,
        ),
        const SizedBox(width: 8),
        // 주최자 이름
        Expanded(
          child: Text(
            tournament.hostName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        // 운영 신뢰도
        HostTrustScoreLoader(
          hostId: tournament.hostId,
          isCompact: true,
          showDetails: true,
        ),
      ],
    );
  }

  Widget _buildGameInfo() {
    return Row(
      children: [
        // 게임 서버
        _buildInfoChip(
          icon: Icons.public,
          text: LolGameServers.names[tournament.gameServer] ?? '한국 서버',
        ),
        const SizedBox(width: 8),
        // 경기 방식
        _buildInfoChip(
          icon: Icons.sports_esports,
          text: LolGameFormats.names[tournament.gameFormat] ?? '단판',
        ),
        const Spacer(),
        // 참가비 정보
        if (tournament.isPaid)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warning.withOpacity(0.9),
                  AppColors.warning,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.attach_money,
                  size: 16,
                  color: Colors.white,
                ),
                Text(
                  NumberFormat('#,###').format(tournament.price ?? 0),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionInfo() {
    final lanes = [
      LolLane.top,
      LolLane.jungle, 
      LolLane.mid, 
      LolLane.adc, 
      LolLane.support
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: lanes.map((lane) {
        final key = lane.toString().split('.').last;
        final filled = tournament.filledSlotsByRole[key] ?? 0;
        final total = tournament.slotsByRole[key] ?? 2;
        final isFull = filled >= total;

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isFull 
                  ? AppColors.error.withOpacity(0.1)
                  : AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFull 
                    ? AppColors.error.withOpacity(0.3)
                    : AppColors.border,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                LaneIconWidget(
                  lane: key,
                  size: 24,
                  color: isFull ? AppColors.error : null,
                ),
                const SizedBox(height: 4),
                Text(
                  '$filled/$total',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isFull 
                        ? AppColors.error
                        : filled > 0 
                            ? AppColors.warning
                            : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusBadge() {
    Color backgroundColor;
    Color textColor;
    String text;
    IconData? icon;

    switch (tournament.status) {
      case TournamentStatus.draft:
        backgroundColor = AppColors.textDisabled.withOpacity(0.1);
        textColor = AppColors.textSecondary;
        text = '초안';
        icon = Icons.edit_outlined;
        break;
      case TournamentStatus.open:
        backgroundColor = AppColors.success.withOpacity(0.1);
        textColor = AppColors.success;
        text = '모집중';
        icon = Icons.group_add;
        break;
      case TournamentStatus.full:
        backgroundColor = AppColors.primary.withOpacity(0.1);
        textColor = AppColors.primary;
        text = '모집완료';
        icon = Icons.check_circle_outline;
        break;
      case TournamentStatus.inProgress:
      case TournamentStatus.ongoing:
        backgroundColor = AppColors.warning.withOpacity(0.1);
        textColor = AppColors.warning;
        text = '진행중';
        icon = Icons.play_circle_outline;
        break;
      case TournamentStatus.completed:
        backgroundColor = AppColors.textDisabled.withOpacity(0.1);
        textColor = AppColors.textSecondary;
        text = '완료';
        icon = Icons.done_all;
        break;
      case TournamentStatus.cancelled:
        backgroundColor = AppColors.error.withOpacity(0.1);
        textColor = AppColors.error;
        text = '취소됨';
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: textColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
} 