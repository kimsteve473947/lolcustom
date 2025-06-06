import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';

class AdminToolsScreen extends StatefulWidget {
  const AdminToolsScreen({Key? key}) : super(key: key);

  @override
  State<AdminToolsScreen> createState() => _AdminToolsScreenState();
}

class _AdminToolsScreenState extends State<AdminToolsScreen> {
  bool _isLoading = false;
  String _resultMessage = '';
  late FirebaseService _firebaseService;
  
  @override
  void initState() {
    super.initState();
    // 초기화 시점에 FirebaseService 객체 가져오기
    _firebaseService = Provider.of<FirebaseService>(context, listen: false);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 도구'),
      ),
      body: _isLoading 
        ? const LoadingIndicator() 
        : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle('토너먼트 관리'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _deleteAllTournaments,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('모든 토너먼트 삭제'),
            ),
            if (_resultMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _resultMessage,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            // 다른 관리 도구들 추가 가능
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildSectionTitle('디버깅 정보'),
            const SizedBox(height: 16),
            _buildDebugInfo(),
          ],
        ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }
  
  Widget _buildDebugInfo() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '애플리케이션 정보',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // 여기에 디버그 정보 표시
            const Text('Firestore 연결 상태: 활성화'),
            const SizedBox(height: 4),
            const Text('캐시 상태: 정상'),
          ],
        ),
      ),
    );
  }
  
  Future<void> _deleteAllTournaments() async {
    setState(() {
      _isLoading = true;
      _resultMessage = '';
    });
    
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('경고'),
          content: const Text(
            '모든 토너먼트를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('삭제'),
            ),
          ],
        ),
      );
      
      if (confirmed == true) {
        // 직접 FirebaseService 인스턴스를 사용
        final count = await _firebaseService.deleteAllTournaments();
        
        setState(() {
          _resultMessage = '$count개의 토너먼트가 삭제되었습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _resultMessage = '오류 발생: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 