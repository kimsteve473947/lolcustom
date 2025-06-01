import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';

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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('M월 d일 (E) HH:mm', 'ko_KR').format(tournament.startsAt.toDate()),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
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
        _buildHostInfo(),
      ],
    );
  }
  
  Widget _buildHostInfo() {
    return Row(
      children: [
        if (tournament.premiumBadge)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              Icons.verified,
              size: 18,
              color: Colors.amber.shade600,
            ),
          ),
        if (tournament.hostProfileImageUrl != null)
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(tournament.hostProfileImageUrl!),
          )
        else
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: Text(
              tournament.hostNickname?.substring(0, 1).toUpperCase() ?? 'H',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
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
        final isFull = filled >= total;

        return Container(
          margin: const EdgeInsets.only(right: 8),
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isFull ? Colors.grey.shade200 : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isFull ? Colors.grey.shade400 : AppColors.primary,
                    width: 1,
                  ),
                ),
                child: Image.asset(
                  LolLaneIcons.paths[lane] ?? 'assets/images/lane_top.png', 
                  color: isFull ? Colors.grey.shade400 : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$filled/$total',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isFull ? Colors.grey.shade600 : AppColors.primary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
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