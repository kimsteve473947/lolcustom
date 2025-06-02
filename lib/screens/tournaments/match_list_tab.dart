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
  List<TournamentModel> _freeTournaments = [];
  List<TournamentModel> _paidTournaments = [];
  bool _hasMoreFreeTournaments = true;
  bool _hasMorePaidTournaments = true;
  DocumentSnapshot? _lastFreeDocument;
  DocumentSnapshot? _lastPaidDocument;
  
  // Scroll controllers for pagination
  final ScrollController _freeScrollController = ScrollController();
  final ScrollController _paidScrollController = ScrollController();

  // 필터 설정
  final Map<String, dynamic> _filters = {
    'isPaid': null,  // null: 모두, true: 유료만, false: 무료만
    'ovrLimit': null,  // null: 제한 없음, int: 제한 값
    'premiumBadge': null,  // null: 모두, true: 프리미엄만
  };
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
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

  // 선택된 탭에 따라 대회 로드
  void _loadTournaments() {
    if (_tabController.index == 0) {
      _loadFreeTournaments();
    } else {
      _loadPaidTournaments();
    }
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
      Map<String, dynamic> filterMap = {..._filters, 'isPaid': false};
      
      // 선택된 날짜가 있으면 해당 날짜의 시작과 끝을 설정
      if (widget.selectedDate != null) {
        // 해당 날짜의 시작 (00:00:00)
        final startDate = DateTime(widget.selectedDate!.year, widget.selectedDate!.month, widget.selectedDate!.day);
        // 해당 날짜의 끝 (23:59:59)
        final endDate = DateTime(widget.selectedDate!.year, widget.selectedDate!.month, widget.selectedDate!.day, 23, 59, 59);
        
        filterMap['startDate'] = startDate;
        filterMap['endDate'] = endDate;
      }
      
      final tournaments = await _tournamentService.getTournaments(
        limit: 20,
        filters: filterMap,
        orderBy: 'startsAt',
        descending: true, // 최신순(내림차순) 정렬
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
      Map<String, dynamic> filterMap = {..._filters, 'isPaid': true};
      
      // 선택된 날짜가 있으면 해당 날짜의 시작과 끝을 설정
      if (widget.selectedDate != null) {
        // 해당 날짜의 시작 (00:00:00)
        final startDate = DateTime(widget.selectedDate!.year, widget.selectedDate!.month, widget.selectedDate!.day);
        // 해당 날짜의 끝 (23:59:59)
        final endDate = DateTime(widget.selectedDate!.year, widget.selectedDate!.month, widget.selectedDate!.day, 23, 59, 59);
        
        filterMap['startDate'] = startDate;
        filterMap['endDate'] = endDate;
      }
      
      final tournaments = await _tournamentService.getTournaments(
        limit: 20,
        filters: filterMap,
        orderBy: 'startsAt',
        descending: true, // 최신순(내림차순) 정렬
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
    }
  }
  
  // 더 많은 무료 내전 로드 (페이지네이션)
  Future<void> _loadMoreFreeTournaments() async {
    if (_isLoading || !_hasMoreFreeTournaments || _lastFreeDocument == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 날짜 필터 적용
      Map<String, dynamic> filterMap = {..._filters, 'isPaid': false};
      
      // 선택된 날짜가 있으면 해당 날짜의 시작과 끝을 설정
      if (widget.selectedDate != null) {
        // 해당 날짜의 시작 (00:00:00)
        final startDate = DateTime(widget.selectedDate!.year, widget.selectedDate!.month, widget.selectedDate!.day);
        // 해당 날짜의 끝 (23:59:59)
        final endDate = DateTime(widget.selectedDate!.year, widget.selectedDate!.month, widget.selectedDate!.day, 23, 59, 59);
        
        filterMap['startDate'] = startDate;
        filterMap['endDate'] = endDate;
      }
      
      final tournaments = await _tournamentService.getTournaments(
        limit: 20,
        startAfter: _lastFreeDocument,
        filters: filterMap,
        orderBy: 'startsAt',
        descending: true, // 최신순(내림차순) 정렬
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
        _lastFreeDocument = lastDoc;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 더 많은 유료 내전 로드 (페이지네이션)
  Future<void> _loadMorePaidTournaments() async {
    if (_isLoading || !_hasMorePaidTournaments || _lastPaidDocument == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 날짜 필터 적용
      Map<String, dynamic> filterMap = {..._filters, 'isPaid': true};
      
      // 선택된 날짜가 있으면 해당 날짜의 시작과 끝을 설정
      if (widget.selectedDate != null) {
        // 해당 날짜의 시작 (00:00:00)
        final startDate = DateTime(widget.selectedDate!.year, widget.selectedDate!.month, widget.selectedDate!.day);
        // 해당 날짜의 끝 (23:59:59)
        final endDate = DateTime(widget.selectedDate!.year, widget.selectedDate!.month, widget.selectedDate!.day, 23, 59, 59);
        
        filterMap['startDate'] = startDate;
        filterMap['endDate'] = endDate;
      }
      
      final tournaments = await _tournamentService.getTournaments(
        limit: 20,
        startAfter: _lastPaidDocument,
        filters: filterMap,
        orderBy: 'startsAt',
        descending: true, // 최신순(내림차순) 정렬
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
        _lastPaidDocument = lastDoc;
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
                _buildFreeTournamentsList(),
                _buildPaidTournamentsList(),
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
  
  Widget _buildFreeTournamentsList() {
    if (_errorMessage != null) {
      return ErrorView(
        message: _errorMessage!,
        onRetry: _loadFreeTournaments,
      );
    }
    
    if (_isLoading && _freeTournaments.isEmpty) {
      return const LoadingIndicator();
    }
    
    if (_freeTournaments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_esports,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              widget.selectedDate != null 
                  ? '${DateFormat('M월 d일', 'ko_KR').format(widget.selectedDate!)}에 일반전이 없습니다'
                  : '일반전이 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.push('/tournaments/create');
              },
              child: const Text('내전 만들기'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadFreeTournaments,
      child: ListView.builder(
        controller: _freeScrollController,
        itemCount: _freeTournaments.length + (_hasMoreFreeTournaments ? 1 : 0),
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          if (index == _freeTournaments.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          
          final tournament = _freeTournaments[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TournamentCard(
              tournament: tournament,
              onTap: () {
                context.push('/tournaments/${tournament.id}');
              },
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildPaidTournamentsList() {
    if (_isLoading && _paidTournaments.isEmpty) {
      return const LoadingIndicator();
    }
    
    if (_paidTournaments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_esports,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              widget.selectedDate != null 
                  ? '${DateFormat('M월 d일', 'ko_KR').format(widget.selectedDate!)}에 경쟁전이 없습니다'
                  : '경쟁전이 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.push('/tournaments/create');
              },
              child: const Text('내전 만들기'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadPaidTournaments,
      child: ListView.builder(
        controller: _paidScrollController,
        itemCount: _paidTournaments.length + (_hasMorePaidTournaments ? 1 : 0),
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          if (index == _paidTournaments.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          
          final tournament = _paidTournaments[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TournamentCard(
              tournament: tournament,
              onTap: () {
                context.push('/tournaments/${tournament.id}');
              },
            ),
          );
        },
      ),
    );
  }
} 