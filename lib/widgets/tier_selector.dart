import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/utils/image_utils.dart';

class TierSelector extends StatefulWidget {
  final PlayerTier? initialTier;
  final ValueChanged<PlayerTier> onTierChanged;
  final String title;
  final String subtitle;
  final ValueChanged<String>? onTitleGenerated;

  const TierSelector({
    Key? key,
    this.initialTier,
    required this.onTierChanged,
    this.title = '티어 선택',
    this.subtitle = '참가자 제한 티어를 선택하세요',
    this.onTitleGenerated,
  }) : super(key: key);

  @override
  State<TierSelector> createState() => _TierSelectorState();
}

class _TierSelectorState extends State<TierSelector> {
  late PlayerTier _selectedTier;
  
  @override
  void initState() {
    super.initState();
    _selectedTier = widget.initialTier ?? PlayerTier.unranked;
    
    // 초기값에 대한 제목 생성 및 콜백 호출
    // initState에서 직접 콜백 호출 대신 마이크로태스크 큐에 추가
    if (widget.onTitleGenerated != null) {
      // 다음 프레임에서 실행되도록 스케줄링
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateTitle(_selectedTier);
      });
    }
  }
  
  final Map<PlayerTier, Color> _tierColors = {
    PlayerTier.iron: const Color(0xFF515A5A),
    PlayerTier.bronze: const Color(0xFFCD7F32),
    PlayerTier.silver: const Color(0xFFC0C0C0),
    PlayerTier.gold: const Color(0xFFFFD700),
    PlayerTier.platinum: const Color(0xFF89CFF0),
    PlayerTier.emerald: const Color(0xFF50C878),
    PlayerTier.diamond: const Color(0xFFB9F2FF),
    PlayerTier.master: const Color(0xFF9370DB),
    PlayerTier.grandmaster: const Color(0xFFFF4500),
    PlayerTier.challenger: const Color(0xFFFFA500),
    PlayerTier.unranked: Colors.grey,
  };
  
  final Map<PlayerTier, String> _tierNames = {
    PlayerTier.iron: '아이언',
    PlayerTier.bronze: '브론즈',
    PlayerTier.silver: '실버',
    PlayerTier.gold: '골드',
    PlayerTier.platinum: '플래티넘',
    PlayerTier.emerald: '에메랄드',
    PlayerTier.diamond: '다이아몬드',
    PlayerTier.master: '마스터',
    PlayerTier.grandmaster: '그랜드마스터',
    PlayerTier.challenger: '챌린저',
    PlayerTier.unranked: '랜덤 멸망전',
  };
  
  final Map<PlayerTier, IconData> _tierIcons = {
    PlayerTier.iron: Icons.grid_3x3,
    PlayerTier.bronze: Icons.looks_3,
    PlayerTier.silver: Icons.filter_tilt_shift,
    PlayerTier.gold: Icons.star,
    PlayerTier.platinum: Icons.auto_awesome,
    PlayerTier.emerald: Icons.spa,
    PlayerTier.diamond: Icons.diamond,
    PlayerTier.master: Icons.workspace_premium,
    PlayerTier.grandmaster: Icons.military_tech,
    PlayerTier.challenger: Icons.emoji_events,
    PlayerTier.unranked: Icons.shuffle,
  };
  
  // 선택한 티어에 따라 제목을 생성하는 메서드
  void _generateTitle(PlayerTier tier) {
    if (tier == PlayerTier.unranked) {
      widget.onTitleGenerated?.call('랜덤 멸망전');
    } else {
      final tierName = _tierNames[tier] ?? '알 수 없음';
      
      // 마스터인 경우 "마스터~챌린저 내전"으로 표시
      if (tier == PlayerTier.master) {
        widget.onTitleGenerated?.call('$tierName~챌린저 내전');
        return;
      }
      
      // 다음 티어 찾기
      final nextTierIndex = tier.index + 1;
      if (nextTierIndex < PlayerTier.values.length) {
        final nextTier = PlayerTier.values[nextTierIndex];
        final nextTierName = _tierNames[nextTier] ?? '알 수 없음';
        widget.onTitleGenerated?.call('$tierName~$nextTierName 내전');
      } else {
        widget.onTitleGenerated?.call('$tierName 내전');
      }
    }
  }
  
  void _selectTier(PlayerTier tier) {
    if (_selectedTier == tier) return; // 같은 티어 재선택 방지
    
    setState(() {
      _selectedTier = tier;
    });
    widget.onTierChanged(tier);
    
    // 티어 선택 시 제목 생성 및 콜백 호출
    if (widget.onTitleGenerated != null) {
      _generateTitle(tier);
    }
  }
  
  // 티어 이름에 따라 참가 가능 범위 반환
  String _getTierRangeText(PlayerTier tier) {
    if (tier == PlayerTier.unranked) {
      return '모든 티어 참가 가능';
    }
    
    // 마스터인 경우 마스터~챌린저 참가 가능으로 표시
    if (tier == PlayerTier.master) {
      return '${_tierNames[tier]} ~ 챌린저 참가 가능';
    }
    
    // 티어 순서를 기준으로 다음 티어 찾기
    final tierIndex = tier.index;
    if (tierIndex >= PlayerTier.values.length - 1) {
      // 최상위 티어인 경우 해당 티어만 참가 가능
      return '${_tierNames[tier]} 참가 가능';
    } else {
      final nextTier = PlayerTier.values[tierIndex + 1];
      return '${_tierNames[tier]} ~ ${_tierNames[nextTier]} 참가 가능';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _buildTierItem(PlayerTier.unranked),
              _buildTierItem(PlayerTier.iron),
              _buildTierItem(PlayerTier.bronze),
              _buildTierItem(PlayerTier.silver),
              _buildTierItem(PlayerTier.gold),
              _buildTierItem(PlayerTier.platinum),
              _buildTierItem(PlayerTier.emerald),
              _buildTierItem(PlayerTier.diamond),
              _buildTierItem(PlayerTier.master),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _getTierRangeText(_selectedTier),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTierItem(PlayerTier tier) {
    final isSelected = _selectedTier == tier;
    final color = _tierColors[tier] ?? Colors.grey;
    final name = _tierNames[tier] ?? '알 수 없음';
    
    return GestureDetector(
      onTap: () => _selectTier(tier),
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (tier == PlayerTier.unranked)
              Icon(
                Icons.shuffle,
                color: color,
                size: 32,
              )
            else
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                child: ClipOval(
                  child: Image.asset(
                    ImageUtils.getTierLogoPath(tier),
                    height: 40,
                    width: 40,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? color : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 