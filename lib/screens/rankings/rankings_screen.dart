import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({Key? key}) : super(key: key);

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedTab = 0;
  
  // 경쟁전 랭킹 데이터
  List<Map<String, dynamic>> _competitiveRankings = [];
  
  // 클랜 랭킹 데이터
  List<Map<String, dynamic>> _clanRankings = [];
  
  bool _isLoadingCompetitive = false;
  bool _isLoadingClan = false;
  
  // 시즌 정보
  String _currentSeason = '2024 시즌 1';
  
  @override
  void initState() {
    super.initState();
    _loadCompetitiveRankings();
    _loadClanRankings();
  }
  
  Future<void> _loadCompetitiveRankings() async {
    setState(() => _isLoadingCompetitive = true);
    
    try {
      // 경쟁전 통계가 있는 사용자들을 가져옵니다
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('competitiveStats.totalGames', isGreaterThan: 0)
          .orderBy('competitiveStats.totalGames', descending: true)
          .limit(100)
          .get();
      
      final rankings = <Map<String, dynamic>>[];
      
      for (var doc in snapshot.docs) {
        final userData = doc.data();
        final stats = userData['competitiveStats'] ?? {};
        
        if (stats['totalGames'] != null && stats['totalGames'] > 0) {
          final winRate = stats['wins'] != null && stats['totalGames'] > 0
              ? (stats['wins'] / stats['totalGames'] * 100).toDouble()
              : 0.0;
          
          rankings.add({
            'uid': doc.id,
            'nickname': userData['nickname'] ?? '알 수 없음',
            'profileImageUrl': userData['profileImageUrl'],
            'tier': PlayerTier.values[userData['tier'] ?? 0],
            'totalGames': stats['totalGames'] ?? 0,
            'wins': stats['wins'] ?? 0,
            'losses': stats['losses'] ?? 0,
            'winRate': winRate,
            'rating': stats['rating'] ?? 1200,
            'position': userData['position'] ?? 'FILL',
          });
        }
      }
      
      // 레이팅 순으로 정렬
      rankings.sort((a, b) => b['rating'].compareTo(a['rating']));
      
      setState(() {
        _competitiveRankings = rankings;
        _isLoadingCompetitive = false;
      });
    } catch (e) {
      print('Error loading competitive rankings: $e');
      setState(() => _isLoadingCompetitive = false);
    }
  }
  
  Future<void> _loadClanRankings() async {
    setState(() => _isLoadingClan = true);
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clans')
          .orderBy('stats.totalPoints', descending: true)
          .limit(50)
          .get();
      
      final rankings = <Map<String, dynamic>>[];
      
      for (var doc in snapshot.docs) {
        final clanData = doc.data();
        final stats = clanData['stats'] ?? {};
        
        rankings.add({
          'id': doc.id,
          'name': clanData['name'] ?? '알 수 없음',
          'tag': clanData['tag'] ?? '',
          'emblemUrl': clanData['emblemUrl'],
          'memberCount': clanData['memberCount'] ?? 0,
          'totalPoints': stats['totalPoints'] ?? 0,
          'weeklyPoints': stats['weeklyPoints'] ?? 0,
          'level': clanData['level'] ?? 1,
          'description': clanData['description'] ?? '',
        });
      }
      
      setState(() {
        _clanRankings = rankings;
        _isLoadingClan = false;
      });
    } catch (e) {
      print('Error loading clan rankings: $e');
      setState(() => _isLoadingClan = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AppStateProvider>(context).currentUser;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // 토스 스타일 헤더
            _buildHeader(),
            
            // 시즌 정보
            _buildSeasonInfo(),
            
            // 탭 선택기
            _buildTabSelector(),
            
            // 내 순위 카드
            if (currentUser != null) _buildMyRankCard(currentUser),
            
            // 랭킹 리스트
            Expanded(
              child: _selectedTab == 0
                  ? _buildCompetitiveRankingList()
                  : _buildClanRankingList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF0F0F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
                  children: [
          const Text(
            '랭킹',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showFilterOptions,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.filter_list,
                size: 20,
                color: Color(0xFF666666),
              ),
            ),
          ),
                  ],
                ),
    );
  }
  
  Widget _buildSeasonInfo() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentSeason,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '시즌 종료까지 32일 남음',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '시즌 정보',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                      Icons.military_tech,
                      size: 18,
                      color: _selectedTab == 0
                          ? AppColors.primary
                          : const Color(0xFF999999),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '경쟁전 랭킹',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _selectedTab == 0
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.groups,
                      size: 18,
                      color: _selectedTab == 1
                          ? AppColors.primary
                          : const Color(0xFF999999),
            ),
                    const SizedBox(width: 6),
            Text(
                      '클랜 랭킹',
              style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _selectedTab == 1
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
          ],
        ),
      );
  }
  
  Widget _buildMyRankCard(UserModel currentUser) {
    // 내 순위 찾기
    int myRank = -1;
    Map<String, dynamic>? myData;
    
    if (_selectedTab == 0) {
      // 경쟁전 랭킹에서 내 순위 찾기
      for (int i = 0; i < _competitiveRankings.length; i++) {
        if (_competitiveRankings[i]['uid'] == currentUser.uid) {
          myRank = i + 1;
          myData = _competitiveRankings[i];
          break;
        }
      }
    }
    
    if (myRank == -1) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildRankBadge(myRank, isMyRank: true),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '내 순위',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentUser.nickname,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          if (myData != null) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${myData['rating']}점',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '승률 ${myData['winRate'].toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildCompetitiveRankingList() {
    if (_isLoadingCompetitive) {
      return const Center(child: LoadingIndicator());
    }
    
    if (_competitiveRankings.isEmpty) {
      return _buildEmptyState('경쟁전 랭킹 데이터가 없습니다');
    }
    
    return RefreshIndicator(
      onRefresh: _loadCompetitiveRankings,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        itemCount: _competitiveRankings.length,
        itemBuilder: (context, index) {
          final data = _competitiveRankings[index];
          final rank = index + 1;
          
          return _buildCompetitiveRankItem(rank, data);
        },
      ),
    );
  }
  
  Widget _buildCompetitiveRankItem(int rank, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          onTap: () => context.push('/profile/${data['uid']}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildRankBadge(rank),
                const SizedBox(width: 16),
                // 프로필 이미지
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _getTierColor(data['tier']).withOpacity(0.3),
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
                const SizedBox(width: 12),
                // 유저 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            data['nickname'],
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
                              color: _getTierColor(data['tier']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getTierName(data['tier']),
                              style: TextStyle(
                                fontSize: 11,
                                color: _getTierColor(data['tier']),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _getPositionIcon(data['position']),
                            size: 14,
                            color: const Color(0xFF666666),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getPositionName(data['position']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${data['totalGames']}전 ${data['wins']}승 ${data['losses']}패',
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
                // 레이팅 정보
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${data['rating']}',
              style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      '승률 ${data['winRate'].toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: data['winRate'] >= 50
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.w600,
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
  
  Widget _buildClanRankingList() {
    if (_isLoadingClan) {
      return const Center(child: LoadingIndicator());
    }
    
    if (_clanRankings.isEmpty) {
      return _buildEmptyState('클랜 랭킹 데이터가 없습니다');
    }
    
    return RefreshIndicator(
      onRefresh: _loadClanRankings,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        itemCount: _clanRankings.length,
        itemBuilder: (context, index) {
          final data = _clanRankings[index];
          final rank = index + 1;
          
          return _buildClanRankItem(rank, data);
        },
      ),
    );
  }
  
  Widget _buildClanRankItem(int rank, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          onTap: () => context.push('/clans/${data['id']}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildRankBadge(rank),
                const SizedBox(width: 16),
                // 클랜 엠블럼
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: data['emblemUrl'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            data['emblemUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.groups, color: Color(0xFF999999)),
                          ),
                        )
                      : const Icon(Icons.groups, color: Color(0xFF999999)),
                ),
                const SizedBox(width: 12),
                // 클랜 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            data['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '[${data['tag']}]',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Lv.${data['level']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 14,
                            color: Color(0xFF666666),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${data['memberCount']}명',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.local_fire_department,
                            size: 14,
                            color: Color(0xFFFF6B6B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '주간 ${data['weeklyPoints']}점',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 포인트 정보
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${data['totalPoints']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const Text(
                      '포인트',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
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
  
  Widget _buildRankBadge(int rank, {bool isMyRank = false}) {
    Color bgColor;
    Color textColor;
    IconData? icon;
    
    if (isMyRank) {
      bgColor = AppColors.primary;
      textColor = Colors.white;
    } else {
    switch (rank) {
      case 1:
          bgColor = const Color(0xFFFFD700);
          textColor = Colors.white;
          icon = Icons.emoji_events;
        break;
      case 2:
          bgColor = const Color(0xFFC0C0C0);
          textColor = Colors.white;
          icon = Icons.emoji_events;
        break;
      case 3:
          bgColor = const Color(0xFFCD7F32);
          textColor = Colors.white;
          icon = Icons.emoji_events;
        break;
      default:
          bgColor = const Color(0xFFF5F5F5);
          textColor = const Color(0xFF666666);
        break;
      }
    }
    
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: icon != null && rank <= 3
            ? Icon(
                icon,
                color: textColor,
                size: 24,
              )
            : Text(
          '$rank',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
      ),
    );
  }
  
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            message,
          style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showFilterOptions() {
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
              '필터 옵션',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 24),
            if (_selectedTab == 0) ...[
              _buildFilterOption(
                icon: Icons.military_tech,
                title: '티어별 보기',
                subtitle: '특정 티어의 랭킹만 표시',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 티어 필터 구현
                },
              ),
              _buildFilterOption(
                icon: Icons.gamepad,
                title: '포지션별 보기',
                subtitle: '특정 포지션의 랭킹만 표시',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 포지션 필터 구현
                },
              ),
            ] else ...[
              _buildFilterOption(
                icon: Icons.people,
                title: '멤버 수별 보기',
                subtitle: '클랜 규모에 따라 필터링',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 멤버 수 필터 구현
                },
              ),
              _buildFilterOption(
                icon: Icons.local_fire_department,
                title: '활동 점수별 보기',
                subtitle: '주간 활동 점수 기준 정렬',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 활동 점수 정렬 구현
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilterOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: const Color(0xFF666666),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFCCCCCC),
              size: 20,
            ),
          ],
        ),
      ),
    );
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
  
  IconData _getPositionIcon(String position) {
    switch (position.toUpperCase()) {
      case 'TOP': return Icons.shield;
      case 'JUNGLE': return Icons.forest;
      case 'MID': return Icons.flare;
      case 'ADC': return Icons.gps_fixed;
      case 'SUPPORT': return Icons.favorite;
      default: return Icons.help_outline;
    }
  }
  
  String _getPositionName(String position) {
    switch (position.toUpperCase()) {
      case 'TOP': return '탑';
      case 'JUNGLE': return '정글';
      case 'MID': return '미드';
      case 'ADC': return '원딜';
      case 'SUPPORT': return '서폿';
      case 'FILL': return '올라운더';
      default: return position;
    }
  }
} 