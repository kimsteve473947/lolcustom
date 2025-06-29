import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/services/tournament_service.dart';

class TournamentProvider with ChangeNotifier {
  final TournamentService _tournamentService;

  TournamentProvider(this._tournamentService);

  // 상태 변수
  DateTime _selectedDate = DateTime.now();
  
  // GameCategory와 TournamentType 조합으로 관리
  Map<String, List<TournamentModel>> _tournaments = {};
  Map<String, bool> _isLoading = {};
  Map<String, bool> _hasMore = {};
  Map<String, DocumentSnapshot?> _lastDocument = {};
  String? _errorMessage;

  // 키 생성 헬퍼 메서드
  String _getKey(GameCategory gameCategory, TournamentType tournamentType) {
    return '${gameCategory.name}_${tournamentType.name}';
  }

  // Getters
  DateTime get selectedDate => _selectedDate;
  List<TournamentModel> tournaments(GameCategory gameCategory, TournamentType tournamentType) {
    final key = _getKey(gameCategory, tournamentType);
    return _tournaments[key] ?? [];
  }
  bool isLoading(GameCategory gameCategory, TournamentType tournamentType) {
    final key = _getKey(gameCategory, tournamentType);
    return _isLoading[key] ?? false;
  }
  bool hasMore(GameCategory gameCategory, TournamentType tournamentType) {
    final key = _getKey(gameCategory, tournamentType);
    return _hasMore[key] ?? true;
  }
  String? get errorMessage => _errorMessage;

  // 날짜 선택
  Future<void> selectDate(DateTime date) async {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
    
    // 모든 카테고리와 타입 조합에 대해 초기 로드
    for (final gameCategory in GameCategory.values) {
      for (final tournamentType in TournamentType.values) {
        await fetchInitialTournaments(gameCategory, tournamentType);
      }
    }
  }

  // 초기 토너먼트 로드
  Future<void> fetchInitialTournaments(GameCategory gameCategory, TournamentType tournamentType) async {
    final key = _getKey(gameCategory, tournamentType);
    if (_isLoading[key] == true) return;

    _isLoading[key] = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tournaments[key] = [];
      _lastDocument[key] = null;
      _hasMore[key] = true;
      
      final result = await _fetchFromService(gameCategory, tournamentType);
      _tournaments[key] = result['tournaments'];
      _lastDocument[key] = result['lastDoc'];
      if ((result['tournaments'] as List).length < 10) {
        _hasMore[key] = false;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading[key] = false;
      notifyListeners();
    }
  }

  // 더 많은 토너먼트 로드
  Future<void> fetchMoreTournaments(GameCategory gameCategory, TournamentType tournamentType) async {
    final key = _getKey(gameCategory, tournamentType);
    if (_isLoading[key] == true || _hasMore[key] == false) return;

    _isLoading[key] = true;
    notifyListeners();

    try {
      final result = await _fetchFromService(gameCategory, tournamentType);
      _tournaments[key]?.addAll(result['tournaments']);
      _lastDocument[key] = result['lastDoc'];
      if ((result['tournaments'] as List).length < 10) {
        _hasMore[key] = false;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading[key] = false;
      notifyListeners();
    }
  }

  // 서비스 호출
  Future<Map<String, dynamic>> _fetchFromService(GameCategory gameCategory, TournamentType tournamentType) {
    final key = _getKey(gameCategory, tournamentType);
    final filters = {
      'gameCategory': gameCategory.index,
      'tournamentType': tournamentType.index,
      'startDate': _selectedDate,
      'endDate': DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59),
    };

    return _tournamentService.getTournaments(
      filters: filters,
      limit: 10,
      startAfter: _lastDocument[key],
    );
  }

  // 낙관적 업데이트를 위한 메서드
  void addNewTournament(TournamentModel tournament) {
    final key = _getKey(tournament.gameCategory, tournament.tournamentType);
    // 해당 날짜의 목록에만 추가
    if (isSameDay(_selectedDate, tournament.startsAt.toDate())) {
      _tournaments[key]?.insert(0, tournament);
      notifyListeners();
    }
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // 레거시 메서드들 (하위 호환성을 위해 유지)
  @Deprecated('Use tournaments(gameCategory, tournamentType) instead')
  List<TournamentModel> tournamentsLegacy(TournamentType type) {
    // 개인전으로 기본 설정
    return tournaments(GameCategory.individual, type);
  }
  
  @Deprecated('Use isLoading(gameCategory, tournamentType) instead')
  bool isLoadingLegacy(TournamentType type) {
    return isLoading(GameCategory.individual, type);
  }
  
  @Deprecated('Use hasMore(gameCategory, tournamentType) instead')
  bool hasMoreLegacy(TournamentType type) {
    return hasMore(GameCategory.individual, type);
  }
  
  @Deprecated('Use fetchInitialTournaments(gameCategory, tournamentType) instead')
  Future<void> fetchInitialTournamentsLegacy(TournamentType type) async {
    return fetchInitialTournaments(GameCategory.individual, type);
  }
  
  @Deprecated('Use fetchMoreTournaments(gameCategory, tournamentType) instead')
  Future<void> fetchMoreTournamentsLegacy(TournamentType type) async {
    return fetchMoreTournaments(GameCategory.individual, type);
  }
}