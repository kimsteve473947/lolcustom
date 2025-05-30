import 'package:flutter/material.dart';

class TournamentCardSimplified extends StatelessWidget {
  final String id;
  final String title;
  final String description;
  final String hostName;
  final String date;
  final String location;
  final bool isPaid;
  final int? price;
  final Map<String, int> slots;
  final Map<String, int> filledSlots;
  final VoidCallback? onTap;

  const TournamentCardSimplified({
    Key? key,
    required this.id,
    required this.title,
    required this.description,
    required this.hostName,
    required this.date,
    required this.location,
    this.isPaid = false,
    this.price,
    required this.slots,
    required this.filledSlots,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
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
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.person, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hostName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          date,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isPaid && price != null)
                Row(
                  children: [
                    const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '참가비: ${price}원',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildRoleStatus('top', filledSlots['top'] ?? 0, slots['top'] ?? 0, Colors.red),
                  _buildRoleStatus('jg', filledSlots['jungle'] ?? 0, slots['jungle'] ?? 0, Colors.green),
                  _buildRoleStatus('mid', filledSlots['mid'] ?? 0, slots['mid'] ?? 0, Colors.blue),
                  _buildRoleStatus('adc', filledSlots['adc'] ?? 0, slots['adc'] ?? 0, Colors.orange),
                  _buildRoleStatus('sup', filledSlots['support'] ?? 0, slots['support'] ?? 0, Colors.purple),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              Text(
                '총 참가자: ${_getTotalFilledSlots()}/${_getTotalSlots()}명',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleStatus(String role, int filled, int total, Color color) {
    final double percentage = total > 0 ? filled / total : 0;
    
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              role,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$filled/$total',
          style: TextStyle(
            fontSize: 12,
            color: filled >= total ? Colors.green : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  int _getTotalSlots() {
    int total = 0;
    slots.forEach((_, count) => total += count);
    return total;
  }

  int _getTotalFilledSlots() {
    int total = 0;
    filledSlots.forEach((_, count) => total += count);
    return total;
  }
} 