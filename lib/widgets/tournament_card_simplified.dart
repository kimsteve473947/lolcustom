import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/widgets/lane_icon_widget.dart';

class TournamentCardSimplified extends StatelessWidget {
  final String title;
  final String? description;
  final String hostName;
  final String date;
  final String time;
  final String location;
  final String status;
  final Map<String, int> slots;
  final Map<String, int> filledSlots;
  final VoidCallback? onTap;
  final String? hostPosition;

  const TournamentCardSimplified({
    Key? key,
    required this.title,
    this.description,
    required this.hostName,
    required this.date,
    required this.time,
    required this.location,
    required this.status,
    required this.slots,
    required this.filledSlots,
    this.onTap,
    this.hostPosition,
  }) : super(key: key);
  
  // 토너먼트 모델에서 생성
  factory TournamentCardSimplified.fromTournament({
    required TournamentModel tournament,
    VoidCallback? onTap,
  }) {
    // 시작 시간 포맷팅
    final startsAtDate = tournament.startsAt.toDate();
    final dateFormatter = DateFormat('MM/dd (E)', 'ko_KR');
    final timeFormatter = DateFormat('HH:mm', 'ko_KR');
    
    return TournamentCardSimplified(
      title: tournament.title,
      description: tournament.description,
      hostName: tournament.hostName,
      date: dateFormatter.format(startsAtDate),
      time: timeFormatter.format(startsAtDate),
      location: tournament.location,
      status: tournament.status.toString().split('.').last,
      slots: tournament.slotsByRole,
      filledSlots: tournament.filledSlotsByRole,
      onTap: onTap,
      hostPosition: tournament.hostPosition,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  status == 'open'
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            '모집중',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            status == 'completed' ? '종료' : '진행중',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    hostName,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.schedule, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    location,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildPositionsBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPositionsBar() {
    // Ensure correct order: top, jungle, mid, adc, support
    final List<Map<String, String>> positions = [
      {'id': 'top', 'label': '탑'},
      {'id': 'jungle', 'label': '정글'},
      {'id': 'mid', 'label': '미드'},
      {'id': 'adc', 'label': '원딜'},
      {'id': 'support', 'label': '서포터'},
    ];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: positions.map((position) {
        return _buildPositionItem(position['id']!, position['label']!);
      }).toList(),
    );
  }

  Widget _buildPositionItem(String position, String label) {
    final total = slots[position] ?? 0;
    final filled = filledSlots[position] ?? 0;
    
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.grey.shade50,
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$filled/$total',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            if (hostPosition == position)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.amber,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.star,
                    size: 12,
                    color: Colors.amber,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LaneIconWidget(
              lane: position,
              size: 22,
              useRoleColor: true,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
} 