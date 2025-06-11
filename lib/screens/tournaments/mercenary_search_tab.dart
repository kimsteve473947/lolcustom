import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  bool _isLoading = false;
  String? _errorMessage;
  List<MercenaryModel> _mercenaries = [];
  List<MercenaryModel> _filteredMercenaries = [];
  
  // 필터링 상태
  final List<String> _positions = ['TOP', 'JUNGLE', 'MID', 'ADC', 'SUPPORT'];
  final List<String> _activityTimes = ['평일 오전', '평일 오후', '주말 오전', '주말 오후'];
  final List<PlayerTier> _tiers = [
    PlayerTier.iron,
    PlayerTier.bronze,
    PlayerTier.silver,
    PlayerTier.gold,
    PlayerTier.platinum,
    PlayerTier.emerald,
    PlayerTier.diamond,
    PlayerTier.master,
    PlayerTier.grandmaster,
    PlayerTier.challenger
  ];
  
  List<String> _selectedPositions = [];
  List<String> _selectedActivityTimes = [];
  List<PlayerTier> _selectedTiers = [];
  bool _showFilters = false;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadMercenaries();
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _filterMercenaries();
      });
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  void _filterMercenaries() {
    if (_searchQuery.isEmpty && 
        _selectedPositions.isEmpty && 
        _selectedTiers.isEmpty && 
        _selectedActivityTimes.isEmpty) {
      _filteredMercenaries = List.from(_mercenaries);
      return;
    }
    
    _filteredMercenaries = _mercenaries.where((mercenary) {
      // 검색어 필터링
      final matchesQuery = _searchQuery.isEmpty || 
                          mercenary.nickname.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          (mercenary.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      
      // 포지션 필터링
      final matchesPosition = _selectedPositions.isEmpty || 
                              _selectedPositions.any((pos) => mercenary.preferredPositions.contains(pos));
      
      // 티어 필터링
      final matchesTier = _selectedTiers.isEmpty || 
                         (mercenary.tier != null && _selectedTiers.contains(mercenary.tier));
      
      // 활동 시간 필터링
      final matchesActivityTime = _selectedActivityTimes.isEmpty ||
                                _selectedActivityTimes.any((time) {
                                  if (time == '평일 오전') {
                                    return _containsWeekdayMorning(mercenary.availabilityTimeSlots);
                                  } else if (time == '평일 오후') {
                                    return _containsWeekdayAfternoon(mercenary.availabilityTimeSlots);
                                  } else if (time == '주말 오전') {
                                    return _containsWeekendMorning(mercenary.availabilityTimeSlots);
                                  } else if (time == '주말 오후') {
                                    return _containsWeekendAfternoon(mercenary.availabilityTimeSlots);
                                  }
                                  return false;
                                });
      
      return matchesQuery && matchesPosition && matchesTier && matchesActivityTime;
    }).toList();
  }
  
  // 평일 오전 활동 확인
  bool _containsWeekdayMorning(Map<String, List<String>> availabilityTimeSlots) {
    final weekdays = ['월', '화', '수', '목', '금'];
    for (final day in weekdays) {
      final slots = availabilityTimeSlots[day] ?? [];
      if (slots.contains('오전')) return true;
    }
    return false;
  }
  
  // 평일 오후 활동 확인
  bool _containsWeekdayAfternoon(Map<String, List<String>> availabilityTimeSlots) {
    final weekdays = ['월', '화', '수', '목', '금'];
    for (final day in weekdays) {
      final slots = availabilityTimeSlots[day] ?? [];
      if (slots.contains('오후') || slots.contains('저녁')) return true;
    }
    return false;
  }
  
  // 주말 오전 활동 확인
  bool _containsWeekendMorning(Map<String, List<String>> availabilityTimeSlots) {
    final weekends = ['토', '일'];
    for (final day in weekends) {
      final slots = availabilityTimeSlots[day] ?? [];
      if (slots.contains('오전')) return true;
    }
    return false;
  }
  
  // 주말 오후 활동 확인
  bool _containsWeekendAfternoon(Map<String, List<String>> availabilityTimeSlots) {
    final weekends = ['토', '일'];
    for (final day in weekends) {
      final slots = availabilityTimeSlots[day] ?? [];
      if (slots.contains('오후') || slots.contains('저녁')) return true;
    }
    return false;
  }
  
  Future<void> _loadMercenaries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final mercenaries = await _firebaseService.getAvailableMercenaries(limit: 50);
      
      if (mounted) {
      setState(() {
        _mercenaries = mercenaries;
          _filteredMercenaries = List.from(mercenaries);
        _isLoading = false;
      });
      }
    } catch (e) {
      if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load mercenaries: $e';
      });
    }
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedPositions = [];
      _selectedTiers = [];
      _selectedActivityTimes = [];
      _filterMercenaries();
    });
  }

  void _applyFilters() {
    setState(() {
      _showFilters = false;
      _filterMercenaries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '용병 찾기',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.tune : Icons.tune_outlined,
              color: _showFilters ? AppColors.primary : Colors.grey[700],
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: '닉네임이나 소개글로 용병 검색하기',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[400]),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            
            // Active Filters
            if (_selectedPositions.isNotEmpty || _selectedTiers.isNotEmpty || _selectedActivityTimes.isNotEmpty)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._selectedPositions.map((position) => _buildFilterChip(
                        label: position,
                        onRemove: () {
                          setState(() {
                            _selectedPositions.remove(position);
                            _filterMercenaries();
                          });
                        },
                      )),
                      ..._selectedTiers.map((tier) => _buildFilterChip(
                        label: _getTierName(tier),
                        onRemove: () {
                          setState(() {
                            _selectedTiers.remove(tier);
                            _filterMercenaries();
                          });
                        },
                      )),
                      ..._selectedActivityTimes.map((time) => _buildFilterChip(
                        label: time,
                        onRemove: () {
                          setState(() {
                            _selectedActivityTimes.remove(time);
                            _filterMercenaries();
                          });
                        },
                      )),
                      if (_selectedPositions.isNotEmpty || _selectedTiers.isNotEmpty || _selectedActivityTimes.isNotEmpty)
                        TextButton(
                          onPressed: _resetFilters,
                          child: Text(
                            '모두 지우기',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            
            // Filter Panel
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _showFilters ? 340 : 0,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                      // 포지션 필터
                      const Text(
                        '포지션',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _positions.map((position) {
                          final selected = _selectedPositions.contains(position);
                          return FilterChip(
                            label: Text(position),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _selectedPositions.add(position);
                                } else {
                                  _selectedPositions.remove(position);
                                }
                              });
                            },
                            selectedColor: AppColors.primary.withOpacity(0.15),
                            checkmarkColor: AppColors.primary,
                            backgroundColor: Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            labelStyle: TextStyle(
                              color: selected ? AppColors.primary : Colors.black87,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 티어 필터
                      const Text(
                        '티어',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tiers.map((tier) {
                          final selected = _selectedTiers.contains(tier);
                          return FilterChip(
                            label: Text(_getTierName(tier)),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _selectedTiers.add(tier);
                                } else {
                                  _selectedTiers.remove(tier);
                                }
                              });
                            },
                            selectedColor: AppColors.primary.withOpacity(0.15),
                            checkmarkColor: AppColors.primary,
                            backgroundColor: Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            labelStyle: TextStyle(
                              color: selected ? AppColors.primary : Colors.black87,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 활동 시간 필터
                      const Text(
                        '활동 시간',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _activityTimes.map((time) {
                          final selected = _selectedActivityTimes.contains(time);
                          return FilterChip(
                            label: Text(time),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _selectedActivityTimes.add(time);
                                } else {
                                  _selectedActivityTimes.remove(time);
                                }
                              });
                            },
                            selectedColor: AppColors.primary.withOpacity(0.15),
                            checkmarkColor: AppColors.primary,
                            backgroundColor: Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            labelStyle: TextStyle(
                              color: selected ? AppColors.primary : Colors.black87,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 필터 적용 버튼
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _applyFilters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            '필터 적용하기',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // 결과 카운트
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              alignment: Alignment.centerLeft,
              child: Text(
                '검색 결과 ${_filteredMercenaries.length}명',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            
            // 목록 영역
          Expanded(
            child: _errorMessage != null
                ? ErrorView(
                    errorMessage: _errorMessage!,
                    onRetry: _loadMercenaries,
                  )
                : _isLoading
                    ? const LoadingIndicator()
                      : _filteredMercenaries.isEmpty
                        ? _buildEmptyState()
                        : _buildMercenaryList(),
          ),
        ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/mercenaries/edit');
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
  
  Widget _buildFilterChip({required String label, required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        backgroundColor: AppColors.primary.withOpacity(0.08),
        deleteIcon: const Icon(
          Icons.close,
          size: 16,
          color: AppColors.primary,
        ),
        onDeleted: onRemove,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
  
  Widget _buildMercenaryList() {
    return RefreshIndicator(
      onRefresh: _loadMercenaries,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _filteredMercenaries.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final mercenary = _filteredMercenaries[index];
          return _buildMercenaryCard(mercenary);
        },
      ),
    );
  }
  
  Widget _buildMercenaryCard(MercenaryModel mercenary) {
          return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
            child: InkWell(
              onTap: () {
                context.push('/mercenaries/${mercenary.id}');
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                  // 프로필 이미지
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[100],
                      image: mercenary.profileImageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(mercenary.profileImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: mercenary.profileImageUrl == null
                        ? Icon(Icons.person, size: 24, color: Colors.grey[400])
                        : null,
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // 기본 정보
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
                              _buildTierBadge(mercenary.tier!),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '최근 활동: ${_getLastActiveText(mercenary.lastActiveAt)}',
                                    style: TextStyle(
                                      fontSize: 12,
                            color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // 포지션 영역
                          Wrap(
                            spacing: 8,
                runSpacing: 8,
                            children: mercenary.preferredPositions.map((position) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getPositionColor(position).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getPositionColor(position).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      position,
                      style: TextStyle(
                        color: _getPositionColor(position),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                              );
                            }).toList(),
                          ),
              
              // 소개글 영역
              if (mercenary.description != null && mercenary.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    mercenary.description!,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // 상세보기 버튼
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    context.push('/mercenaries/${mercenary.id}');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '상세보기',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
  }
  
  Widget _buildTierBadge(PlayerTier tier) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: _getTierColor(tier),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getTierName(tier),
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
      child: Column(
            mainAxisSize: MainAxisSize.min,
        children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
              ),
              const SizedBox(height: 24),
          Text(
                '검색 결과가 없습니다',
            style: TextStyle(
              fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
            ),
              ),
              const SizedBox(height: 12),
              Text(
                '다른 필터를 적용하거나 새로운 용병을 등록해보세요',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
              ElevatedButton.icon(
            onPressed: () {
              context.push('/mercenaries/edit');
            },
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  '용병 등록하기',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
          ),
        ],
          ),
        ),
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
      case PlayerTier.emerald: return '에메랄드';
      case PlayerTier.diamond: return '다이아몬드';
      case PlayerTier.master: return '마스터';
      case PlayerTier.grandmaster: return '그랜드마스터';
      case PlayerTier.challenger: return '챌린저';
      case PlayerTier.unranked: return '언랭크';
    }
  }
  
  // 티어별 색상
  Color _getTierColor(PlayerTier tier) {
    switch (tier) {
      case PlayerTier.iron: return Colors.grey[700]!;
      case PlayerTier.bronze: return const Color(0xFFCD7F32);
      case PlayerTier.silver: return const Color(0xFFC0C0C0);
      case PlayerTier.gold: return const Color(0xFFFFD700);
      case PlayerTier.platinum: return const Color(0xFF8BFFFF);
      case PlayerTier.emerald: return const Color(0xFF50C878);
      case PlayerTier.diamond: return const Color(0xFFB9F2FF);
      case PlayerTier.master: return const Color(0xFF9370DB);
      case PlayerTier.grandmaster: return const Color(0xFFFF4500);
      case PlayerTier.challenger: return const Color(0xFFE6E6FA);
      case PlayerTier.unranked: return Colors.grey;
    }
  }
  
  // 포지션별 색상
  Color _getPositionColor(String position) {
    switch (position) {
      case 'TOP': return const Color(0xFF5C7CFA);
      case 'JUNGLE': return const Color(0xFF40C057);
      case 'MID': return const Color(0xFFFFA94D);
      case 'ADC': return const Color(0xFFFA5252);
      case 'SUPPORT': return const Color(0xFF845EF7);
      default: return Colors.grey;
    }
  }
  
  // 최근 활동 텍스트
  String _getLastActiveText(Timestamp? lastActiveAt) {
    if (lastActiveAt == null) {
      return '정보 없음';
    }
    
    final lastActiveDateTime = lastActiveAt.toDate();
    final now = DateTime.now();
    final difference = now.difference(lastActiveDateTime);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${(difference.inDays / 7).floor()}주 전';
    }
  }
} 