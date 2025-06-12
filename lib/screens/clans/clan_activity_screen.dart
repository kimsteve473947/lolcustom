import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/clan_creation_provider.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';

class ClanActivityScreen extends StatefulWidget {
  const ClanActivityScreen({Key? key}) : super(key: key);

  @override
  State<ClanActivityScreen> createState() => _ClanActivityScreenState();
}

class _ClanActivityScreenState extends State<ClanActivityScreen> {
  final Map<String, String> _dayLabels = {
    '월': '월',
    '화': '화',
    '수': '수',
    '목': '목',
    '금': '금',
    '토': '토',
    '일': '일',
  };
  
  final Map<PlayTimeType, String> _timeLabels = {
    PlayTimeType.morning: '아침\n6-10시',
    PlayTimeType.daytime: '낮\n10-18시',
    PlayTimeType.evening: '저녁\n18-24시',
    PlayTimeType.night: '심야\n24-6시',
  };

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ClanCreationProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            provider.previousStep();
            context.pop();
          },
        ),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon and team name
                  Row(
                    children: [
                      // Show team icon if available
                      if (provider.hasEmblem)
                        Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: _buildEmblemPreview(provider),
                        ),
                      Text(
                        provider.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    '주로 언제 운동하나요?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '정확하지 않아도 괜찮아요. 자주 차는 시간과 요일을 알려주세요.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Activity days
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '활동 요일',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (provider.activityDays.isEmpty)
                        Text(
                          '최소 1개 이상 선택해주세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[700],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Day selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _dayLabels.entries.map((entry) {
                      final day = entry.key;
                      final label = entry.value;
                      final isSelected = provider.activityDays.contains(day);
                      
                      return GestureDetector(
                        onTap: () => provider.toggleActivityDay(day),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Activity times
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '활동 시간대',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (provider.activityTimes.isEmpty)
                        Text(
                          '최소 1개 이상 선택해주세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[700],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Time selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _timeLabels.entries.map((entry) {
                      final time = entry.key;
                      final label = entry.value;
                      final isSelected = provider.activityTimes.contains(time);
                      
                      return GestureDetector(
                        onTap: () => provider.toggleActivityTime(time),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          
          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      provider.previousStep();
                      context.pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '뒤로',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canProceed() ? _proceedToNext : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '다음',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  bool _canProceed() {
    final provider = Provider.of<ClanCreationProvider>(context, listen: false);
    return provider.activityDays.isNotEmpty && provider.activityTimes.isNotEmpty;
  }
  
  void _proceedToNext() {
    final provider = Provider.of<ClanCreationProvider>(context, listen: false);
    
    // 활동 요일과 시간대가 모두 선택되었는지 확인
    if (provider.activityDays.isEmpty || provider.activityTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('활동 요일과 시간대를 모두 선택해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    provider.nextStep();
    
    // 명확한 이동 경로 지정
    context.push('/clans/preferences');
  }
  
  Widget _buildEmblemPreview(ClanCreationProvider provider) {
    if (provider.emblem is Map) {
      // Get frame properties if available
      BoxShape shape = BoxShape.circle;
      BorderRadius? borderRadius;
      
      final emblem = provider.emblem as Map;
      if (emblem.containsKey('frame')) {
        final String frameType = emblem['frame'];
        switch (frameType) {
          case 'circle':
            shape = BoxShape.circle;
            break;
          case 'rounded_square':
            shape = BoxShape.rectangle;
            borderRadius = BorderRadius.circular(8);
            break;
          case 'shield':
            shape = BoxShape.rectangle;
            borderRadius = BorderRadius.vertical(top: Radius.circular(10), bottom: Radius.circular(5));
            break;
          default:
            shape = BoxShape.circle;
        }
      }
      
      return Container(
        decoration: BoxDecoration(
          color: emblem['backgroundColor'],
          shape: shape,
          borderRadius: borderRadius,
        ),
        child: Center(
          child: Icon(
            _getIconData(emblem['symbol']),
            size: 20,
            color: _getIconColor(emblem['symbol']),
          ),
        ),
      );
    }
    
    return const Icon(
      Icons.group,
      size: 20,
      color: AppColors.primary,
    );
  }
  
  IconData _getIconData(String? symbol) {
    if (symbol == null) return Icons.group;
    
    final Map<String, IconData> iconMap = {
      'shield': Icons.shield,
      'star': Icons.star,
      'sports_soccer': Icons.sports_soccer,
      'sports_basketball': Icons.sports_basketball,
      'sports_baseball': Icons.sports_baseball,
      'sports_football': Icons.sports_football,
      'sports_volleyball': Icons.sports_volleyball,
      'sports_tennis': Icons.sports_tennis,
      'whatshot': Icons.whatshot,
      'bolt': Icons.bolt,
      'pets': Icons.pets,
      'favorite': Icons.favorite,
      'stars': Icons.stars,
      'military_tech': Icons.military_tech,
      'emoji_events': Icons.emoji_events,
      'local_fire_department': Icons.local_fire_department,
      'public': Icons.public,
      'cruelty_free': Icons.cruelty_free,
      'emoji_nature': Icons.emoji_nature,
      'rocket_launch': Icons.rocket_launch,
    };
    
    return iconMap[symbol] ?? Icons.group;
  }
  
  Color _getIconColor(String? symbol) {
    if (symbol == null) return Colors.white;
    
    final Map<String, Color> colorMap = {
      'shield': Colors.grey.shade800,
      'star': Colors.amber,
      'sports_soccer': Colors.black,
      'sports_basketball': Colors.orange.shade800,
      'sports_baseball': Colors.red.shade700,
      'sports_football': Colors.brown.shade700,
      'sports_volleyball': Colors.yellow.shade700,
      'sports_tennis': Colors.green.shade700,
      'whatshot': Colors.orange.shade700,
      'bolt': Colors.yellow,
      'pets': Colors.brown.shade800,
      'favorite': Colors.red,
      'stars': Colors.amber,
      'military_tech': Colors.amber.shade800,
      'emoji_events': Colors.amber.shade700,
      'local_fire_department': Colors.red.shade700,
      'public': Colors.blue.shade700,
      'cruelty_free': Colors.purple.shade700,
      'emoji_nature': Colors.green.shade700,
      'rocket_launch': Colors.blue.shade800,
    };
    
    return colorMap[symbol] ?? Colors.white;
  }
} 