import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';

class MercenarySearchTab extends StatefulWidget {
  const MercenarySearchTab({Key? key}) : super(key: key);

  @override
  State<MercenarySearchTab> createState() => _MercenarySearchTabState();
}

class _MercenarySearchTabState extends State<MercenarySearchTab> {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = false;
  String? _errorMessage;
  List<MercenaryModel> _mercenaries = [];
  bool _ovrToggle = true;
  
  @override
  void initState() {
    super.initState();
    _loadMercenaries();
  }
  
  Future<void> _loadMercenaries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final mercenaries = await _firebaseService.getAvailableMercenaries(
        limit: 20,
        minOvr: _ovrToggle ? null : 0,
      );
      
      setState(() {
        _mercenaries = mercenaries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load mercenaries: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _errorMessage != null
                ? ErrorView(
                    message: _errorMessage!,
                    onRetry: _loadMercenaries,
                  )
                : _isLoading
                    ? const LoadingIndicator()
                    : _mercenaries.isEmpty
                        ? _buildEmptyState()
                        : _buildMercenaryList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/mercenaries/edit');
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // OVR Filter toggle
          FilterChip(
            label: const Text('OVR 표시'),
            selected: _ovrToggle,
            onSelected: (value) {
              setState(() {
                _ovrToggle = value;
              });
              _loadMercenaries();
            },
            selectedColor: AppColors.primary.withOpacity(0.2),
            checkmarkColor: AppColors.primary,
          ),
          const SizedBox(width: 8),
          // Additional filters can be added here
        ],
      ),
    );
  }
  
  Widget _buildMercenaryList() {
    return RefreshIndicator(
      onRefresh: _loadMercenaries,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _mercenaries.length,
        itemBuilder: (context, index) {
          final mercenary = _mercenaries[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () {
                context.push('/mercenaries/${mercenary.id}');
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Profile Image
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: mercenary.profileImageUrl != null
                          ? NetworkImage(mercenary.profileImageUrl!)
                          : null,
                      child: mercenary.profileImageUrl == null
                          ? const Icon(Icons.person, size: 30)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                mercenary.nickname,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (mercenary.tier != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _getTierName(mercenary.tier!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Preferred positions
                          Wrap(
                            spacing: 8,
                            children: mercenary.preferredPositions.map((position) {
                              return Chip(
                                label: Text(position),
                                padding: EdgeInsets.zero,
                                labelStyle: const TextStyle(fontSize: 10),
                                backgroundColor: Colors.grey.shade200,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    // Stats
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _getTopRoleStat(mercenary).toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTopRole(mercenary),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '아직 등록된 용병이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              context.push('/mercenaries/edit');
            },
            child: const Text('용병 등록하기'),
          ),
        ],
      ),
    );
  }
  
  // 헬퍼 메서드: 티어 이름 반환
  String _getTierName(PlayerTier tier) {
    switch (tier) {
      case PlayerTier.iron: return '아이언';
      case PlayerTier.bronze: return '브론즈';
      case PlayerTier.silver: return '실버';
      case PlayerTier.gold: return '골드';
      case PlayerTier.platinum: return '플래티넘';
      case PlayerTier.diamond: return '다이아몬드';
      case PlayerTier.master: return '마스터';
      case PlayerTier.grandmaster: return '그랜드마스터';
      case PlayerTier.challenger: return '챌린저';
      case PlayerTier.unranked: return '언랭크';
    }
  }
  
  // 헬퍼 메서드: 최고 역할 찾기
  String _getTopRole(MercenaryModel mercenary) {
    if (mercenary.roleStats.isEmpty) return '';
    
    MapEntry<String, int> topEntry = mercenary.roleStats.entries.first;
    
    for (final entry in mercenary.roleStats.entries) {
      if (entry.value > topEntry.value) {
        topEntry = entry;
      }
    }
    
    return topEntry.key;
  }
  
  // 헬퍼 메서드: 최고 역할 스탯 찾기
  int _getTopRoleStat(MercenaryModel mercenary) {
    if (mercenary.roleStats.isEmpty) return 0;
    
    int topStat = mercenary.roleStats.values.first;
    
    for (final stat in mercenary.roleStats.values) {
      if (stat > topStat) {
        topStat = stat;
      }
    }
    
    return topStat;
  }
} 