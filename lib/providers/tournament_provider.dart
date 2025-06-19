import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/services/tournament_service.dart';

class TournamentProvider with ChangeNotifier {
  final TournamentService _tournamentService;

  TournamentProvider(this._tournamentService);

  // 상태 변수
  DateTime _selectedDate = DateTime.now();
  Map<TournamentType, List<TournamentModel>> _tournaments = {
    TournamentType.casual: [],
    TournamentType.competitive: [],
  };
  Map<TournamentType, bool> _isLoading = {
    TournamentType.casual: false,
    TournamentType.competitive: false,
  };
  Map<TournamentType, bool> _hasMore = {
    TournamentType.casual: true,
    TournamentType.competitive: true,
  };
  Map<TournamentType, DocumentSnapshot?> _lastDocument = {
    TournamentType.casual: null,
    TournamentType.competitive: null,
  };
  String? _errorMessage;

  // Getters
  DateTime get selectedDate => _selectedDate;
  List<TournamentModel> tournaments(TournamentType type) => _tournaments[type] ?? [];
  bool isLoading(TournamentType type) => _isLoading[type] ?? false;
  bool hasMore(TournamentType type) => _hasMore[type] ?? true;
  String? get errorMessage => _errorMessage;

  // 날짜 선택
  Future<void> selectDate(DateTime date) async {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
    await fetchInitialTournaments(TournamentType.casual);
    await fetchInitialTournaments(TournamentType.competitive);
  }

  // 초기 토너먼트 로드
  Future<void> fetchInitialTournaments(TournamentType type) async {
    if (_isLoading[type] == true) return;

    _isLoading[type] = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tournaments[type] = [];
      _lastDocument[type] = null;
      _hasMore[type] = true;
      
      final result = await _fetchFromService(type);
      _tournaments[type] = result['tournaments'];
      _lastDocument[type] = result['lastDoc'];
      if ((result['tournaments'] as List).length < 10) {
        _hasMore[type] = false;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading[type] = false;
      notifyListeners();
    }
  }

  // 더 많은 토너먼트 로드
  Future<void> fetchMoreTournaments(TournamentType type) async {
    if (_isLoading[type] == true || _hasMore[type] == false) return;

    _isLoading[type] = true;
    notifyListeners();

    try {
      final result = await _fetchFromService(type);
      _tournaments[type]?.addAll(result['tournaments']);
      _lastDocument[type] = result['lastDoc'];
      if ((result['tournaments'] as List).length < 10) {
        _hasMore[type] = false;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading[type] = false;
      notifyListeners();
    }
  }

  // 서비스 호출
  Future<Map<String, dynamic>> _fetchFromService(TournamentType type) {
    final filters = {
      'tournamentType': type.index,
      'startDate': _selectedDate,
      'endDate': DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59),
    };

    return _tournamentService.getTournaments(
      filters: filters,
      limit: 10,
      startAfter: _lastDocument[type],
    );
  }

  // 낙관적 업데이트를 위한 메서드
  void addNewTournament(TournamentModel tournament) {
    final type = tournament.tournamentType;
    // 해당 날짜의 목록에만 추가
    if (isSameDay(_selectedDate, tournament.startsAt.toDate())) {
      _tournaments[type]?.insert(0, tournament);
      notifyListeners();
    }
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}