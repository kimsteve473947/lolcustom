import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({Key? key}) : super(key: key);

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = false;
  String? _errorMessage;
  List<UserModel> _topRatedUsers = [];
  List<MercenaryModel> _topMercenaries = [];
  
  late TabController _tabController;
  String _selectedTier = '전체';
  String _selectedPosition = '전체';
  String _selectedPeriod = '전체 기간';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _loadData();
      }
    });
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      if (_tabController.index == 0) {
        // Load top rated users
        // This is a placeholder until we implement the actual rating logic
        final users = await _getMockTopUsers();
        setState(() {
          _topRatedUsers = users;
          _isLoading = false;
        });
      } else {
        // Load top mercenaries
        // This is a placeholder until we implement the actual rating logic
        final mercenaries = await _getMockTopMercenaries();
        setState(() {
          _topMercenaries = mercenaries;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load rankings: $e';
      });
    }
  }
  
  // TODO: Replace with actual API calls
  Future<List<UserModel>> _getMockTopUsers() async {
    await Future.delayed(const Duration(milliseconds: 800));
    
    final List<UserModel> mockUsers = [];
    for (int i = 1; i <= 20; i++) {
      mockUsers.add(
        UserModel(
          uid: 'user$i',
          nickname: '플레이어$i',
          tier: i <= 3 ? 'Diamond' : (i <= 10 ? 'Platinum' : 'Gold'),
          averageRating: 5 - (i * 0.15),
          joinedAt: Timestamp.now(),
          profileImageUrl: i % 3 == 0 ? 'https://via.placeholder.com/150' : null,
        ),
      );
    }
    
    return mockUsers;
  }
  
  Future<List<MercenaryModel>> _getMockTopMercenaries() async {
    await Future.delayed(const Duration(milliseconds: 800));
    
    final List<MercenaryModel> mockMercenaries = [];
    for (int i = 1; i <= 20; i++) {
      mockMercenaries.add(
        MercenaryModel(
          id: 'merc$i',
          userUid: 'user$i',
          nickname: '용병$i',
          tier: i <= 3 ? 'Diamond' : (i <= 10 ? 'Platinum' : 'Gold'),
          roleStats: {
            'top': 70 + (20 - i),
            'jungle': 65 + (20 - i),
            'mid': 75 + (20 - i),
            'adc': 80 + (20 - i),
            'support': 60 + (20 - i),
          },
          skillStats: {
            'teamwork': 70 + (20 - i),
            'pass': 75 + (20 - i),
            'vision': 65 + (20 - i),
          },
          preferredPositions: const ['top', 'mid'],
          averageRating: 5 - (i * 0.15),
          createdAt: Timestamp.now(),
          profileImageUrl: i % 3 == 0 ? 'https://via.placeholder.com/150' : null,
        ),
      );
    }
    
    return mockMercenaries;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '랭킹',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: '플레이어 랭킹'),
            Tab(text: '용병 랭킹'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _errorMessage != null
                ? ErrorView(
                    message: _errorMessage!,
                    onRetry: _loadData,
                  )
                : _isLoading
                    ? const LoadingIndicator()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildUserRankings(),
                          _buildMercenaryRankings(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilters() {
    final List<String> tiers = ['전체', 'Challenger', 'Grandmaster', 'Master', 'Diamond', 'Platinum', 'Gold', 'Silver', 'Bronze', 'Iron'];
    final List<String> positions = ['전체', 'Top', 'Jungle', 'Mid', 'ADC', 'Support'];
    final List<String> periods = ['전체 기간', '이번 주', '이번 달', '이번 시즌'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Row(
            children: [
              const Text('티어: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedTier,
                  isExpanded: true,
                  underline: Container(height: 1, color: AppColors.divider),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedTier = newValue;
                      });
                      _loadData();
                    }
                  },
                  items: tiers.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('포지션: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedPosition,
                  isExpanded: true,
                  underline: Container(height: 1, color: AppColors.divider),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedPosition = newValue;
                      });
                      _loadData();
                    }
                  },
                  items: positions.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('기간: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedPeriod,
                  isExpanded: true,
                  underline: Container(height: 1, color: AppColors.divider),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedPeriod = newValue;
                      });
                      _loadData();
                    }
                  },
                  items: periods.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildUserRankings() {
    if (_topRatedUsers.isEmpty) {
      return const Center(
        child: Text(
          '랭킹 데이터가 없습니다',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _topRatedUsers.length,
      itemBuilder: (context, index) {
        final user = _topRatedUsers[index];
        return _buildRankingItem(
          rank: index + 1,
          name: user.nickname,
          profileImage: user.profileImageUrl,
          tier: user.tier,
          rating: user.averageRating,
          highlight: index < 3,
        );
      },
    );
  }
  
  Widget _buildMercenaryRankings() {
    if (_topMercenaries.isEmpty) {
      return const Center(
        child: Text(
          '랭킹 데이터가 없습니다',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _topMercenaries.length,
      itemBuilder: (context, index) {
        final mercenary = _topMercenaries[index];
        return _buildRankingItem(
          rank: index + 1,
          name: mercenary.nickname,
          profileImage: mercenary.profileImageUrl,
          tier: mercenary.tier,
          rating: mercenary.averageRating,
          highlight: index < 3,
          roleStats: mercenary.roleStats,
          bestRole: mercenary.topRole,
        );
      },
    );
  }
  
  Widget _buildRankingItem({
    required int rank,
    required String name,
    String? profileImage,
    String? tier,
    double? rating,
    bool highlight = false,
    Map<String, int>? roleStats,
    String? bestRole,
  }) {
    Color rankColor;
    Widget rankWidget;
    
    if (rank == 1) {
      rankColor = Colors.amber;
      rankWidget = const Icon(Icons.emoji_events, color: Colors.amber);
    } else if (rank == 2) {
      rankColor = Colors.blueGrey.shade300;
      rankWidget = const Icon(Icons.emoji_events, color: Colors.blueGrey);
    } else if (rank == 3) {
      rankColor = Colors.brown.shade300;
      rankWidget = const Icon(Icons.emoji_events, color: Colors.brown);
    } else {
      rankColor = AppColors.textSecondary;
      rankWidget = Text(
        '$rank',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      );
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: highlight ? 2 : 1,
      color: highlight ? Colors.white : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Center(
                child: rankWidget,
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 20,
              backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
              child: profileImage == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (tier != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tier,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (bestRole != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            bestRole,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (rating != null) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (roleStats != null && roleStats.containsKey(_selectedPosition.toLowerCase()) && _selectedPosition != '전체')
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${roleStats[_selectedPosition.toLowerCase()]}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 