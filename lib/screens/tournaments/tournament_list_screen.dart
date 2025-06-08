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

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({Key? key}) : super(key: key);

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final TournamentService _tournamentService = TournamentService();
  
  late TabController _tabController;
  
  bool _isLoading = false;
  String? _errorMessage;
  List<TournamentModel> _freeTournaments = [];
  List<TournamentModel> _paidTournaments = [];
  bool _hasMoreFreeTournaments = true;
  bool _hasMorePaidTournaments = true;
  DocumentSnapshot? _lastFreeDocument;
  DocumentSnapshot? _lastPaidDocument;
  
  // Filters
  bool _ovrToggle = false;
  DateTime? _selectedDate;
  int _currentDateIndex = 0;
  
  // Scroll controllers for pagination
  final ScrollController _freeScrollController = ScrollController();
  final ScrollController _paidScrollController = ScrollController();

  // 필터 설정
  final Map<String, dynamic> _filters = {
    'isPaid': null,  // null: 모두, true: 유료만, false: 무료만
    'ovrLimit': null,  // null: 제한 없음, int: 제한 값
    'premiumBadge': null,  // null: 모두, true: 프리미엄만
  };
  
  // 날짜 범위
  DateTime? _startDate;
  DateTime? _endDate;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 무료 내전 로드
    _loadFreeTournaments();
    
    // 유료 내전 로드
    _loadPaidTournaments();
    
    // Set up scroll listeners for pagination
    _freeScrollController.addListener(() {
      if (_freeScrollController.position.pixels >= _freeScrollController.position.maxScrollExtent * 0.8 &&
          !_isLoading &&
          _hasMoreFreeTournaments) {
        _loadMoreFreeTournaments();
      }
    });
    
    _paidScrollController.addListener(() {
      if (_paidScrollController.position.pixels >= _paidScrollController.position.maxScrollExtent * 0.8 &&
          !_isLoading &&
          _hasMorePaidTournaments) {
        _loadMorePaidTournaments();
      }
    });
    
    // 탭 변경 리스너
    _tabController.addListener(() {
      setState(() {
        // 필터 업데이트
        _filters['isPaid'] = _tabController.index == 0 ? false : true;
      });
    });
  }

  @override
  void dispose() {
    _freeScrollController.dispose();
    _paidScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // 무료 내전 로드
  Future<void> _loadFreeTournaments() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 날짜 필터 적용
      Map<String, dynamic> filterMap = {..._filters, 'isPaid': false, 'showOnlyFuture': true};
      if (_startDate != null && _endDate != null) {
        filterMap['startDate'] = _startDate;
        filterMap['endDate'] = _endDate;
      }
      
      final tournaments = await _tournamentService.getTournaments(
        limit: 20,
        filters: filterMap,
      );
      
      DocumentSnapshot? lastDoc;
      if (tournaments.isNotEmpty) {
        lastDoc = await FirebaseFirestore.instance
            .collection('tournaments')
            .doc(tournaments.last.id)
            .get();
      }
      
      setState(() {
        _freeTournaments = tournaments;
        _isLoading = false;
        _hasMoreFreeTournaments = tournaments.length == 20;
        _lastFreeDocument = lastDoc;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        // 에러 메시지 개선
        if (e.toString().contains('index') && e.toString().contains('failed-precondition')) {
          _errorMessage = '필터링에 필요한 인덱스가 생성 중입니다. 잠시 후 다시 시도해주세요.';
        } else {
          _errorMessage = '내전 목록을 불러오는 중 오류가 발생했습니다: ${e.toString().split(']').last.trim()}';
        }
      });
      
      // 에러 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('index') 
                ? '필터링에 필요한 인덱스가 생성 중입니다. 잠시 후 다시 시도해주세요.'
                : '에러가 발생했습니다: ${e.toString().split(']').last.trim()}'
          ),
          action: SnackBarAction(
            label: '다시 시도',
            onPressed: _loadFreeTournaments,
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
  
  // 유료 내전 로드
  Future<void> _loadPaidTournaments() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 날짜 필터 적용
      Map<String, dynamic> filterMap = {..._filters, 'isPaid': true, 'showOnlyFuture': true};
      if (_startDate != null && _endDate != null) {
        filterMap['startDate'] = _startDate;
        filterMap['endDate'] = _endDate;
      }
      
      final tournaments = await _tournamentService.getTournaments(
        limit: 20,
        filters: filterMap,
      );
      
      DocumentSnapshot? lastDoc;
      if (tournaments.isNotEmpty) {
        lastDoc = await FirebaseFirestore.instance
            .collection('tournaments')
            .doc(tournaments.last.id)
            .get();
      }
      
      setState(() {
        _paidTournaments = tournaments;
        _isLoading = false;
        _hasMorePaidTournaments = tournaments.length == 20;
        _lastPaidDocument = lastDoc;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        // 에러 메시지 개선
        if (e.toString().contains('index') && e.toString().contains('failed-precondition')) {
          _errorMessage = '필터링에 필요한 인덱스가 생성 중입니다. 잠시 후 다시 시도해주세요.';
        } else {
          _errorMessage = '내전 목록을 불러오는 중 오류가 발생했습니다: ${e.toString().split(']').last.trim()}';
        }
      });
      
      // 에러 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('index') 
                ? '필터링에 필요한 인덱스가 생성 중입니다. 잠시 후 다시 시도해주세요.'
                : '에러가 발생했습니다: ${e.toString().split(']').last.trim()}'
          ),
          action: SnackBarAction(
            label: '다시 시도',
            onPressed: _loadPaidTournaments,
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // 무료 내전 추가 로드
  Future<void> _loadMoreFreeTournaments() async {
    if (_isLoading || !_hasMoreFreeTournaments || _lastFreeDocument == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final tournaments = await _tournamentService.getTournaments(
        limit: 20,
        startAfter: _lastFreeDocument,
        filters: {..._filters, 'isPaid': false, 'showOnlyFuture': true},
      );
      
      DocumentSnapshot? lastDoc;
      if (tournaments.isNotEmpty) {
        lastDoc = await FirebaseFirestore.instance
            .collection('tournaments')
            .doc(tournaments.last.id)
            .get();
      }
      
      setState(() {
        _freeTournaments.addAll(tournaments);
        _isLoading = false;
        _hasMoreFreeTournaments = tournaments.length == 20;
        _lastFreeDocument = lastDoc ?? _lastFreeDocument;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load more tournaments: $e';
      });
    }
  }
  
  // 유료 내전 추가 로드
  Future<void> _loadMorePaidTournaments() async {
    if (_isLoading || !_hasMorePaidTournaments || _lastPaidDocument == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final tournaments = await _tournamentService.getTournaments(
        limit: 20,
        startAfter: _lastPaidDocument,
        filters: {..._filters, 'isPaid': true, 'showOnlyFuture': true},
      );
      
      DocumentSnapshot? lastDoc;
      if (tournaments.isNotEmpty) {
        lastDoc = await FirebaseFirestore.instance
            .collection('tournaments')
            .doc(tournaments.last.id)
            .get();
      }
      
      setState(() {
        _paidTournaments.addAll(tournaments);
        _isLoading = false;
        _hasMorePaidTournaments = tournaments.length == 20;
        _lastPaidDocument = lastDoc ?? _lastPaidDocument;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load more tournaments: $e';
      });
    }
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadFreeTournaments();
    _loadPaidTournaments();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('내전 목록'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() => _isLoading = true);
                _loadFreeTournaments();
                _loadPaidTournaments();
              },
            ),
            // 테스트용 버튼 추가
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.orange),
              onPressed: _createTestTournament,
              tooltip: '테스트 토너먼트 생성',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '무료'),
              Tab(text: '유료'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildDateSelector(),
            _buildFilters(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 무료 내전 탭
                  _errorMessage != null
                    ? ErrorView(
                        errorMessage: _errorMessage!,
                        onRetry: _loadFreeTournaments,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadFreeTournaments,
                        child: _freeTournaments.isEmpty && !_isLoading
                            ? _buildEmptyState(isPaid: false)
                            : _buildTournamentList(
                                tournaments: _freeTournaments,
                                scrollController: _freeScrollController,
                                isLoading: _isLoading,
                                isPaid: false,
                              ),
                      ),
                  
                  // 유료 내전 탭
                  _errorMessage != null
                    ? ErrorView(
                        errorMessage: _errorMessage!,
                        onRetry: _loadPaidTournaments,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPaidTournaments,
                        child: _paidTournaments.isEmpty && !_isLoading
                            ? _buildEmptyState(isPaid: true)
                            : _buildTournamentList(
                                tournaments: _paidTournaments,
                                scrollController: _paidScrollController,
                                isLoading: _isLoading,
                                isPaid: true,
                              ),
                      ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            context.push('/tournaments/create');
          },
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    // Generate dates for the next 7 days
    final List<DateTime> dates = [];
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      dates.add(now.add(Duration(days: i)));
    }
    
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = _currentDateIndex == index;
          
          // Format date
          final day = DateFormat('d').format(date);
          final weekday = DateFormat('E', 'ko_KR').format(date);
          final isToday = DateFormat('yMd').format(date) == DateFormat('yMd').format(now);
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _currentDateIndex = index;
                _selectedDate = isSelected ? null : date; // Toggle date selection
              });
              _loadFreeTournaments();
              _loadPaidTournaments();
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isToday ? '오늘' : weekday,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _ovrToggle = !_ovrToggle;
                  _filters['ovrLimit'] = _ovrToggle ? 100 : null;
                });
                _loadFreeTournaments();
                _loadPaidTournaments();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: _ovrToggle ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _ovrToggle ? AppColors.primary : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 16,
                      color: _ovrToggle ? AppColors.primary : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '실력 제한',
                      style: TextStyle(
                        fontSize: 14,
                        color: _ovrToggle ? AppColors.primary : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  final hasPremium = _filters['premiumBadge'] == true;
                  _filters['premiumBadge'] = hasPremium ? null : true;
                });
                _loadFreeTournaments();
                _loadPaidTournaments();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: _filters['premiumBadge'] == true 
                      ? AppColors.primary.withOpacity(0.1) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _filters['premiumBadge'] == true 
                        ? AppColors.primary 
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified,
                      size: 16,
                      color: _filters['premiumBadge'] == true 
                          ? AppColors.primary 
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '프리미엄',
                      style: TextStyle(
                        fontSize: 14,
                        color: _filters['premiumBadge'] == true 
                            ? AppColors.primary 
                            : Colors.grey.shade600,
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

  Widget _buildEmptyState({required bool isPaid}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_esports,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            isPaid ? '참가비 내전이 없습니다' : '무료 내전이 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 내전을 만들어보세요!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
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

  Widget _buildTournamentList({
    required List<TournamentModel> tournaments,
    required ScrollController scrollController,
    required bool isLoading,
    required bool isPaid,
  }) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: tournaments.length + 1, // +1 for loading indicator
      itemBuilder: (context, index) {
        if (index == tournaments.length) {
          // Loading indicator at the end
          if (isLoading) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            );
          } else {
            return const SizedBox.shrink();
          }
        }
        
        final tournament = tournaments[index];
        return TournamentCard(
          tournament: tournament,
          onTap: () {
            context.push('/tournaments/${tournament.id}');
          },
        );
      },
    );
  }

  // 테스트 토너먼트 생성 메서드
  Future<void> _createTestTournament() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (appState.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }
    
    try {
      final now = DateTime.now();
      final startTime = now.add(const Duration(hours: 2)); // 2시간 후 시작
      
      // 토너먼트 모델 생성
      final tournament = TournamentModel(
        id: '',
        title: '테스트 토너먼트 ${DateTime.now().millisecondsSinceEpoch}',
        description: '이것은 테스트를 위한 토너먼트입니다.',
        hostId: appState.currentUser!.uid,
        hostName: appState.currentUser!.nickname,
        hostProfileImageUrl: appState.currentUser!.profileImageUrl,
        gameMode: GameMode.howlingAbyss,
        gameTitle: '리그 오브 레전드',
        startsAt: Timestamp.fromDate(startTime),
        status: TournamentStatus.open,
        totalSlots: 10,
        slotsByRole: {
          'top': 2,
          'jungle': 2,
          'mid': 2,
          'adc': 2,
          'support': 2,
        },
        filledSlots: {'total': 0},
        filledSlotsByRole: {
          'top': 0,
          'jungle': 0,
          'mid': 0,
          'adc': 0,
          'support': 0,
        },
        participants: [],
        participantsByRole: {},
        ovrLimit: 1000, // 제한 없음
        isPaid: false,
        entryFee: 0,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        tournamentType: TournamentType.casual,
        rules: '참가자들은 예의를 지켜주세요.',
        premiumBadge: false,
        tags: ['test', 'tutorial'],
      );
      
      // 토너먼트 생성
      final tournamentId = await _tournamentService.createTournament(tournament);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('테스트 토너먼트가 생성되었습니다. ID: $tournamentId'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 토너먼트 목록 새로고침
      setState(() {
        _isLoading = true;
      });
      _loadFreeTournaments();
      _loadPaidTournaments();
    } catch (e) {
      debugPrint('토너먼트 생성 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('토너먼트 생성 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 