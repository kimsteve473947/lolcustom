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
import 'package:lol_custom_game_manager/widgets/lane_icon_widget.dart';

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
        // 필터 업데이트 - 명확한 TournamentType 사용
        _filters['tournamentType'] = _tabController.index == 0 
            ? TournamentType.casual.index 
            : TournamentType.competitive.index;
      });
      
      // 초기 데이터 로드
      _loadTournaments();
    });
    
    // 초기 필터 설정
    _filters['tournamentType'] = TournamentType.casual.index;
    
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
    'tournamentType': TournamentType.casual.index,  // 명확한 기본값 설정
    'showOnlyFuture': true, // 현재 시간 이후의 토너먼트만 표시
  };
  
  Future<void> _loadTournaments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final tournamentService = Provider.of<TournamentService>(context, listen: false);
      
      // 날짜 필터 적용 - selectedDate가 없으면 오늘 날짜 사용
      final DateTime filterDate = widget.selectedDate ?? DateTime.now();
      final startDate = DateTime(filterDate.year, filterDate.month, filterDate.day);
      final endDate = DateTime(filterDate.year, filterDate.month, filterDate.day, 23, 59, 59);
      
      _filters['startDate'] = startDate;
      _filters['endDate'] = endDate;
      
      final tournaments = await tournamentService.getTournaments(
        filters: _filters,
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
      
      // 마지막 대회 ID를 오프셋으로 사용
      final lastId = _tournaments.last.id;
      
      // 현재 필터 그대로 사용하여 추가 데이터 로드
      final tournaments = await tournamentService.getTournaments(
        filters: _filters, // 이미 showOnlyFuture가 포함되어 있음
        limit: 10,
      );
      
      setState(() {
        // 중복 제거 후 추가
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
        errorMessage: _errorMessage!,
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
    // 역할 순서 정의 (순서대로 표시하기 위함)
    final orderedRoles = ['top', 'jungle', 'mid', 'adc', 'support'];
    
    // 총 참가자 수와 총 슬롯 수 계산
    final totalParticipants = tournament.participants.length;
    final totalSlots = tournament.slotsByRole.values.fold(0, (sum, count) => sum + count);
    
    // 대회 이름에서 티어 정보 추출
    Map<String, String> tierInfo = {};
    
    // 티어 확인 함수
    void checkAndAddTier(String tierName, String iconPath, int tierRank) {
      if (tournament.title.toLowerCase().contains(tierName)) {
        tierInfo[tierName] = iconPath;
      }
    }
    
    // 티어 순위와 함께 각 티어 확인 (낮은 숫자가 낮은 티어)
    checkAndAddTier('아이언', 'assets/images/tiers/아이언로고.png', 1);
    checkAndAddTier('브론즈', 'assets/images/tiers/브론즈로고.png', 2);
    checkAndAddTier('실버', 'assets/images/tiers/실버로고.png', 3);
    checkAndAddTier('골드', 'assets/images/tiers/골드로고.png', 4);
    checkAndAddTier('플레티넘', 'assets/images/tiers/플레티넘로고.png', 5);
    checkAndAddTier('플래티넘', 'assets/images/tiers/플레티넘로고.png', 5);
    checkAndAddTier('에메랄드', 'assets/images/tiers/에메랄드로고.png', 6);
    checkAndAddTier('다이아', 'assets/images/tiers/다이아로고.png', 7);
    checkAndAddTier('마스터', 'assets/images/tiers/마스터로고.png', 8);
    
    // 티어 순서대로 정렬된 아이콘 경로 배열 생성
    List<String> tierIconPaths = [];
    
    // 순서대로 티어 아이콘 추가 (낮은 티어부터 높은 티어로)
    if (tierInfo.containsKey('아이언')) tierIconPaths.add('assets/images/tiers/아이언로고.png');
    if (tierInfo.containsKey('브론즈')) tierIconPaths.add('assets/images/tiers/브론즈로고.png');
    if (tierInfo.containsKey('실버')) tierIconPaths.add('assets/images/tiers/실버로고.png');
    if (tierInfo.containsKey('골드')) tierIconPaths.add('assets/images/tiers/골드로고.png');
    if (tierInfo.containsKey('플레티넘') || tierInfo.containsKey('플래티넘')) tierIconPaths.add('assets/images/tiers/플레티넘로고.png');
    if (tierInfo.containsKey('에메랄드')) tierIconPaths.add('assets/images/tiers/에메랄드로고.png');
    if (tierInfo.containsKey('다이아')) tierIconPaths.add('assets/images/tiers/다이아로고.png');
    if (tierInfo.containsKey('마스터')) tierIconPaths.add('assets/images/tiers/마스터로고.png');
    
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
          children: [
            // 상단 정보 (시간, 상태, 호스트)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('HH:mm', 'ko_KR').format(tournament.startsAt.toDate()),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
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
                  const SizedBox(height: 12),
                  Text(
                    tournament.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  // 티어 아이콘 표시
                  if (tierIconPaths.isNotEmpty)
                    SizedBox(
                      height: 24,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        children: tierIconPaths.map((path) => 
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Image.asset(
                              path,
                              width: 24,
                              height: 24,
                            ),
                          )
                        ).toList(),
                      ),
                    )
                  else if (tournament.title.toLowerCase().contains('랜덤'))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '랜덤',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
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
                      const Text(
                        '참가 현황',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$totalParticipants/$totalSlots',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getParticipantCountColor(totalParticipants, totalSlots),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // 각 역할별 인원 표시 (순서대로)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: orderedRoles.map((role) {
                      final totalForRole = tournament.slotsByRole[role] ?? 2;
                      final filledForRole = tournament.filledSlotsByRole[role] ?? 0;
                      
                      return Column(
                        children: [
                          LaneIconWidget(
                            lane: role,
                            size: 36, // 아이콘 크기 증가
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$filledForRole/$totalForRole',
                            style: TextStyle(
                              fontSize: 14, // 폰트 크기 증가
                              fontWeight: FontWeight.bold,
                              color: _getParticipantCountColor(filledForRole, totalForRole),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  
                  // 전체 진행 상황 표시 바
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalSlots > 0 ? totalParticipants / totalSlots : 0,
                      backgroundColor: Colors.grey.shade200,
                      color: _getProgressBarColor(totalParticipants, totalSlots),
                      minHeight: 8, // 프로그레스 바 높이 증가
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
  
  // 참가자 수에 따른 색상 변경
  Color _getParticipantCountColor(int filled, int total) {
    if (filled == 0) return Colors.black;  // 0/2: 검정색
    if (filled < total) return Colors.amber.shade700;  // 1/2: 노란색
    return Colors.red;  // 2/2: 빨간색
  }
  
  // 프로그레스 바 색상
  Color _getProgressBarColor(int filled, int total) {
    if (filled == 0) return Colors.grey.shade700;
    if (filled < total) return Colors.amber.shade700;
    return Colors.red;
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