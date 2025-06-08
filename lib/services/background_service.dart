import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/services/tournament_service.dart';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();
  
  final TournamentService _tournamentService = TournamentService();
  Timer? _cleanupTimer;
  
  void startCleanupService() {
    debugPrint('Starting background cleanup service');
    
    // 앱 시작시 한 번 실행
    _cleanupExpiredChatRooms();
    
    // 매 30분마다 실행 (실제 배포 앱에서는 더 긴 간격으로 설정 가능)
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _cleanupExpiredChatRooms(),
    );
  }
  
  void stopCleanupService() {
    debugPrint('Stopping background cleanup service');
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }
  
  Future<void> _cleanupExpiredChatRooms() async {
    debugPrint('Running expired chat rooms cleanup');
    try {
      await _tournamentService.cleanupExpiredTournamentChatRooms();
    } catch (e) {
      debugPrint('Error in background cleanup: $e');
    }
  }
  
  // 앱이 종료될 때 호출하여 리소스 해제
  void dispose() {
    stopCleanupService();
  }
} 