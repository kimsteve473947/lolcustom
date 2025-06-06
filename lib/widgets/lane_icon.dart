import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';

/// LoL 라인 아이콘을 표시하는 위젯
/// 앱 전체에서 일관된 디자인으로 라인 아이콘을 표시하기 위해 사용
class LaneIcon extends StatelessWidget {
  /// 라인 식별자 (top, jungle, mid, adc, support)
  final String lane;
  
  /// 아이콘 크기 (기본값: 24)
  final double size;
  
  /// 배경 표시 여부 (기본값: true)
  final bool showBackground;
  
  /// 테두리 표시 여부 (기본값: false)
  final bool showBorder;
  
  /// 아이콘 색상 (기본값: 해당 라인의 기본 색상)
  final Color? color;
  
  /// 배경 색상 (기본값: 해당 라인의 기본 색상의 투명도 0.1)
  final Color? backgroundColor;
  
  /// 선택된 상태 (기본값: false)
  final bool isSelected;
  
  const LaneIcon({
    Key? key,
    required this.lane,
    this.size = 24.0,
    this.showBackground = true,
    this.showBorder = false,
    this.color,
    this.backgroundColor,
    this.isSelected = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final laneColor = _getLaneColor();
    final bgColor = backgroundColor ?? laneColor.withOpacity(0.1);
    final iconColor = color ?? (isSelected ? laneColor : Colors.grey.shade700);
    
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.2),
      decoration: showBackground 
          ? BoxDecoration(
              color: isSelected ? laneColor.withOpacity(0.2) : bgColor,
              shape: BoxShape.circle,
              border: showBorder 
                  ? Border.all(
                      color: isSelected ? laneColor : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    )
                  : null,
            )
          : null,
      child: Image.asset(
        _getLaneImagePath(),
        width: size * 0.6,
        height: size * 0.6,
        color: iconColor,
      ),
    );
  }
  
  /// 라인 색상 반환
  Color _getLaneColor() {
    switch (lane.toLowerCase()) {
      case 'top': return AppColors.roleTop;
      case 'jungle': return AppColors.roleJungle;
      case 'mid': return AppColors.roleMid;
      case 'adc': return AppColors.roleAdc;
      case 'support': return AppColors.roleSupport;
      default: return AppColors.primary;
    }
  }
  
  /// 라인 이미지 경로 반환
  String _getLaneImagePath() {
    switch (lane.toLowerCase()) {
      case 'top': return LolLaneIcons.top;
      case 'jungle': return LolLaneIcons.jungle;
      case 'mid': return LolLaneIcons.mid;
      case 'adc': return LolLaneIcons.adc;
      case 'support': return LolLaneIcons.support;
      default: return LolLaneIcons.top;
    }
  }
} 