import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/tournament_card.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({Key? key}) : super(key: key);

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = false;
  String? _errorMessage;
  List<TournamentModel> _tournaments = [];
  bool _hasMoreTournaments = true;
  DocumentSnapshot? _lastDocument;
  
  // Filters
  bool _ovrToggle = false;
  DateTime? _selectedDate;
  int _currentDateIndex = 0;
  
  // Scroll controller for pagination
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTournaments();
    
    // Set up scroll listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
          !_isLoading &&
          _hasMoreTournaments) {
        _loadMoreTournaments();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTournaments() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final tournaments = await _firebaseService.getTournaments(
        limit: 10,
        startDate: _selectedDate,
        endDate: _selectedDate != null 
          ? DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59)
          : null,
        ovrLimit: _ovrToggle ? null : 0, // If OVR toggle is on, we filter matches with OVR limit
      );
      
      setState(() {
        _tournaments = tournaments;
        _isLoading = false;
        _hasMoreTournaments = tournaments.length == 10;
        _lastDocument = tournaments.isNotEmpty 
          ? FirebaseFirestore.instance
              .collection('tournaments')
              .doc(tournaments.last.id)
          : null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load tournaments: $e';
      });
    }
  }

  Future<void> _loadMoreTournaments() async {
    if (_isLoading || !_hasMoreTournaments || _lastDocument == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final tournaments = await _firebaseService.getTournaments(
        limit: 10,
        startAfter: _lastDocument,
        startDate: _selectedDate,
        endDate: _selectedDate != null 
          ? DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59)
          : null,
        ovrLimit: _ovrToggle ? null : 0,
      );
      
      setState(() {
        _tournaments.addAll(tournaments);
        _isLoading = false;
        _hasMoreTournaments = tournaments.length == 10;
        _lastDocument = tournaments.isNotEmpty 
          ? FirebaseFirestore.instance
              .collection('tournaments')
              .doc(tournaments.last.id)
          : _lastDocument;
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
    _loadTournaments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text(
              '용병구함',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            SizedBox(width: 8),
            Chip(
              label: Text('민락동'),
              padding: EdgeInsets.zero,
              labelStyle: TextStyle(fontSize: 12),
              backgroundColor: Color(0xFFEEEEEE),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {
              // TODO: Navigate to notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Navigate to search
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          _buildFilters(),
          Expanded(
            child: _errorMessage != null
                ? ErrorView(
                    message: _errorMessage!,
                    onRetry: _loadTournaments,
                  )
                : RefreshIndicator(
                    onRefresh: _loadTournaments,
                    child: _tournaments.isEmpty && !_isLoading
                        ? _buildEmptyState()
                        : _buildTournamentList(),
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
              _loadTournaments();
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isToday ? '오늘' : day,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    weekday,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // OVR Filter toggle
          FilterChip(
            label: const Text('OVR 제한없음'),
            selected: _ovrToggle,
            onSelected: (value) {
              setState(() {
                _ovrToggle = value;
              });
              _loadTournaments();
            },
            selectedColor: AppColors.primary.withOpacity(0.2),
            checkmarkColor: AppColors.primary,
          ),
          const SizedBox(width: 8),
          // Additional filters can be added here
        ],
      ),
    );
  }

  Widget _buildTournamentList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _tournaments.length + (_isLoading && _hasMoreTournaments ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _tournaments.length) {
          return const LoadingIndicator();
        }
        
        final tournament = _tournaments[index];
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.sports_soccer_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            '등록된 내전이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
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
} 