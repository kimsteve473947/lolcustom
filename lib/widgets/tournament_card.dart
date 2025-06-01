import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
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
              const SizedBox(height: 16),
              _buildLocation(),
              const SizedBox(height: 16),
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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
        if (tournament.hostProfileImageUrl != null)
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(tournament.hostProfileImageUrl!),
          )
        else
          const CircleAvatar(
            radius: 18,
            child: Icon(Icons.person),
          ),
      ],
    );
  }

  Widget _buildLocation() {
    return Row(
      children: [
        const Icon(
          Icons.location_on,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            tournament.location,
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
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

  Widget _buildFooter() {
    return Row(
      children: [
        _buildSlotInfo(),
        const Spacer(),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildSlotInfo() {
    // Define role data
    final roles = [
      {'key': 'top', 'color': AppColors.roleTop},
      {'key': 'jungle', 'color': AppColors.roleJungle},
      {'key': 'mid', 'color': AppColors.roleMid},
      {'key': 'adc', 'color': AppColors.roleAdc},
      {'key': 'support', 'color': AppColors.roleSupport},
    ];

    return Row(
      children: roles.map((role) {
        final key = role['key'] as String;
        final color = role['color'] as Color;
        final filled = tournament.filledSlotsByRole[key] ?? 0;
        final total = tournament.slotsByRole[key] ?? 0;
        final isFull = filled >= total;

        return Container(
          margin: const EdgeInsets.only(right: 8),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isFull 
                ? color.withOpacity(0.3) 
                : color.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$filled/$total',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isFull ? AppColors.textSecondary : Colors.white,
              ),
            ),
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