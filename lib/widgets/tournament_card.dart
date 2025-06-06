import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/widgets/lane_icon_widget.dart';

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
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildGameInfo(),
              const SizedBox(height: 12),
              _buildDivider(),
              const SizedBox(height: 12),
              _buildFooter(),
            ],
          ),
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
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 더 큰 시간 표시
              Text(
                DateFormat('M월 d일 (E) HH:mm', 'ko_KR').format(tournament.startsAt.toDate()),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tournament.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // 티어 아이콘 표시
        if (tierIconPaths.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: tierIconPaths.map((path) => 
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '랜덤',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
          )
        else if (tournament.premiumBadge)
          Icon(
            Icons.verified,
            size: 24,
            color: Colors.amber.shade600,
          ),
      ],
    );
  }

  Widget _buildGameInfo() {
    return Row(
      children: [
        // 게임 서버 정보
        Expanded(
          child: Row(
            children: [
              const Icon(
                Icons.public,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                LolGameServers.names[tournament.gameServer] ?? '한국 서버',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        
        // 경기 방식 정보
        Expanded(
          child: Row(
            children: [
              const Icon(
                Icons.format_list_numbered,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                LolGameFormats.names[tournament.gameFormat] ?? '단판',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        
        // 참가비 정보
        if (tournament.isPaid)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${NumberFormat('#,###').format(tournament.price ?? 0)}원',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        _buildLaneInfo(),
        const Spacer(),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildLaneInfo() {
    // Define lane data
    final lanes = [
      LolLane.top,
      LolLane.jungle, 
      LolLane.mid, 
      LolLane.adc, 
      LolLane.support
    ];

    return Row(
      children: lanes.map((lane) {
        final key = lane.toString().split('.').last;
        final filled = tournament.filledSlotsByRole[key] ?? 0;
        final total = tournament.slotsByRole[key] ?? 2;

        return Container(
          margin: const EdgeInsets.only(right: 8),
          child: Column(
            children: [
              LaneIconWidget(
                lane: key,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                '$filled/$total',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getParticipantCountColor(filled, total),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 참가자 수에 따른 색상 변경
  Color _getParticipantCountColor(int filled, int total) {
    if (filled == 0) return Colors.black;  // 0/2: 검정색
    if (filled < total) return Colors.amber.shade700;  // 1/2: 노란색
    return Colors.red;  // 2/2: 빨간색
  }

  Widget _buildStatusBadge() {
    Color color;
    String text;

    switch (tournament.status) {
      case TournamentStatus.draft:
        color = Colors.grey;
        text = '초안';
        break;
      case TournamentStatus.open:
        color = AppColors.success;
        text = '모집중';
        break;
      case TournamentStatus.full:
        color = AppColors.primary;
        text = '모집완료';
        break;
      case TournamentStatus.inProgress:
      case TournamentStatus.ongoing:
        color = AppColors.warning;
        text = '진행중';
        break;
      case TournamentStatus.completed:
        color = AppColors.textSecondary;
        text = '완료';
        break;
      case TournamentStatus.cancelled:
        color = AppColors.error;
        text = '취소됨';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
} 