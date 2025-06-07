import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/services/tournament_service.dart';
import 'package:intl/intl.dart';

class TournamentsByDateScreen extends StatefulWidget {
  final DateTime selectedDate;

  const TournamentsByDateScreen({
    Key? key,
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<TournamentsByDateScreen> createState() => _TournamentsByDateScreenState();
}

class _TournamentsByDateScreenState extends State<TournamentsByDateScreen> {
  final TournamentService _tournamentService = TournamentService();
  List<TournamentModel> _tournaments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tournaments = await _tournamentService.getUserTournamentsByDate(widget.selectedDate);
      
      setState(() {
        _tournaments = tournaments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '토너먼트 정보를 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy년 M월 d일');
    final formattedDate = dateFormat.format(widget.selectedDate);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('$formattedDate의 내전'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTournaments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTournaments,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : _tournaments.isEmpty
                  ? _buildEmptyView()
                  : _buildTournamentList(),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            '${DateFormat('yyyy년 M월 d일').format(widget.selectedDate)}에 예정된 내전이 없습니다',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('달력으로 돌아가기'),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentList() {
    final timeFormat = DateFormat('HH:mm');
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tournaments.length,
      itemBuilder: (context, index) {
        final tournament = _tournaments[index];
        final startTime = timeFormat.format(tournament.startsAt.toDate());
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: InkWell(
            onTap: () {
              // 토너먼트 상세 페이지로 이동
              Navigator.of(context).pushNamed(
                '/tournament-detail',
                arguments: tournament.id,
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getTournamentStatusColor(tournament.status),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getTournamentStatusText(tournament.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (tournament.tournamentType == TournamentType.competitive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '경쟁전',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tournament.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '시작 시간: $startTime',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '주최자: ${tournament.hostName}',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _getParticipationProgress(tournament),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '참가자: ${_getTotalParticipants(tournament)}/${_getTotalSlots(tournament)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getTournamentStatusColor(TournamentStatus status) {
    switch (status) {
      case TournamentStatus.draft:
        return Colors.grey;
      case TournamentStatus.open:
        return Colors.green;
      case TournamentStatus.full:
        return Colors.orange;
      case TournamentStatus.inProgress:
      case TournamentStatus.ongoing:
        return Colors.blue;
      case TournamentStatus.completed:
        return Colors.purple;
      case TournamentStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTournamentStatusText(TournamentStatus status) {
    switch (status) {
      case TournamentStatus.draft:
        return '초안';
      case TournamentStatus.open:
        return '모집중';
      case TournamentStatus.full:
        return '모집완료';
      case TournamentStatus.inProgress:
      case TournamentStatus.ongoing:
        return '진행중';
      case TournamentStatus.completed:
        return '완료됨';
      case TournamentStatus.cancelled:
        return '취소됨';
      default:
        return '알 수 없음';
    }
  }

  double _getParticipationProgress(TournamentModel tournament) {
    final totalSlots = _getTotalSlots(tournament);
    if (totalSlots == 0) return 0;
    
    final participants = _getTotalParticipants(tournament);
    return participants / totalSlots;
  }

  int _getTotalSlots(TournamentModel tournament) {
    return tournament.slots.values.fold(0, (sum, count) => sum + count);
  }

  int _getTotalParticipants(TournamentModel tournament) {
    return tournament.participants.length;
  }
} 