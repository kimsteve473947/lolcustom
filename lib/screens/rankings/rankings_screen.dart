import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({Key? key}) : super(key: key);

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late TabController _tabController;
  
  bool _isLoading = false;
  String? _errorMessage;
  List<UserModel> _topRatedUsers = [];
  List<UserModel> _topHostingUsers = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRankings();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadRankings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // In a real implementation, you would use a dedicated ranking service
      // For now, we're just mocking the data with some users from Firebase
      final users = await _firebaseService.fetchTopUsers(limit: 20);
      
      // Sort by average rating for top rated users
      final topRated = List<UserModel>.from(users);
      topRated.sort((a, b) => (b.averageRating ?? 0).compareTo(a.averageRating ?? 0));
      
      // Sort by tournaments hosted count for top hosting users
      final topHosting = List<UserModel>.from(users);
      topHosting.sort((a, b) => (b.hostedTournamentsCount ?? 0).compareTo(a.hostedTournamentsCount ?? 0));
      
      setState(() {
        _topRatedUsers = topRated;
        _topHostingUsers = topHosting;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '랭킹 정보를 불러오는 중 오류가 발생했습니다: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('랭킹'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '평점 랭킹'),
            Tab(text: '내전 개최 랭킹'),
          ],
        ),
      ),
      body: _errorMessage != null
          ? ErrorView(
              errorMessage: _errorMessage!,
              onRetry: _loadRankings,
            )
          : _isLoading
              ? const LoadingIndicator()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRankingList(_topRatedUsers, (user) => user.averageRating ?? 0, '평점'),
                    _buildRankingList(_topHostingUsers, (user) => user.hostedTournamentsCount?.toDouble() ?? 0, '개최 수'),
                  ],
                ),
    );
  }
  
  Widget _buildRankingList(List<UserModel> users, double Function(UserModel) valueGetter, String valueSuffix) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '랭킹 정보가 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadRankings,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final rank = index + 1;
          final value = valueGetter(user);
          
          return ListTile(
            leading: _buildRankIndicator(rank),
            title: Text(
              user.nickname,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(user.position ?? '포지션 미설정'),
            trailing: Text(
              valueSuffix == '평점' ? '$value' : '${value.toInt()}$valueSuffix',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            onTap: () {
              // Navigate to user profile
            },
          );
        },
      ),
    );
  }
  
  Widget _buildRankIndicator(int rank) {
    Color color;
    switch (rank) {
      case 1:
        color = Colors.amber; // Gold
        break;
      case 2:
        color = Colors.blueGrey.shade300; // Silver
        break;
      case 3:
        color = Colors.brown.shade300; // Bronze
        break;
      default:
        color = Colors.grey.shade400;
        break;
    }
    
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$rank',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
} 