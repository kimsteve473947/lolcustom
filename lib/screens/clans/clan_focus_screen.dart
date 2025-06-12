import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/clan_creation_provider.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart' as CustomAuth;
import 'dart:io';

class ClanFocusScreen extends StatefulWidget {
  const ClanFocusScreen({Key? key}) : super(key: key);

  @override
  State<ClanFocusScreen> createState() => _ClanFocusScreenState();
}

class _ClanFocusScreenState extends State<ClanFocusScreen> {
  double _sliderValue = 5.0;
  bool _isCreating = false;
  
  @override
  void initState() {
    super.initState();
    // Initialize slider with provider value
    final provider = Provider.of<ClanCreationProvider>(context, listen: false);
    _sliderValue = provider.focusRating.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ClanCreationProvider>(context);
    final authProvider = Provider.of<CustomAuth.AuthProvider>(context);
    
    // Set focus based on slider position
    ClanFocus focus;
    if (_sliderValue <= 3) {
      focus = ClanFocus.casual;
    } else if (_sliderValue >= 7) {
      focus = ClanFocus.competitive;
    } else {
      focus = ClanFocus.balanced;
    }
    
    // Update provider with current values
    if (provider.focusRating != _sliderValue.toInt() || provider.focus != focus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.setFocusRating(_sliderValue.toInt());
        provider.setFocus(focus);
      });
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('클랜 성향'),
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
                    '팀 성향을\n선택해주세요',
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
                      '설정한 성향에 따라 비슷한 성향의 클랜과 매칭될 확률이 높아집니다.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Focus level display
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildFocusIndicator(
                          label: _getFocusLabel(focus),
                          description: _getFocusDescription(focus),
                          color: _getFocusColor(focus),
                        ),
                        const SizedBox(height: 32),
                        
                        // Slider
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: _getFocusColor(focus),
                            inactiveTrackColor: Colors.grey[200],
                            thumbColor: _getFocusColor(focus),
                            overlayColor: _getFocusColor(focus).withOpacity(0.2),
                            trackHeight: 8.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
                          ),
                          child: Slider(
                            value: _sliderValue,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            onChanged: (value) {
                              setState(() {
                                _sliderValue = value;
                              });
                            },
                          ),
                        ),
                        
                        // Scale labels
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '친목 위주',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '균형',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '실력 위주',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Focus description
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getFocusColor(focus).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getFocusColor(focus).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getFocusIcon(),
                              color: _getFocusColor(focus),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getFocusDetailTitle(focus),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _getFocusColor(focus),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getDetailedDescription(focus),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
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
                    onPressed: _isCreating ? null : () => _createClan(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '완료',
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
  
  Widget _buildFocusIndicator({
    required String label,
    required String description,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              _getFocusIcon(),
              color: color,
              size: 30,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  IconData _getFocusIcon() {
    if (_sliderValue <= 3) {
      return Icons.sentiment_satisfied_alt;
    } else if (_sliderValue >= 7) {
      return Icons.fitness_center;
    } else {
      return Icons.balance;
    }
  }
  
  String _getFocusLabel(ClanFocus focus) {
    switch (focus) {
      case ClanFocus.casual:
        return '친목 위주';
      case ClanFocus.competitive:
        return '실력 위주';
      case ClanFocus.balanced:
        return '균형잡힌 스타일';
    }
  }
  
  String _getFocusDescription(ClanFocus focus) {
    switch (focus) {
      case ClanFocus.casual:
        return '즐겁게 게임하며 좋은 시간을 보내요';
      case ClanFocus.competitive:
        return '승리를 위해 전략적으로 플레이해요';
      case ClanFocus.balanced:
        return '실력과 친목 모두 중요해요';
    }
  }
  
  String _getFocusDetailTitle(ClanFocus focus) {
    switch (focus) {
      case ClanFocus.casual:
        return '함께하는 즐거움에 집중해요';
      case ClanFocus.competitive:
        return '승리와 실력 향상에 집중해요';
      case ClanFocus.balanced:
        return '즐거움과 승리 모두 중요해요';
    }
  }
  
  String _getDetailedDescription(ClanFocus focus) {
    switch (focus) {
      case ClanFocus.casual:
        return '경쟁보다는 함께하는 즐거움을 중요시해요. 실수를 해도 괜찮아요. 재미있게 게임하며 친목을 다지는 것이 목표예요. 성장보다는 즐거운 시간을 우선시합니다.';
      case ClanFocus.competitive:
        return '승리를 위해 노력하고 실력 향상에 집중해요. 팀원 각자의 역할을 중요시하며 전략적인 플레이를 추구해요. 목표를 향해 함께 성장하는 것을 추구합니다.';
      case ClanFocus.balanced:
        return '승리도 중요하지만 함께 즐기는 것도 중요해요. 서로 돕고 배우며 실력을 향상시키는 동시에 좋은 관계를 유지해요. 적절한 긴장감과 즐거움을 모두 추구합니다.';
    }
  }
  
  Color _getFocusColor(ClanFocus focus) {
    switch (focus) {
      case ClanFocus.casual:
        return Colors.green.shade600;
      case ClanFocus.competitive:
        return Colors.red.shade600;
      case ClanFocus.balanced:
        return AppColors.primary;
    }
  }
  
  Future<void> _createClan(BuildContext context) async {
    final provider = Provider.of<ClanCreationProvider>(context, listen: false);
    final authProvider = Provider.of<CustomAuth.AuthProvider>(context, listen: false);
    
    if (!provider.isFormValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모든 정보를 입력해주세요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Check if user is logged in
    if (authProvider.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() {
      _isCreating = true;
    });
    
    try {
      // 클랜 생성
      final clan = await provider.createClan(authProvider.user!.uid);
      
      // Reset provider after successful creation
      provider.reset();
      
      // Navigate to the clan detail page
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('클랜이 성공적으로 생성되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // 클랜 상세 페이지로 이동
        context.go('/clans/${clan.id}');
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('클랜 생성 중 오류가 발생했습니다: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
} 