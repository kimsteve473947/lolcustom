import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/tournament_card.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lol_custom_game_manager/services/tournament_service.dart';
import 'package:lol_custom_game_manager/widgets/tournament_card_simplified.dart';
import 'package:lol_custom_game_manager/screens/tournaments/tournament_main_screen.dart';

class MatchListTab extends StatefulWidget {
  final DateTime? selectedDate;
  
  const MatchListTab({
    Key? key,
    this.selectedDate,
  }) : super(key: key);

  @override
  State<MatchListTab> createState() => _MatchListTabState();
}

class _MatchListTabState extends State<MatchListTab> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final TournamentService _tournamentService = TournamentService();
  
  late TabController _tabController;
  
  bool _isLoading = false;
  String? _errorMessage;
  List<TournamentModel> _tournaments = [];
  
  // Scroll controllers for pagination
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Set up scroll listeners for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
          !_isLoading &&
          _tournaments.isNotEmpty) {
        _loadMoreTournaments();
      }
    });
    
    // 탭 변경 리스너
    _tabController.addListener(() {
      setState(() {
        // 필터 업데이트
        _filters['tournamentType'] = _tabController.index == 0 ? TournamentType.casual.index : TournamentType.competitive.index;
      });
      
      // 초기 데이터 로드
      _loadTournaments();
    });
    
    // 초기 데이터 로드
    _loadTournaments();
  }
  
  @override
  void didUpdateWidget(MatchListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 날짜가 변경되었으면 대회 목록 다시 로드
    if (widget.selectedDate != oldWidget.selectedDate) {
      _loadTournaments();
    }
  }

  // 필터 설정
  final Map<String, dynamic> _filters = {
    'tournamentType': null,  // null: 모두, int: 일반전만, int: 경쟁전만
  };
  
  Future<void> _loadTournaments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final tournamentService = Provider.of<TournamentService>(context, listen: false);
      
      // 날짜 필터 적용
      if (widget.selectedDate != null) {
        final startDate = DateTime(widget.selectedDate!.year, widget.selectedDate!.month, widget.selectedDate!.day);
        final endDate = DateTime(widget.selectedDate!.year, widget.selectedDate!.month, widget.selectedDate!.day, 23, 59, 59);
        
        _filters['startDate'] = startDate;
        _filters['endDate'] = endDate;
      }
      
      final tournaments = await tournamentService.getTournaments(
        filters: _filters,
        orderBy: 'startsAt',
        descending: false,
      );
      
      setState(() {
        _tournaments = tournaments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '내전 목록을 불러오는 중 오류가 발생했습니다: $e';
      });
    }
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // 더 많은 대회 로드 (페이지네이션)
  Future<void> _loadMoreTournaments() async {
    if (_isLoading || _tournaments.isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final tournamentService = Provider.of<TournamentService>(context, listen: false);
      
      // Use limit and offset-based pagination instead of cursor-based pagination
      final tournaments = await tournamentService.getTournaments(
        filters: _filters,
        orderBy: 'startsAt',
        descending: false,
        limit: 10,
      );
      
      setState(() {
        // Only add tournaments that aren't already in the list (to avoid duplicates)
        for (final tournament in tournaments) {
          if (!_tournaments.any((t) => t.id == tournament.id)) {
            _tournaments.add(tournament);
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTournamentsList(),
                _buildTournamentsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppColors.primary,
      unselectedLabelColor: Colors.grey,
      indicatorColor: AppColors.primary,
      tabs: const [
        Tab(text: '일반전'),
        Tab(text: '경쟁전'),
      ],
    );
  }
  
  Widget _buildTournamentsList() {
    if (_errorMessage != null) {
      return ErrorView(
        message: _errorMessage!,
        onRetry: _loadTournaments,
      );
    }
    
    if (_isLoading && _tournaments.isEmpty) {
      return const LoadingIndicator();
    }
    
    if (_tournaments.isEmpty) {
      return _buildEmptyState();
    }
    
    return RefreshIndicator(
      onRefresh: _loadTournaments,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _tournaments.length + (_isLoading ? 1 : 0),
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          if (index == _tournaments.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          
          final tournament = _tournaments[index];
          return _buildTournamentCard(tournament);
        },
      ),
    );
  }
  
  Widget _buildEmptyState() {
    String message = widget.selectedDate != null
        ? '${DateFormat('M월 d일', 'ko_KR').format(widget.selectedDate!)}에 예정된 내전이 없습니다'
        : '예정된 내전이 없습니다';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.push('/tournaments/create');
            },
            icon: const Icon(Icons.add),
            label: const Text('내전 만들기'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTournamentCard(TournamentModel tournament) {
    // 역할 아이콘 맵
    final roleIcons = {
      'top': Icons.arrow_upward,
      'jungle': Icons.nature_people,
      'mid': Icons.adjust,
      'adc': Icons.gps_fixed,
      'support': Icons.shield,
    };
    
    // 역할 색상 맵
    final roleColors = {
      'top': AppColors.roleTop,
      'jungle': AppColors.roleJungle,
      'mid': AppColors.roleMid,
      'adc': AppColors.roleAdc,
      'support': AppColors.roleSupport,
    };
    
    // 총 참가자 수와 총 슬롯 수 계산
    final totalParticipants = tournament.participants.length;
    final totalSlots = tournament.slotsByRole.values.fold(0, (sum, count) => sum + count);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          context.push('/tournaments/${tournament.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 정보 (시간, 상태, 호스트)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('M월 d일 (E) HH:mm', 'ko_KR').format(tournament.startsAt.toDate()),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(tournament.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusText(tournament.status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(tournament.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tournament.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: tournament.hostProfileImageUrl != null
                            ? NetworkImage(tournament.hostProfileImageUrl!)
                            : null,
                        child: tournament.hostProfileImageUrl == null
                            ? const Icon(Icons.person, size: 12)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tournament.hostNickname ?? tournament.hostName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 참가자 진행 상황 표시
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 총 참가자 수 표시
                  Row(
                    children: [
                      Text(
                        '참가 현황',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$totalParticipants/$totalSlots',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // 각 역할별 인원 표시
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: tournament.slotsByRole.entries.map((entry) {
                      final role = entry.key;
                      final totalForRole = entry.value;
                      final filledForRole = tournament.filledSlotsByRole[role] ?? 0;
                      
                      return Expanded(
                        child: Column(
                          children: [
                            Icon(
                              roleIcons[role],
                              color: roleColors[role],
                              size: 16,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$filledForRole/$totalForRole',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: filledForRole == totalForRole
                                    ? AppColors.success
                                    : roleColors[role],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  
                  // 전체 진행 상황 표시 바
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalSlots > 0 ? totalParticipants / totalSlots : 0,
                      backgroundColor: Colors.grey.shade200,
                      color: AppColors.primary,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getStatusText(TournamentStatus status) {
    switch (status) {
      case TournamentStatus.draft:
        return '초안';
      case TournamentStatus.open:
        return '모집 중';
      case TournamentStatus.full:
        return '모집 완료';
      case TournamentStatus.inProgress:
      case TournamentStatus.ongoing:
        return '진행 중';
      case TournamentStatus.completed:
        return '완료됨';
      case TournamentStatus.cancelled:
        return '취소됨';
    }
  }
  
  Color _getStatusColor(TournamentStatus status) {
    switch (status) {
      case TournamentStatus.draft:
        return Colors.grey;
      case TournamentStatus.open:
        return AppColors.success;
      case TournamentStatus.full:
        return AppColors.primary;
      case TournamentStatus.inProgress:
      case TournamentStatus.ongoing:
        return AppColors.warning;
      case TournamentStatus.completed:
        return AppColors.textSecondary;
      case TournamentStatus.cancelled:
        return AppColors.error;
    }
  }
} 