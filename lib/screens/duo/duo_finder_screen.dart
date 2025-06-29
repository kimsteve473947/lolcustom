import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/widgets/lane_icon_widget.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:go_router/go_router.dart';

class DuoFinderScreen extends StatefulWidget {
  const DuoFinderScreen({Key? key}) : super(key: key);

  @override
  State<DuoFinderScreen> createState() => _DuoFinderScreenState();
}

class _DuoFinderScreenState extends State<DuoFinderScreen> with TickerProviderStateMixin {
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
      final onlineSnapshot = await FirebaseFirestore.instance
          .collection('duoPosts')
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .limit(100)
          .get()
          .catchError((error) {
            print('Error getting online users: $error');
            return null;
          });
      
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '듀오 찾기',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF1A1A1A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () {
            // 뒤로가기: 내전 화면으로 이동
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/tournaments');
            }
          },
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Container(
            height: 1,
            color: const Color(0xFFF0F0F0),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getDuoPostsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LoadingIndicator());
                }
                
                if (snapshot.hasError) {
                  return _buildErrorView();
                }
                
                final posts = snapshot.data?.docs ?? [];
                
                if (posts.isEmpty) {
                  return _buildEmptyView();
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

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 필터 버튼들
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterButton(
                  icon: Icons.military_tech,
                  label: _selectedTiers.isEmpty ? '티어' : '티어 ${_selectedTiers.length}',
                  isSelected: _selectedTiers.isNotEmpty,
                  onTap: _showTierFilter,
                ),
                const SizedBox(width: 8),
                _buildFilterButton(
                  icon: Icons.gamepad,
                  label: _selectedPositions.isEmpty ? '포지션' : '포지션 ${_selectedPositions.length}',
                  isSelected: _selectedPositions.isNotEmpty,
                  onTap: _showPositionFilter,
                ),
                const SizedBox(width: 8),
                _buildFilterButton(
                  icon: Icons.mic,
                  label: '마이크',
                  isSelected: _onlyMicEnabled,
                  onTap: () {
                    setState(() {
                      _onlyMicEnabled = !_onlyMicEnabled;
                    });
                  },
                  color: _onlyMicEnabled ? AppColors.success : null,
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
          // 통계 정보
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
    );
  }

  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final buttonColor = color ?? AppColors.primary;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? buttonColor.withOpacity(0.1)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? buttonColor : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? buttonColor : const Color(0xFF666666),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? buttonColor : const Color(0xFF666666),
                ),
              ),
            ],
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

  Widget _buildErrorView() {
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

  Widget _buildEmptyView() {
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

  Stream<QuerySnapshot> _getDuoPostsStream() {
    // 인덱스 오류를 방지하기 위해 간단한 쿼리 사용
    return FirebaseFirestore.instance
        .collection('duoPosts')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .limit(50)
        .snapshots()
        .handleError((error) {
          print('Error in duo posts stream: $error');
        });
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
                          color: isSelected ? Colors.white : const Color(0xFF666666),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedTiers.clear();
                        });
                        setState(() {});
                        Navigator.pop(context);
                      },
                      child: const Text('초기화'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('적용'),
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

  void _showPositionFilter() {
    final positions = ['탑', '정글', '미드', '원딜', '서폿'];
    
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
                children: positions.map((position) {
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
                              color: isSelected ? Colors.white : const Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedPositions.clear();
                        });
                        setState(() {});
                        Navigator.pop(context);
                      },
                      child: const Text('초기화'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('적용'),
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

  Widget _buildDuoCard(String postId, Map<String, dynamic> data) {
    final createdAt = (data['createdAt'] as Timestamp).toDate();
    final timeAgo = _getTimeAgo(createdAt);
    final currentUser = Provider.of<AppStateProvider>(context, listen: false).currentUser;
    final isMyPost = currentUser?.uid == data['uid'];
    final tier = PlayerTier.values[data['tier'] ?? 0];
    final position = data['mainPosition'] ?? 'FILL';
    final micEnabled = data['micEnabled'] ?? false;
    
    // 클라이언트 사이드 필터링
    if (_selectedTiers.isNotEmpty && !_selectedTiers.contains(tier)) {
      return const SizedBox.shrink();
    }
    
    if (_selectedPositions.isNotEmpty && 
        !_selectedPositions.contains(_getKoreanPosition(position))) {
      return const SizedBox.shrink();
    }
    
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
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _getTierColor(tier).withOpacity(0.2),
                      backgroundImage: data['profileImageUrl'] != null
                          ? NetworkImage(data['profileImageUrl'])
                          : null,
                      child: data['profileImageUrl'] == null
                          ? Icon(Icons.person, color: _getTierColor(tier))
                          : null,
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
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
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
                              if (micEnabled) ...[
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
    
    _showDuoPostForm();
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
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '내용',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: contentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '듀오에게 하고 싶은 말을 적어주세요',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소'),
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
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('등록하기'),
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
        title: const Text('게시물 삭제'),
        content: const Text('정말로 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
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
    context.push('/profile/${data['uid']}');
  }
  
  void _sendDuoMessage(Map<String, dynamic> data) {
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