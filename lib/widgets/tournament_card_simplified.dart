import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';

class TournamentCardSimplified extends StatelessWidget {
  final String id;
  final String title;
  final String? description;
  final String hostName;
  final String date;
  final String location;
  final bool isPaid;
  final int? price;
  final Map<String, int> slots;
  final Map<String, int> filledSlots;
  final VoidCallback onTap;

  const TournamentCardSimplified({
    Key? key,
    required this.id,
    required this.title,
    this.description,
    required this.hostName,
    required this.date,
    required this.location,
    required this.isPaid,
    this.price,
    required this.slots,
    required this.filledSlots,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  isPaid
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '유료 ${price != null ? '₩${price}' : ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '무료',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildPositionItem('top', '탑'),
        _buildPositionItem('jungle', '정글'),
        _buildPositionItem('mid', '미드'),
        _buildPositionItem('adc', '원딜'),
        _buildPositionItem('support', '서포터'),
      ],
    );
  }

  Widget _buildPositionItem(String position, String label) {
    final total = slots[position] ?? 0;
    final filled = filledSlots[position] ?? 0;
    final isEmpty = filled < total;
    
    Color getColor() {
      switch (position) {
        case 'top':
          return AppColors.top;
        case 'jungle':
          return AppColors.jungle;
        case 'mid':
          return AppColors.mid;
        case 'adc':
          return AppColors.adc;
        case 'support':
          return AppColors.support;
        default:
          return Colors.grey;
      }
    }

    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isEmpty ? getColor().withOpacity(0.2) : getColor(),
            shape: BoxShape.circle,
            border: Border.all(
              color: getColor(),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '$filled/$total',
              style: TextStyle(
                color: isEmpty ? getColor() : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
} 