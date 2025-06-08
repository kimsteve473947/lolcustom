import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tournament_app/providers/app_state_provider.dart';
import 'package:tournament_app/services/tournament_service.dart';
import 'package:tournament_app/models/tournament_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentListScreen extends StatefulWidget {
  // ... (existing code)
  @override
  _TournamentListScreenState createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  // ... (existing code)

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  @override
  Widget build(BuildContext context) {
    // ... (existing code)
  }

  Future<void> _loadTournaments() async {
    // ... (existing code)
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
        gameMode: 'HOWLING_ABYSS',
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
      final tournamentService = TournamentService();
      final tournamentId = await tournamentService.createTournament(tournament);
      
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
      _loadTournaments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('토너먼트 생성 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 