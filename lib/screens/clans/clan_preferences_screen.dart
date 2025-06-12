import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/clan_creation_provider.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'dart:io';

class ClanPreferencesScreen extends StatefulWidget {
  const ClanPreferencesScreen({Key? key}) : super(key: key);

  @override
  State<ClanPreferencesScreen> createState() => _ClanPreferencesScreenState();
}

class _ClanPreferencesScreenState extends State<ClanPreferencesScreen> {
  final Map<AgeGroup, String> _ageLabels = {
    AgeGroup.teens: '10대',
    AgeGroup.twenties: '20대',
    AgeGroup.thirties: '30대',
    AgeGroup.fortyPlus: '40대 이상',
  };
  
  final Map<GenderPreference, String> _genderLabels = {
    GenderPreference.male: '남자',
    GenderPreference.female: '여자',
    GenderPreference.any: '남녀 모두',
  };

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ClanCreationProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('클랜 선호도'),
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
                      if (provider.hasEmblem)
                        _buildEmblemPreview(provider),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          provider.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    '어떤 사람들이\n모여있나요?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      '정확하지 않아도 괜찮아요. 주변의 팀, 선수들과 매칭될 수 있게 도와드릴게요.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Age groups
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '주요 나이대',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(복수선택 가능)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      if (provider.ageGroups.isEmpty)
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
                  
                  // Age selection
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final entry in _ageLabels.entries)
                        _buildSelectionTile(
                          label: entry.value,
                          isSelected: provider.ageGroups.contains(entry.key),
                          onTap: () => provider.toggleAgeGroup(entry.key),
                          icon: _getAgeIcon(entry.key),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Gender preference
                  const Text(
                    '성별',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Gender selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      for (final entry in _genderLabels.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _buildSelectionTile(
                            label: entry.value,
                            isSelected: provider.genderPreference == entry.key,
                            onTap: () => provider.setGenderPreference(entry.key),
                            icon: _getGenderIcon(entry.key),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  spreadRadius: 0,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
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
                      elevation: 0,
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
                      elevation: 2,
                    ),
                    child: const Text(
                      '다음',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
  
  Widget _buildEmblemPreview(ClanCreationProvider provider) {
    if (!provider.hasEmblem) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.group,
          size: 24,
          color: AppColors.primary,
        ),
      );
    }
    
    if (provider.emblem is File) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            fit: BoxFit.cover,
            image: FileImage(provider.emblem as File),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      );
    } else if (provider.emblem is Map) {
      // 엠블럼 속성 가져오기
      final emblem = provider.emblem as Map;
      final String frame = emblem['frame'] as String? ?? 'circle';
      final String symbol = emblem['symbol'] as String? ?? 'sports_soccer';
      final Color color = emblem['backgroundColor'] as Color? ?? AppColors.primary;
      
      // 프레임 형태에 따라 다른 모양 반환
      switch (frame) {
        case 'circle':
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                _getIconData(symbol),
                size: 20,
                color: Colors.white,
              ),
            ),
          );
        case 'rounded_square':
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                _getIconData(symbol),
                size: 20,
                color: Colors.white,
              ),
            ),
          );
        default:
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                _getIconData(symbol),
                size: 20,
                color: Colors.white,
              ),
            ),
          );
      }
    }
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.group,
        size: 24,
        color: AppColors.primary,
      ),
    );
  }
  
  IconData _getIconData(String symbol) {
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
    
    return iconMap[symbol] ?? Icons.star;
  }
  
  IconData _getAgeIcon(AgeGroup ageGroup) {
    switch (ageGroup) {
      case AgeGroup.teens:
        return Icons.school;
      case AgeGroup.twenties:
        return Icons.emoji_people;
      case AgeGroup.thirties:
        return Icons.work;
      case AgeGroup.fortyPlus:
        return Icons.psychology;
      default:
        return Icons.person;
    }
  }
  
  IconData _getGenderIcon(GenderPreference gender) {
    switch (gender) {
      case GenderPreference.male:
        return Icons.male;
      case GenderPreference.female:
        return Icons.female;
      case GenderPreference.any:
        return Icons.people;
      default:
        return Icons.people;
    }
  }
  
  Widget _buildSelectionTile({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              spreadRadius: isSelected ? 1 : 0,
            ),
          ],
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  bool _canProceed() {
    final provider = Provider.of<ClanCreationProvider>(context, listen: false);
    return provider.ageGroups.isNotEmpty;
  }
  
  void _proceedToNext() {
    final provider = Provider.of<ClanCreationProvider>(context, listen: false);
    
    // 나이대가 선택되었는지 확인
    if (provider.ageGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('주요 나이대를 최소 1개 이상 선택해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    provider.nextStep();
    
    // 명확한 이동 경로 지정
    context.push('/clans/focus');
  }
} 