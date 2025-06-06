import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';

class LaneIconWidget extends StatelessWidget {
  final String lane;
  final double size;
  final Color? color;
  final bool showLabel;
  final double labelFontSize;
  final bool? useRoleColor;

  const LaneIconWidget({
    Key? key,
    required this.lane,
    this.size = 24,
    this.color,
    this.showLabel = false,
    this.labelFontSize = 12,
    this.useRoleColor,
  }) : super(key: key);

  Color _getRoleColor() {
    if (useRoleColor == false) return Colors.white;
    
    switch (lane.toLowerCase()) {
      case 'top': return const Color(0xFFE74C3C);
      case 'jungle': return const Color(0xFF27AE60);
      case 'mid': return const Color(0xFF3498DB);
      case 'adc': return const Color(0xFFF39C12);
      case 'support': return const Color(0xFF9B59B6);
      default: return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Image.asset(
                _getLaneImagePath(),
                fit: BoxFit.contain,
                width: size * 0.8,
                height: size * 0.8,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            _getLaneName(),
            style: TextStyle(
              fontSize: labelFontSize,
              fontWeight: FontWeight.w600,
              color: _getRoleColor(),
            ),
          ),
        ],
      ],
    );
  }

  String _getLaneImagePath() {
    switch (lane.toLowerCase()) {
      case 'top':
        return LolLaneIcons.top;
      case 'jungle':
        return LolLaneIcons.jungle;
      case 'mid':
        return LolLaneIcons.mid;
      case 'adc':
        return LolLaneIcons.adc;
      case 'support':
        return LolLaneIcons.support;
      default:
        return LolLaneIcons.top;
    }
  }

  String _getLaneName() {
    switch (lane.toLowerCase()) {
      case 'top':
        return '탑';
      case 'jungle':
        return '정글';
      case 'mid':
        return '미드';
      case 'adc':
        return '원딜';
      case 'support':
        return '서포터';
      default:
        return lane;
    }
  }
} 