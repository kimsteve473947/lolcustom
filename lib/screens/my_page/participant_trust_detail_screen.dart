import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/services/participant_trust_score_manager.dart';
import 'package:lol_custom_game_manager/widgets/participant_trust_score_widget.dart';
import 'package:lol_custom_game_manager/models/participant_evaluation_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 참가자 신뢰도 상세 화면
class ParticipantTrustDetailScreen extends StatefulWidget {
  const ParticipantTrustDetailScreen({Key? key}) : super(key: key);
  
  @override
  State<ParticipantTrustDetailScreen> createState() => _ParticipantTrustDetailScreenState();
}

class _ParticipantTrustDetailScreenState extends State<ParticipantTrustDetailScreen> {
  final ParticipantTrustScoreManager _scoreManager = ParticipantTrustScoreManager();
  ParticipantTrustInfo? _trustInfo;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadTrustInfo();
  }
  
  Future<void> _loadTrustInfo() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    try {
      final info = await _scoreManager.getParticipantTrustInfo(userId);
      setState(() {
        _trustInfo = info;
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('참가자 신뢰도'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trustInfo == null
              ? const Center(child: Text('정보를 불러올 수 없습니다.'))
              : Column(
                  children: [
                    // 상단 점수 요약
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppColors.white,
                      child: Row(
                        children: [
                          // 점수
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${_trustInfo!.score.toInt()}',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: _getScoreColor(_trustInfo!.score),
                                  ),
                                ),
                                Text(
                                  _getScoreStatus(_trustInfo!.score),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _getScoreColor(_trustInfo!.score),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 구분선
                          Container(
                            width: 1,
                            height: 60,
                            color: Colors.grey[300],
                          ),
                          // 연속 클린 참여
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.local_fire_department,
                                      color: _trustInfo!.cleanStreak > 0 
                                          ? Colors.orange 
                                          : Colors.grey[400],
                                      size: 24,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_trustInfo!.cleanStreak}',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: _trustInfo!.cleanStreak > 0 
                                            ? Colors.orange 
                                            : Colors.grey[400],
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '연속 클린 참여',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 점수 범위 가이드 (가로 스크롤)
                    Container(
                      height: 80,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildCompactScoreRange('90-100', Colors.green, '우수'),
                          _buildCompactScoreRange('70-89', Colors.yellow[700]!, '일반'),
                          _buildCompactScoreRange('50-69', Colors.orange, '주의'),
                          _buildCompactScoreRange('0-49', Colors.red, '위험'),
                        ],
                      ),
                    ),
                    
                    // 최근 기록
                    Expanded(
                      child: Container(
                        color: AppColors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(Icons.history, size: 20, color: AppColors.textPrimary),
                                  const SizedBox(width: 8),
                                  Text(
                                    '최근 참가 기록',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '최근 10개',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: _trustInfo!.history.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.history,
                                            size: 48,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '아직 참가 기록이 없어요',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: EdgeInsets.zero,
                                      itemCount: _trustInfo!.history.take(10).length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final record = _trustInfo!.history[index];
                                        return _buildCompactHistoryItem(record);
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
  
  Widget _buildScoreGuide() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '점수 가이드',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildScoreRange(
            range: '90~100점',
            color: Colors.green,
            icon: Icons.verified_user,
            description: '매우 신뢰할 수 있는 참가자',
            benefit: '명예 뱃지 획득',
          ),
          const SizedBox(height: 12),
          _buildScoreRange(
            range: '70~89점',
            color: Colors.yellow[700]!,
            icon: Icons.person,
            description: '일반적인 참가자',
            benefit: '모든 토너먼트 참가 가능',
          ),
          const SizedBox(height: 12),
          _buildScoreRange(
            range: '50~69점',
            color: Colors.orange,
            icon: Icons.warning_amber,
            description: '최근 평가가 낮아요',
            benefit: '일부 토너먼트 제한 가능',
          ),
          const SizedBox(height: 12),
          _buildScoreRange(
            range: '49점 이하',
            color: Colors.red,
            icon: Icons.error_outline,
            description: '주의가 필요한 유저',
            benefit: '토너먼트 참가 제한',
          ),
        ],
      ),
    );
  }
  
  Widget _buildScoreRange({
    required String range,
    required Color color,
    required IconData icon,
    required String description,
    required String benefit,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    range,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                benefit,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildCalculationExplanation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calculate,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '점수 계산 방식',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCalculationItem(
            title: '기본 점수',
            description: '모든 참가자는 70점으로 시작합니다.',
          ),
          const SizedBox(height: 12),
          _buildCalculationItem(
            title: '최근 10경기 반영',
            description: '최근 경기일수록 더 큰 비중으로 점수에 반영됩니다.',
          ),
          const SizedBox(height: 12),
          _buildCalculationItem(
            title: '가중 평균 계산',
            description: '가장 최근 경기는 100%, 이전 경기는 90%씩 감소하는 비중으로 계산됩니다.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tips_and_updates,
                  color: AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '꾸준한 정상 참여로 신뢰도를 높여보세요!',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCalculationItem({
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.yellow[700]!;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
  
  String _getScoreStatus(double score) {
    if (score >= 90) return '매우 신뢰할 수 있는 참가자';
    if (score >= 70) return '일반적인 참가자';
    if (score >= 50) return '최근 평가가 낮아요';
    return '주의가 필요한 유저';
  }
  
  Widget _buildCompactScoreRange(String range, Color color, String status) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            range,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactHistoryItem(ParticipantTrustHistory record) {
    final isPositive = record.scoreChange >= 0;
    final color = isPositive ? Colors.green : Colors.red;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.add_circle : Icons.remove_circle,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.tournamentTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  record.reason,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isPositive ? '+' : ''}${record.scoreChange}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
} 