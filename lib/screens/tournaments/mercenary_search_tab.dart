import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/models/matching_request_model.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:lol_custom_game_manager/widgets/lane_icon_widget.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';

class MercenarySearchTab extends StatefulWidget {
  final int initialIndex;
  
  const MercenarySearchTab({
    Key? key,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<MercenarySearchTab> createState() => _MercenarySearchTabState();
}

class _MercenarySearchTabState extends State<MercenarySearchTab> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: const Color(0xFF1A1A1A),
            unselectedLabelColor: const Color(0xFF999999),
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: '용병 찾기'),
              Tab(text: '듀오 찾기'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MercenaryFinderView(),
            DuoFinderView(),
          ],
        ),
      ),
    );
  }
}

// 용병 찾기 뷰
class MercenaryFinderView extends StatefulWidget {
  const MercenaryFinderView({Key? key}) : super(key: key);

  @override
  State<MercenaryFinderView> createState() => _MercenaryFinderViewState();
}

class _MercenaryFinderViewState extends State<MercenaryFinderView> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  
  List<MercenaryModel> _mercenaries = [];
  List<MercenaryModel> _filteredMercenaries = [];
  MercenaryModel? _myMercenary;
  bool _isLoading = true;
  String? _errorMessage;
  
  // 필터 옵션
  final List<String> _positions = ['탑', '정글', '미드', '원딜', '서폿'];
  final List<PlayerTier> _tiers = PlayerTier.values.where((t) => t != PlayerTier.unranked).toList();
  
  List<String> _selectedPositions = [];
  List<PlayerTier> _selectedTiers = [];
  String _sortBy = 'recent'; // recent, rating, tier
  
  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    _filterMercenaries();
  }
  
  Future<void> _loadData() async {
                        setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 현재 사용자의 용병 프로필 확인
      final currentUser = Provider.of<AppStateProvider>(context, listen: false).currentUser;
      if (currentUser != null) {
        final myMercenaryDoc = await FirebaseFirestore.instance
            .collection('mercenaries')
            .where('userUid', isEqualTo: currentUser.uid)
            .limit(1)
            .get();
            
        if (myMercenaryDoc.docs.isNotEmpty) {
          _myMercenary = MercenaryModel.fromFirestore(myMercenaryDoc.docs.first);
        }
      }
      
      // 전체 용병 목록 로드
      final mercenaries = await _firebaseService.getAvailableMercenaries(limit: 100);
      
                        setState(() {
        _mercenaries = mercenaries;
        _filteredMercenaries = mercenaries;
        _isLoading = false;
      });
      
      _filterMercenaries();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '데이터를 불러오는 중 오류가 발생했습니다: $e';
      });
    }
  }
  
  void _filterMercenaries() {
    List<MercenaryModel> filtered = List.from(_mercenaries);
    
    // 검색어 필터
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((m) =>
        m.nickname.toLowerCase().contains(query) ||
        (m.description?.toLowerCase().contains(query) ?? false)
      ).toList();
    }
    
    // 포지션 필터
    if (_selectedPositions.isNotEmpty) {
      filtered = filtered.where((m) =>
        m.preferredPositions.any((pos) => 
          _selectedPositions.contains(_getKoreanPosition(pos))
        )
      ).toList();
    }
    
    // 티어 필터
    if (_selectedTiers.isNotEmpty) {
      filtered = filtered.where((m) => _selectedTiers.contains(m.tier)).toList();
    }
    
    // 정렬
    switch (_sortBy) {
      case 'recent':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'rating':
        filtered.sort((a, b) => b.averageRating.compareTo(a.averageRating));
        break;
      case 'tier':
        filtered.sort((a, b) => b.tier.index.compareTo(a.tier.index));
        break;
    }
    
    setState(() {
      _filteredMercenaries = filtered;
    });
  }
  
  String _getKoreanPosition(String position) {
    switch (position.toUpperCase()) {
      case 'TOP': return '탑';
      case 'JUNGLE': return '정글';
      case 'MID': return '미드';
      case 'ADC': return '원딜';
      case 'SUPPORT': return '서폿';
      default: return position;
    }
  }
  
  String _getEnglishPosition(String position) {
    switch (position) {
      case '탑': return 'TOP';
      case '정글': return 'JUNGLE';
      case '미드': return 'MID';
      case '원딜': return 'ADC';
      case '서폿': return 'SUPPORT';
      default: return position;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: LoadingIndicator());
    }
    
    if (_errorMessage != null) {
      return ErrorView(errorMessage: _errorMessage!, onRetry: _loadData);
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildSimpleHeader(),
          if (_myMercenary != null) _buildMyProfile(),
          Expanded(
            child: _buildMercenaryList(),
          ),
        ],
      ),
      floatingActionButton: _myMercenary == null
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/mercenaries/register'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                '용병 등록',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }
  
  Widget _buildSimpleHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        children: [
          // 검색바와 필터 버튼
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '닉네임이나 소개글로 검색',
                      hintStyle: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 15,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF999999),
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Color(0xFF999999),
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 필터 버튼
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showFilterBottomSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (_selectedPositions.isNotEmpty || _selectedTiers.isNotEmpty)
                          ? AppColors.primary
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            Icons.tune,
                            color: (_selectedPositions.isNotEmpty || _selectedTiers.isNotEmpty)
                                ? Colors.white
                                : const Color(0xFF666666),
                            size: 24,
                          ),
                        ),
                        if (_selectedPositions.isNotEmpty || _selectedTiers.isNotEmpty)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 상태 표시
          Row(
            children: [
              Text(
                '총 ${_filteredMercenaries.length}명의 용병',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              if (_selectedPositions.isNotEmpty || _selectedTiers.isNotEmpty)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPositions.clear();
                        _selectedTiers.clear();
                      });
                      _filterMercenaries();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.clear,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '필터 초기화',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                '필터',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 24),
              // 포지션 필터
              const Text(
                '포지션',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _positions.map((position) {
                  final isSelected = _selectedPositions.contains(position);
                  return GestureDetector(
                    onTap: () {
                      setModalState(() {
                        if (isSelected) {
                          _selectedPositions.remove(position);
                        } else {
                          _selectedPositions.add(position);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LaneIconWidget(
                            lane: _getEnglishPosition(position).toLowerCase(),
                            size: 16,
                            color: isSelected ? Colors.white : const Color(0xFF666666),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            position,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // 티어 필터
              const Text(
                '티어',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tiers.map((tier) {
                  final isSelected = _selectedTiers.contains(tier);
                  return GestureDetector(
                    onTap: () {
                      setModalState(() {
                        if (isSelected) {
                          _selectedTiers.remove(tier);
                        } else {
                          _selectedTiers.add(tier);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _getTierColor(tier)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getTierName(tier),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF666666),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              // 적용 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    _filterMercenaries();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '적용하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
  
  Widget _buildMyProfile() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _myMercenary!.profileImageUrl != null
                  ? Image.network(
                      _myMercenary!.profileImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.person, color: Color(0xFF999999)),
                    )
                  : const Icon(Icons.person, color: Color(0xFF999999)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '내 용병 프로필',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _myMercenary!.nickname,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/mercenaries/edit/${_myMercenary!.id}'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            child: const Text(
              '수정',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMercenaryList() {
    if (_filteredMercenaries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[300],
            ),
                const SizedBox(height: 16),
            const Text(
              '검색 결과가 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF999999),
              ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
      itemCount: _filteredMercenaries.length,
          itemBuilder: (context, index) {
        final mercenary = _filteredMercenaries[index];
        return _buildMercenaryCard(mercenary);
      },
    );
  }
  
  Widget _buildMercenaryCard(MercenaryModel mercenary) {
    final isMyProfile = _myMercenary?.id == mercenary.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showMercenaryDetail(mercenary),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 상단 정보
                Row(
                  children: [
                    // 프로필 이미지
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFF0F0F0),
                          width: 1,
                        ),
                      ),
                      child: ClipOval(
                        child: mercenary.profileImageUrl != null
                            ? Image.network(
                                mercenary.profileImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.person, color: Color(0xFF999999)),
                              )
                            : const Icon(Icons.person, color: Color(0xFF999999)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 닉네임과 티어
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                mercenary.nickname,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              if (isMyProfile) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '내 프로필',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildTierBadge(mercenary.tier),
                              const SizedBox(width: 8),
                              if (mercenary.averageRating > 0) ...[
                                Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Colors.amber[600],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  mercenary.averageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF666666),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 매칭 요청 버튼
                    if (!isMyProfile)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showMatchingRequestDialog(mercenary),
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Text(
                                '매칭 요청',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // 포지션
                Row(
                  children: [
                    ...mercenary.preferredPositions.take(3).map((position) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LaneIconWidget(
                              lane: position.toLowerCase(),
                              size: 14,
                              color: const Color(0xFF666666),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getKoreanPosition(position),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF666666),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    if (mercenary.preferredPositions.length > 3)
                      Text(
                        '+${mercenary.preferredPositions.length - 3}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF999999),
                        ),
                      ),
                  ],
                ),
                // 자기소개
                if (mercenary.description != null && mercenary.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      mercenary.description!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTierBadge(PlayerTier tier) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: _getTierColor(tier).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _getTierName(tier),
        style: TextStyle(
          fontSize: 12,
          color: _getTierColor(tier),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  void _showMercenaryDetail(MercenaryModel mercenary) {
    context.push('/mercenaries/${mercenary.id}');
  }
  
  void _showMatchingRequestDialog(MercenaryModel mercenary) {
    final currentUser = Provider.of<AppStateProvider>(context, listen: false).currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${mercenary.nickname}님에게',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '매칭 요청을 보내시겠습니까?',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _sendMatchingRequest(mercenary);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '요청 보내기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _sendMatchingRequest(MercenaryModel mercenary) async {
    final currentUser = Provider.of<AppStateProvider>(context, listen: false).currentUser;
    if (currentUser == null) return;
    
    try {
      final request = MatchingRequestModel(
        id: '',
        fromUserId: currentUser.uid,
        fromUserNickname: currentUser.nickname,
        fromUserProfileUrl: currentUser.profileImageUrl,
        toUserId: mercenary.userUid,
        toUserNickname: mercenary.nickname,
        toUserProfileUrl: mercenary.profileImageUrl,
        status: MatchingRequestStatus.pending,
        createdAt: Timestamp.now(),
      );
      
      await FirebaseFirestore.instance
          .collection('matchingRequests')
          .add(request.toFirestore());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매칭 요청을 보냈습니다'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('요청 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
  
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
  
  Color _getTierColor(PlayerTier tier) {
    switch (tier) {
      case PlayerTier.iron: return const Color(0xFF5C5C5C);
      case PlayerTier.bronze: return const Color(0xFF8B4513);
      case PlayerTier.silver: return const Color(0xFF808080);
      case PlayerTier.gold: return const Color(0xFFFFD700);
      case PlayerTier.platinum: return const Color(0xFF00CED1);
      case PlayerTier.emerald: return const Color(0xFF50C878);
      case PlayerTier.diamond: return const Color(0xFF00BFFF);
      case PlayerTier.master: return const Color(0xFF9370DB);
      case PlayerTier.grandmaster: return const Color(0xFFDC143C);
      case PlayerTier.challenger: return const Color(0xFFFFD700);
      case PlayerTier.unranked: return const Color(0xFF999999);
    }
  }
}

// 듀오 찾기 뷰
class DuoFinderView extends StatefulWidget {
  const DuoFinderView({Key? key}) : super(key: key);

  @override
  State<DuoFinderView> createState() => _DuoFinderViewState();
}

class _DuoFinderViewState extends State<DuoFinderView> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  
  // 필터
  List<PlayerTier> _selectedTiers = [];
  List<String> _selectedPositions = [];
  bool _onlyMicEnabled = false;
  
  // 실시간 카운터
  int _onlineCount = 0;
  int _todayPostCount = 0;
  
  @override
  void initState() {
    super.initState();
    _loadStats();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  Future<void> _loadStats() async {
    try {
      // 온라인 사용자 수 - 단순화된 쿼리
      final onlineSnapshot = await FirebaseFirestore.instance
          .collection('duoPosts')
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .limit(100)
          .get()
          .catchError((error) {
            print('Error getting online users: $error');
            return null;
          });
      
      // 오늘 게시글 수 - 단순화된 쿼리
      final today = DateTime.now();
      final todayStart = Timestamp.fromDate(DateTime(today.year, today.month, today.day));
      final todaySnapshot = await FirebaseFirestore.instance
          .collection('duoPosts')
          .where('expiresAt', isGreaterThan: todayStart)
          .limit(100)
          .get()
          .catchError((error) {
            print('Error getting today posts: $error');
            return null;
          });
      
      if (mounted) {
        setState(() {
          _onlineCount = onlineSnapshot?.docs.length ?? 0;
          _todayPostCount = todaySnapshot?.docs.length ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading duo stats: $e');
      // 오류가 발생해도 기본값 유지
      if (mounted) {
        setState(() {
          _onlineCount = 0;
          _todayPostCount = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
      children: [
          // 상단 헤더 - 간소화
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 필터 버튼들 - 한 줄로 간소화
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // 티어 필터
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showTierFilter,
                borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedTiers.isEmpty
                                  ? const Color(0xFFF5F5F5)
                                  : AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedTiers.isEmpty
                                    ? Colors.transparent
                                    : AppColors.primary,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.military_tech,
                                  size: 16,
                                  color: _selectedTiers.isEmpty
                                      ? const Color(0xFF666666)
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedTiers.isEmpty
                                      ? '티어'
                                      : '티어 ${_selectedTiers.length}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedTiers.isEmpty
                                        ? const Color(0xFF666666)
                                        : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 포지션 필터
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showPositionFilter,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedPositions.isEmpty
                                  ? const Color(0xFFF5F5F5)
                                  : AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedPositions.isEmpty
                                    ? Colors.transparent
                                    : AppColors.primary,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.gamepad,
                                  size: 16,
                                  color: _selectedPositions.isEmpty
                                      ? const Color(0xFF666666)
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedPositions.isEmpty
                                      ? '포지션'
                                      : '포지션 ${_selectedPositions.length}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedPositions.isEmpty
                                        ? const Color(0xFF666666)
                                        : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 마이크 필터
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                setState(() {
                              _onlyMicEnabled = !_onlyMicEnabled;
                });
              },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _onlyMicEnabled
                                  ? AppColors.success.withOpacity(0.1)
                                  : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _onlyMicEnabled
                                    ? AppColors.success
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.mic,
                                  size: 16,
                                  color: _onlyMicEnabled
                                      ? AppColors.success
                                      : const Color(0xFF666666),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '마이크',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _onlyMicEnabled
                                        ? AppColors.success
                                        : const Color(0xFF666666),
                                  ),
            ),
          ],
        ),
                          ),
                        ),
                      ),
                      if (_selectedTiers.isNotEmpty || _selectedPositions.isNotEmpty || _onlyMicEnabled) ...[
                        const SizedBox(width: 16),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedTiers.clear();
                                _selectedPositions.clear();
                                _onlyMicEnabled = false;
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.clear,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 통계 정보 - 간소화
                Row(
                  children: [
        Expanded(
                      child: _buildStatCard(
                        icon: Icons.people,
                        label: '현재 접속',
                        value: '$_onlineCount명',
                        color: const Color(0xFF00FF00),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.article,
                        label: '오늘 게시글',
                        value: '$_todayPostCount개',
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Container(
            height: 1,
            color: const Color(0xFFF0F0F0),
          ),
          
          // 듀오 목록
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getDuoPostsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LoadingIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
        child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
          children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
            const SizedBox(height: 16),
                        const Text(
                          '게시글을 불러올 수 없습니다',
                  style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {});
                          },
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  );
                }
                
                final posts = snapshot.data?.docs ?? [];
                
                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
                        const Text(
                          '현재 듀오를 찾는 사람이 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF999999),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '첫 번째로 듀오를 찾아보세요!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFFBBBBBB),
              ),
            ),
          ],
      ),
    );
  }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final data = posts[index].data() as Map<String, dynamic>;
                    return _buildDuoCard(posts[index].id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDuoPostDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text(
          '듀오 찾기',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
          children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
              ),
            ),
          ],
          ),
        ],
      ),
    );
  }
  
  void _showTierFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                '티어 선택',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
                children: PlayerTier.values.where((t) => t != PlayerTier.unranked).map((tier) {
                  final isSelected = _selectedTiers.contains(tier);
                  return GestureDetector(
                    onTap: () {
                      setModalState(() {
                        if (isSelected) {
                          _selectedTiers.remove(tier);
                  } else {
                          _selectedTiers.add(tier);
                  }
                });
              },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _getTierColor(tier)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getTierName(tier),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF666666),
                        ),
                      ),
                    ),
            );
          }).toList(),
        ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '적용하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
  
  void _showPositionFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
      color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                '포지션 선택',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['탑', '정글', '미드', '원딜', '서폿'].map((position) {
                  final isSelected = _selectedPositions.contains(position);
                  return GestureDetector(
                    onTap: () {
                      setModalState(() {
                        if (isSelected) {
                          _selectedPositions.remove(position);
                        } else {
                          _selectedPositions.add(position);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
        child: Row(
                        mainAxisSize: MainAxisSize.min,
          children: [
                          LaneIconWidget(
                            lane: _getEnglishPosition(position).toLowerCase(),
                            size: 16,
                            color: isSelected ? Colors.white : const Color(0xFF666666),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            position,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF666666),
                            ),
            ),
          ],
        ),
      ),
    );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '적용하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
  
  Stream<QuerySnapshot> _getDuoPostsStream() {
    // 단순화된 쿼리 - 만료되지 않은 포스트만 가져오기
    return FirebaseFirestore.instance
        .collection('duoPosts')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .limit(50) // 최대 50개만 가져오기
        .snapshots()
        .handleError((error) {
          print('Error in duo posts stream: $error');
          // 에러 발생 시 빈 스트림 반환
          return Stream.empty();
        });
  }
  
  Widget _buildDuoCard(String postId, Map<String, dynamic> data) {
    final createdAt = (data['createdAt'] as Timestamp).toDate();
    final timeAgo = _getTimeAgo(createdAt);
    final currentUser = Provider.of<AppStateProvider>(context, listen: false).currentUser;
    final isMyPost = currentUser?.uid == data['uid'];
    final tier = PlayerTier.values[data['tier'] ?? 0];
    final isOnline = data['isOnline'] ?? false;
    final position = data['mainPosition'] ?? 'FILL';
    final micEnabled = data['micEnabled'] ?? false;
    
    // 클라이언트 사이드 필터링
    // 티어 필터
    if (_selectedTiers.isNotEmpty && !_selectedTiers.contains(tier)) {
      return const SizedBox.shrink();
    }
    
    // 포지션 필터링
    if (_selectedPositions.isNotEmpty && 
        !_selectedPositions.contains(_getKoreanPosition(position))) {
      return const SizedBox.shrink();
    }
    
    // 마이크 필터
    if (_onlyMicEnabled && !micEnabled) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
      ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
      child: InkWell(
          onTap: isMyPost ? null : () => _showDuoDetailDialog(data),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                    // 프로필 이미지와 온라인 상태
                    Stack(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _getTierColor(tier).withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: data['profileImageUrl'] != null
                                ? Image.network(
                                    data['profileImageUrl'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.person, color: Color(0xFF999999)),
                                  )
                                : const Icon(Icons.person, color: Color(0xFF999999)),
                          ),
                        ),
                        if (isOnline)
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FF00),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                              Text(
                                data['nickname'] ?? '알 수 없음',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            const SizedBox(width: 8),
                              // 티어 배지
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _getTierColor(tier).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getTierName(tier),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _getTierColor(tier),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isMyPost) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '내 글',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              // 포지션
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    LaneIconWidget(
                                      lane: position.toLowerCase() == 'fill' ? 'fill' : position.toLowerCase(),
                                      size: 12,
                                      color: const Color(0xFF666666),
                                    ),
                                    const SizedBox(width: 4),
                        Text(
                                      _getKoreanPosition(position),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF666666),
                                      ),
                        ),
                      ],
                    ),
                  ),
                              // 마이크
                              if (data['micEnabled'] == true) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                    decoration: BoxDecoration(
                                    color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.mic,
                                        size: 12,
                                        color: AppColors.success,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '마이크',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Text(
                                timeAgo,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF999999),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 액션 버튼
                    if (isMyPost)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFF999999),
                          size: 20,
                        ),
                        onPressed: () => _deleteDuoPost(postId),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _sendDuoMessage(data),
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                    ),
                    child: Text(
                                '메시지',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (data['content'] != null && data['content'].isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                    width: double.infinity,
                  padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  child: Text(
                      data['content'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                        height: 1.4,
                      ),
                  ),
                ),
              ],
                // 추가 정보 (조회수 등)
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.remove_red_eye_outlined,
                      size: 14,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${data['views'] ?? 0}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _showCreateDuoPostDialog() {
    final currentUser = Provider.of<AppStateProvider>(context, listen: false).currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }
    
    // 최근 게시물 확인 - 단순화된 쿼리
    FirebaseFirestore.instance
        .collection('duoPosts')
        .where('uid', isEqualTo: currentUser.uid)
        .limit(20) // 최근 20개만 가져오기
        .get()
        .then((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        // 클라이언트에서 정렬
        final posts = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'createdAt': (doc.data()['createdAt'] as Timestamp).toDate(),
          };
        }).toList();
        
        posts.sort((a, b) {
          final aDate = a['createdAt'] as DateTime;
          final bDate = b['createdAt'] as DateTime;
          return bDate.compareTo(aDate);
        });
        
        final lastPost = posts.first;
        final timeDiff = DateTime.now().difference(lastPost['createdAt'] as DateTime);
        
        if (timeDiff.inMinutes < 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${60 - timeDiff.inSeconds}초 후에 다시 작성할 수 있습니다'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      }
      
      _showDuoPostForm();
    }).catchError((error) {
      // 에러가 발생해도 폼을 보여줌
      print('Error checking recent posts: $error');
      _showDuoPostForm();
    });
  }
  
  void _showDuoPostForm() {
    final contentController = TextEditingController();
    String selectedPosition = 'FILL';
    bool micEnabled = false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
      child: Padding(
              padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
                  const Text(
                    '듀오 찾기',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '함께 게임할 듀오를 찾아보세요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 포지션 선택
                  const Text(
                    '주 포지션',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
            const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['TOP', 'JUNGLE', 'MID', 'ADC', 'SUPPORT', 'FILL'].map((pos) {
                      final isSelected = selectedPosition == pos;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedPosition = pos;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (pos != 'FILL')
                                LaneIconWidget(
                                  lane: pos.toLowerCase(),
                                  size: 16,
                                  color: isSelected ? Colors.white : const Color(0xFF666666),
                                ),
                              if (pos != 'FILL')
                                const SizedBox(width: 6),
            Text(
                                _getKoreanPosition(pos),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // 마이크 사용
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.mic,
                          color: micEnabled ? AppColors.success : const Color(0xFF999999),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '마이크 사용',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: micEnabled,
                          onChanged: (value) {
                            setState(() {
                              micEnabled = value;
                            });
                          },
                          activeColor: AppColors.primary,
                          inactiveThumbColor: const Color(0xFFDDDDDD),
                          inactiveTrackColor: const Color(0xFFF0F0F0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 내용
                  const Text(
                    '내용',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    maxLines: 3,
                    maxLength: 100,
                    decoration: InputDecoration(
                      hintText: '듀오에게 하고 싶은 말을 적어주세요',
                      hintStyle: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 버튼
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await _createDuoPost(
                              selectedPosition,
                              micEnabled,
                              contentController.text.trim(),
                            );
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            '등록하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Future<void> _createDuoPost(String position, bool micEnabled, String content) async {
    final currentUser = Provider.of<AppStateProvider>(context, listen: false).currentUser;
    if (currentUser == null) return;
    
    try {
      final now = Timestamp.now();
      await FirebaseFirestore.instance.collection('duoPosts').add({
        'uid': currentUser.uid,
        'nickname': currentUser.nickname,
        'profileImageUrl': currentUser.profileImageUrl,
        'tier': currentUser.tier.index,
        'mainPosition': position,
        'micEnabled': micEnabled,
        'content': content,
        'views': 0,
        'createdAt': now,
        'expiresAt': Timestamp.fromMillisecondsSinceEpoch(
          now.millisecondsSinceEpoch + const Duration(hours: 1).inMilliseconds,
        ),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('듀오 찾기 글이 등록되었습니다'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('등록 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
  
  void _deleteDuoPost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '듀오 찾기 삭제',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: const Text(
          '이 게시물을 삭제하시겠습니까?',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              '취소',
              style: TextStyle(
                color: Color(0xFF666666),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text(
              '삭제',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('duoPosts')
            .doc(postId)
            .delete();
            
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('게시물이 삭제되었습니다'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('삭제 실패: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
  
  void _showDuoDetailDialog(Map<String, dynamic> data) {
    // 프로필 상세 보기
    context.push('/profile/${data['uid']}');
  }
  
  void _sendDuoMessage(Map<String, dynamic> data) {
    // Direct Message 화면으로 이동
    context.push('/chat/direct?userId=${data['uid']}&nickname=${data['nickname']}');
  }
  
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${difference.inDays}일 전';
    }
  }
  
  String _getKoreanPosition(String position) {
    switch (position.toUpperCase()) {
      case 'TOP': return '탑';
      case 'JUNGLE': return '정글';
      case 'MID': return '미드';
      case 'ADC': return '원딜';
      case 'SUPPORT': return '서폿';
      case 'FILL': return '모든 포지션';
      default: return position;
    }
  }
  
  String _getEnglishPosition(String position) {
    switch (position) {
      case '탑': return 'TOP';
      case '정글': return 'JUNGLE';
      case '미드': return 'MID';
      case '원딜': return 'ADC';
      case '서폿': return 'SUPPORT';
      default: return position;
  }
}

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

Color _getTierColor(PlayerTier tier) {
  switch (tier) {
      case PlayerTier.iron: return const Color(0xFF5C5C5C);
      case PlayerTier.bronze: return const Color(0xFF8B4513);
      case PlayerTier.silver: return const Color(0xFF808080);
    case PlayerTier.gold: return const Color(0xFFFFD700);
      case PlayerTier.platinum: return const Color(0xFF00CED1);
    case PlayerTier.emerald: return const Color(0xFF50C878);
      case PlayerTier.diamond: return const Color(0xFF00BFFF);
    case PlayerTier.master: return const Color(0xFF9370DB);
      case PlayerTier.grandmaster: return const Color(0xFFDC143C);
      case PlayerTier.challenger: return const Color(0xFFFFD700);
      case PlayerTier.unranked: return const Color(0xFF999999);
    }
  }
}