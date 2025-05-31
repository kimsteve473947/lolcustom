import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';

class TournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  final Function()? onTap;

  const TournamentCard({
    Key? key,
    required this.tournament,
    this.onTap,
  }) : super(key: key);

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: tournament.hostProfileImageUrl != null
                        ? NetworkImage(tournament.hostProfileImageUrl!)
                        : null,
                    radius: 20,
                    child: tournament.hostProfileImageUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament.hostNickname ?? tournament.hostName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _formatDate(tournament.startsAt),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (tournament.premiumBadge)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PREMIUM',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
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
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              if (tournament.distance != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.directions,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${tournament.distance!.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildRoleChip('TOP', tournament.slotsByRole['top'] ?? 0,
                      tournament.filledSlotsByRole['top'] ?? 0, AppColors.roleTop),
                  const SizedBox(width: 8),
                  _buildRoleChip('JG', tournament.slotsByRole['jungle'] ?? 0,
                      tournament.filledSlotsByRole['jungle'] ?? 0, AppColors.roleJungle),
                  const SizedBox(width: 8),
                  _buildRoleChip('MID', tournament.slotsByRole['mid'] ?? 0,
                      tournament.filledSlotsByRole['mid'] ?? 0, AppColors.roleMid),
                  const SizedBox(width: 8),
                  _buildRoleChip('ADC', tournament.slotsByRole['adc'] ?? 0,
                      tournament.filledSlotsByRole['adc'] ?? 0, AppColors.roleAdc),
                  const SizedBox(width: 8),
                  _buildRoleChip('SUP', tournament.slotsByRole['support'] ?? 0,
                      tournament.filledSlotsByRole['support'] ?? 0, AppColors.roleSupport),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (tournament.isPaid && tournament.price != null)
                    Text(
                      '참가비: ${tournament.price}원',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  else
                    const Text(
                      '무료 참가',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green,
                      ),
                    ),
                  if (tournament.ovrLimit != null)
                    Text(
                      '평점 제한: ${tournament.ovrLimit}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String label, int total, int filled, Color color) {
    final isFull = filled >= total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isFull ? Colors.grey.shade300 : color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isFull ? Colors.grey : color),
      ),
      child: Text(
        '$label $filled/$total',
        style: TextStyle(
          color: isFull ? Colors.grey : color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
} 