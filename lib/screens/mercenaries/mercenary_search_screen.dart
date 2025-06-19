import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MercenarySearchScreen extends StatefulWidget {
  const MercenarySearchScreen({Key? key}) : super(key: key);

  @override
  State<MercenarySearchScreen> createState() => _MercenarySearchScreenState();
}

class _MercenarySearchScreenState extends State<MercenarySearchScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  
  // 상태 관리
  bool _isLoading = false;
  String? _errorMessage;
  List<MercenaryModel> _mercenaries = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  
  // 필터링 관련 상태
  final List<String> _positions = ['TOP', 'JUNGLE', 'MID', 'ADC', 'SUPPORT'];
  Set<String> _selectedPositions = {};
  PlayerTier? _selectedTier;
  bool _isLoadingMore = false;
  
  @override
  void initState() {
    super.initState();
    _loadMercenaries();
  }
  
  // 용병 목록 로드
  Future<void> _loadMercenaries({bool refresh = false}) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      
      if (refresh) {
        _mercenaries = [];
        _lastDocument = null;
        _hasMoreData = true;
      }
      
      _errorMessage = null;
    });
    
    try {
      final result = await _firebaseService.getAvailableMercenaries(
        limit: 10,
        startAfter: _lastDocument,
        positions: _selectedPositions.isNotEmpty ? _selectedPositions.toList() : null,
        minTier: _selectedTier,
      );
      
      if (result.mercenaries.isNotEmpty) {
        setState(() {
          _mercenaries.addAll(result.mercenaries);
          _lastDocument = result.lastDocument;
          _hasMoreData = result.hasMore;
        });
      } else if (!refresh) {
        setState(() {
          _hasMoreData = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '용병 목록을 불러오는 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 추가 데이터 로드
  Future<void> _loadMoreMercenaries() async {
    if (_isLoadingMore || !_hasMoreData) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final result = await _firebaseService.getAvailableMercenaries(
        limit: 10,
        startAfter: _lastDocument,
        positions: _selectedPositions.isNotEmpty ? _selectedPositions.toList() : null,
        minTier: _selectedTier,
      );
      
      if (result.mercenaries.isNotEmpty) {
        setState(() {
          _mercenaries.addAll(result.mercenaries);
          _lastDocument = result.lastDocument;
          _hasMoreData = result.hasMore;
        });
      } else {
        setState(() {
          _hasMoreData = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '추가 데이터를 불러오는 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }
  
  // 1:1 메시지 보내기
  Future<void> _openDirectMessage(MercenaryModel mercenary) async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final currentUser = appState.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }
    
    if (currentUser.uid == mercenary.userUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자신에게는 메시지를 보낼 수 없습니다')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final dmRoom = await _firebaseService.findOrCreateDirectMessageRoom(
        currentUserId: currentUser.uid,
        currentUserName: currentUser.nickname,
        otherUserId: mercenary.userUid,
        otherUserName: mercenary.nickname,
        currentUserProfileUrl: currentUser.profileImageUrl,
        otherUserProfileUrl: mercenary.profileImageUrl,
      );
      
      if (dmRoom != null) {
        // 메시지 화면으로 이동
        context.push('/direct_message/${dmRoom.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메시지 룸을 생성하는데 실패했습니다')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  // 용병 등록 화면으로 이동
  void _navigateToRegistration() {
    context.push('/mercenary/register').then((value) {
      if (value != null) {
        _loadMercenaries(refresh: true);
      }
    });
  }
  
  // 용병 상세 화면으로 이동
  void _navigateToDetail(MercenaryModel mercenary) {
    context.push('/mercenary/${mercenary.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('용병 찾기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadMercenaries(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // 필터 바
          _buildFilterBar(),
          
          // 용병 목록
          Expanded(
            child: _isLoading && _mercenaries.isEmpty
                ? const LoadingIndicator()
                : _errorMessage != null
                    ? ErrorView(message: _errorMessage!)
                    : _mercenaries.isEmpty
                        ? _buildEmptyState()
                        : _buildMercenaryList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToRegistration,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  // 필터 바 위젯
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 포지션 필터
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '포지션:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...(_positions.map((position) {
                  final isSelected = _selectedPositions.contains(position);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(position),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedPositions.add(position);
                          } else {
                            _selectedPositions.remove(position);
                          }
                        });
                        _loadMercenaries(refresh: true);
                      },
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      checkmarkColor: AppColors.primary,
                    ),
                  );
                }).toList()),
              ],
            ),
          ),
          
          // 티어 필터
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '티어:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PlayerTier?>(
                    value: _selectedTier,
                    hint: const Text('전체'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<PlayerTier?>(
                        value: null,
                        child: Text('전체'),
                      ),
                      ...PlayerTier.values.map((tier) {
                        return DropdownMenuItem<PlayerTier?>(
                          value: tier,
                          child: Text(_getTierName(tier)),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedTier = value;
                      });
                      _loadMercenaries(refresh: true);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // 빈 상태 위젯
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '등록된 용병이 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '첫 번째 용병이 되어보세요!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToRegistration,
            icon: const Icon(Icons.add),
            label: const Text('용병 등록하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  // 용병 목록 위젯
  Widget _buildMercenaryList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent && _hasMoreData && !_isLoadingMore) {
          _loadMoreMercenaries();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _mercenaries.length + (_hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _mercenaries.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          final mercenary = _mercenaries[index];
          return _buildMercenaryCard(mercenary);
        },
      ),
    );
  }
  
  // 용병 카드 위젯
  Widget _buildMercenaryCard(MercenaryModel mercenary) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(mercenary),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필 이미지와 티어 배지
              Stack(
                children: [
                  mercenary.profileImageUrl != null && mercenary.profileImageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: mercenary.profileImageUrl!,
                          imageBuilder: (context, imageProvider) => CircleAvatar(
                            radius: 32,
                            backgroundImage: imageProvider,
                          ),
                          placeholder: (context, url) => const CircleAvatar(
                            radius: 32,
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => const CircleAvatar(
                            radius: 32,
                            backgroundImage: AssetImage('assets/images/profile_placeholder.png'),
                          ),
                        )
                      : const CircleAvatar(
                          radius: 32,
                          backgroundImage: AssetImage('assets/images/profile_placeholder.png'),
                        ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getTierColor(mercenary.tier),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        _getTierAbbreviation(mercenary.tier),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              
              // 정보 섹션
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 닉네임과 인적 정보
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
                        if (mercenary.demographicInfo != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              mercenary.demographicInfo!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // 포지션 정보
                    Row(
                      children: mercenary.preferredPositions.map((position) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              position,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 4),
                    
                    // 소개 텍스트
                    if (mercenary.description != null && mercenary.description!.isNotEmpty)
                      Text(
                        mercenary.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    const SizedBox(height: 4),
                    
                    // 가능 시간대
                    if (mercenary.availabilityTimeSlots.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          mercenary.availabilitySummary,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // 메시지 버튼
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.message,
                      color: AppColors.primary,
                    ),
                    onPressed: () => _openDirectMessage(mercenary),
                  ),
                  Text(
                    'DM',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ],
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
  
  // 헬퍼 메서드: 티어 약어 반환
  String _getTierAbbreviation(PlayerTier tier) {
    switch (tier) {
      case PlayerTier.iron: return 'I';
      case PlayerTier.bronze: return 'B';
      case PlayerTier.silver: return 'S';
      case PlayerTier.gold: return 'G';
      case PlayerTier.platinum: return 'P';
      case PlayerTier.emerald: return 'E';
      case PlayerTier.diamond: return 'D';
      case PlayerTier.master: return 'M';
      case PlayerTier.grandmaster: return 'GM';
      case PlayerTier.challenger: return 'C';
      case PlayerTier.unranked: return 'U';
    }
  }
  
  // 헬퍼 메서드: 티어 색상 반환
  Color _getTierColor(PlayerTier tier) {
    switch (tier) {
      case PlayerTier.iron: return Colors.grey.shade700;
      case PlayerTier.bronze: return Colors.brown;
      case PlayerTier.silver: return Colors.blueGrey;
      case PlayerTier.gold: return Colors.amber;
      case PlayerTier.platinum: return Colors.cyan.shade700;
      case PlayerTier.emerald: return Colors.green.shade600;
      case PlayerTier.diamond: return Colors.lightBlue;
      case PlayerTier.master: return Colors.purple;
      case PlayerTier.grandmaster: return Colors.red;
      case PlayerTier.challenger: return Colors.deepOrangeAccent;
      case PlayerTier.unranked: return Colors.grey;
    }
  }
} 