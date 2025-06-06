import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';
import 'package:lol_custom_game_manager/models/models.dart';

/// 토너먼트 관련 UI 유틸리티 클래스
/// 여러 화면에서 공통으로 사용할 수 있는 UI 헬퍼 함수들을 제공합니다.
class TournamentUIUtils {
  // 역할 이름 반환
  static String getRoleName(String role) {
    switch (role) {
      case 'top': return '탑';
      case 'jungle': return '정글';
      case 'mid': return '미드';
      case 'adc': return '원딜';
      case 'support': return '서포터';
      default: return role;
    }
  }
  
  // 역할 색상 반환
  static Color getRoleColor(String role) {
    switch (role) {
      case 'top': return AppColors.roleTop;
      case 'jungle': return AppColors.roleJungle;
      case 'mid': return AppColors.roleMid;
      case 'adc': return AppColors.roleAdc;
      case 'support': return AppColors.roleSupport;
      default: return AppColors.primary;
    }
  }
  
  // 역할 아이콘 이미지 반환
  static Widget getRoleIconImage(String role, {double size = 24.0, Color? color}) {
    String assetPath;
    switch (role) {
      case 'top': assetPath = LolLaneIcons.top; break;
      case 'jungle': assetPath = LolLaneIcons.jungle; break;
      case 'mid': assetPath = LolLaneIcons.mid; break;
      case 'adc': assetPath = LolLaneIcons.adc; break;
      case 'support': assetPath = LolLaneIcons.support; break;
      default: assetPath = LolLaneIcons.top; break;
    }
    
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      color: color,
    );
  }
  
  // 레거시 지원용 - 이전 아이콘 기반 방식 (대체 예정)
  static IconData getRoleIcon(String role) {
    switch (role) {
      case 'top': return Icons.arrow_upward;
      case 'jungle': return Icons.nature_people;
      case 'mid': return Icons.adjust;
      case 'adc': return Icons.gps_fixed;
      case 'support': return Icons.shield;
      default: return Icons.sports_esports;
    }
  }
  
  // 티어 이름 반환
  static String getTierName(PlayerTier tier) {
    switch (tier) {
      case PlayerTier.iron: return '아이언';
      case PlayerTier.bronze: return '브론즈';
      case PlayerTier.silver: return '실버';
      case PlayerTier.gold: return '골드';
      case PlayerTier.platinum: return '플래티넘';
      case PlayerTier.emerald: return '에메랄드';
      case PlayerTier.diamond: return '다이아몬드';
      case PlayerTier.master: return '마스터';
      case PlayerTier.grandmaster: return '그랜드마스터';
      case PlayerTier.challenger: return '챌린저';
      default: return '없음';
    }
  }
  
  // 토너먼트 상태 텍스트 반환
  static String getStatusText(TournamentStatus status) {
    switch (status) {
      case TournamentStatus.draft: return '초안';
      case TournamentStatus.open: return '모집 중';
      case TournamentStatus.full: return '모집 완료';
      case TournamentStatus.inProgress:
      case TournamentStatus.ongoing: return '진행 중';
      case TournamentStatus.completed: return '완료됨';
      case TournamentStatus.cancelled: return '취소됨';
    }
  }
  
  // 토너먼트 상태 색상 반환
  static Color getStatusColor(TournamentStatus status) {
    switch (status) {
      case TournamentStatus.draft: return Colors.grey;
      case TournamentStatus.open: return AppColors.success;
      case TournamentStatus.full: return AppColors.primary;
      case TournamentStatus.inProgress:
      case TournamentStatus.ongoing: return AppColors.warning;
      case TournamentStatus.completed: return AppColors.textSecondary;
      case TournamentStatus.cancelled: return AppColors.error;
    }
  }
  
  // 토너먼트 상태 칩 위젯 반환
  static Widget buildTournamentStatusChip(TournamentStatus status) {
    final color = getStatusColor(status);
    final text = getStatusText(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  // 역할 기반 섹션 타이틀 생성
  static Widget buildRoleSectionTitle(String role) {
    final color = getRoleColor(role);
    final name = getRoleName(role);
    final icon = getRoleIcon(role);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
} 