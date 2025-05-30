import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';

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
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildLocationAndTime(),
              const SizedBox(height: 16),
              _buildRoles(),
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
        if (tournament.premiumBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'PREMIUM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const Spacer(),
        if (tournament.isFull)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '마감',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (tournament.isPaid)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tournament.isPaid ? AppColors.warning : Colors.green,
              borderRadius: BorderRadius.circular(4),
            ),
            margin: const EdgeInsets.only(left: 8),
            child: Text(
              tournament.isPaid ? '참가비 ${NumberFormat('#,###').format(tournament.price ?? 0)}원' : '무료',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationAndTime() {
    // Format date and time
    final dateTime = tournament.startsAt.toDate();
    final date = DateFormat('M월 d일 (E)', 'ko_KR').format(dateTime);
    final time = DateFormat('HH:mm').format(dateTime);
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$date $time',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tournament.location,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (tournament.distance != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${tournament.distance!.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRoles() {
    // Define role data
    final roles = [
      {'name': 'Top', 'icon': Icons.arrow_upward, 'color': AppColors.roleTop, 'key': 'top'},
      {'name': 'Jungle', 'icon': Icons.nature_people, 'color': AppColors.roleJungle, 'key': 'jungle'},
      {'name': 'Mid', 'icon': Icons.adjust, 'color': AppColors.roleMid, 'key': 'mid'},
      {'name': 'ADC', 'icon': Icons.gps_fixed, 'color': AppColors.roleAdc, 'key': 'adc'},
      {'name': 'Support', 'icon': Icons.shield, 'color': AppColors.roleSupport, 'key': 'support'},
    ];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: roles.map((role) {
        final key = role['key'] as String;
        final filled = tournament.filledSlotsByRole[key] ?? 0;
        final total = tournament.slotsByRole[key] ?? 2;
        final isFull = filled >= total;
        
        return Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (role['color'] as Color).withOpacity(isFull ? 0.3 : 1.0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                role['icon'] as IconData,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${role['name']}',
              style: TextStyle(
                fontSize: 10,
                color: isFull ? AppColors.textDisabled : AppColors.textPrimary,
              ),
            ),
            Text(
              '$filled/$total',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isFull ? AppColors.textDisabled : AppColors.textPrimary,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: tournament.hostProfileImageUrl != null
              ? NetworkImage(tournament.hostProfileImageUrl!)
              : null,
          child: tournament.hostProfileImageUrl == null
              ? const Icon(Icons.person, size: 16)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          tournament.hostNickname,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (tournament.ovrLimit != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'OVR ${tournament.ovrLimit}+',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
} 