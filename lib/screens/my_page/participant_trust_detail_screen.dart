import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/services/participant_trust_score_manager.dart';
import 'package:lol_custom_game_manager/widgets/participant_trust_score_widget.dart';
import 'package:lol_custom_game_manager/widgets/host_trust_score_widget.dart';
import 'package:lol_custom_game_manager/models/participant_evaluation_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

/// 신뢰도 상세 화면 (참가자/주최자 탭 형태)
class ParticipantTrustDetailScreen extends StatefulWidget {
  const ParticipantTrustDetailScreen({Key? key}) : super(key: key);
  
  @override
  State<ParticipantTrustDetailScreen> createState() => _ParticipantTrustDetailScreenState();
}

class _ParticipantTrustDetailScreenState extends State<ParticipantTrustDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ParticipantTrustScoreManager _scoreManager = ParticipantTrustScoreManager();
  
  ParticipantTrustInfo? _participantTrustInfo;
  double _hostTrustScore = 80.0;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTrustData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadTrustData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    try {
      // 참가자 신뢰도 정보 로드
      final participantInfo = await _scoreManager.getParticipantTrustInfo(userId);
      
      // 주최자 신뢰도 정보 로드
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      final hostScore = userDoc.exists 
          ? (userDoc.data()?['hostScore'] as num?)?.toDouble() ?? 80.0
          : 80.0;
      
      setState(() {
        _participantTrustInfo = participantInfo;
        _hostTrustScore = hostScore;
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
        backgroundColor: AppColors.backgroundCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '신뢰도',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '참가자 신뢰도'),
            Tab(text: '주최자 신뢰도'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildParticipantTrustTab(),
                _buildHostTrustTab(),
              ],
            ),
    );
  }
  
  Widget _buildParticipantTrustTab() {
    if (_participantTrustInfo == null) {
      return _buildErrorState('참가자 신뢰도 정보를 불러올 수 없습니다.');
    }
    
    return Column(
      children: [
        // 상단 점수 요약
        Container(
          padding: const EdgeInsets.all(20),
          color: AppColors.backgroundCard,
          child: Row(
            children: [
              // 점수
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${_participantTrustInfo!.score.toInt()}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: _getScoreColor(_participantTrustInfo!.score),
                      ),
                    ),
                    Text(
                      _getScoreStatus(_participantTrustInfo!.score),
                      style: TextStyle(
                        fontSize: 14,
                        color: _getScoreColor(_participantTrustInfo!.score),
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
                color: AppColors.border,
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
                          color: _participantTrustInfo!.cleanStreak > 0 
                              ? Colors.orange 
                              : AppColors.textTertiary,
                          size: 24,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_participantTrustInfo!.cleanStreak}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: _participantTrustInfo!.cleanStreak > 0 
                                ? Colors.orange 
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '연속 클린 참여',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // 점수 범위 가이드
        Container(
          height: 80,
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: AppColors.backgroundCard,
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
        
        const SizedBox(height: 8),
        
        // 최근 기록
        Expanded(
          child: Container(
            color: AppColors.backgroundCard,
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
                          fontWeight: FontWeight.w700,
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
                Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: _participantTrustInfo!.history.isEmpty
                      ? _buildEmptyState('아직 참가 기록이 없어요')
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: _participantTrustInfo!.history.take(10).length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, index) {
                            final record = _participantTrustInfo!.history[index];
                            return _buildCompactHistoryItem(record);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildHostTrustTab() {
    return Column(
      children: [
        // 상단 점수 요약
        Container(
          padding: const EdgeInsets.all(20),
          color: AppColors.backgroundCard,
          child: Column(
            children: [
              Text(
                '${_hostTrustScore.toInt()}',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: _getScoreColor(_hostTrustScore),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getHostScoreStatus(_hostTrustScore),
                style: TextStyle(
                  fontSize: 14,
                  color: _getScoreColor(_hostTrustScore),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // 점수 범위 가이드
        Container(
          height: 80,
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: AppColors.backgroundCard,
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
        
        const SizedBox(height: 8),
        
        // 최근 평가 기록
        Expanded(
          child: Container(
            color: AppColors.backgroundCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.assessment, size: 20, color: AppColors.textPrimary),
                      const SizedBox(width: 8),
                      Text(
                        '최근 주최 기록',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
                Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: _buildHostEvaluationHistory(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildHostEvaluationHistory() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return _buildEmptyState('사용자 정보를 불러올 수 없습니다');
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('evaluations')
          .where('targetUserId', isEqualTo: userId)
          .where('isHost', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('아직 주최 기록이 없어요');
        }
        
        final evaluations = snapshot.data!.docs;
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: evaluations.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
          itemBuilder: (context, index) {
            final eval = evaluations[index].data() as Map<String, dynamic>;
            return _buildHostEvaluationItem(eval);
          },
        );
      },
    );
  }
  
  Widget _buildHostEvaluationItem(Map<String, dynamic> evaluation) {
    final rating = (evaluation['rating'] as num?)?.toDouble() ?? 5.0;
    final tournamentTitle = evaluation['tournamentTitle'] as String? ?? '토너먼트';
    final comment = evaluation['comment'] as String? ?? '';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getRatingColor(rating).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${rating.toInt()}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _getRatingColor(rating),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tournamentTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    comment,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              return Icon(
                index < rating ? Icons.star : Icons.star_border,
                size: 14,
                color: index < rating ? Colors.amber : AppColors.textTertiary,
              );
            }),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactScoreRange(String range, Color color, String status) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            range,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactHistoryItem(ParticipantTrustHistory record) {
    final isPositive = record.scoreChange >= 0;
    final color = isPositive ? AppColors.success : AppColors.error;
    
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
                    fontWeight: FontWeight.w600,
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
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getScoreColor(double score) {
    if (score >= 90) return AppColors.success;
    if (score >= 70) return Colors.yellow[700]!;
    if (score >= 50) return Colors.orange;
    return AppColors.error;
  }
  
  String _getScoreStatus(double score) {
    if (score >= 90) return '일반적인 참가자';
    if (score >= 70) return '일반적인 참가자';
    if (score >= 50) return '최근 평가가 낮아요';
    return '주의가 필요한 유저';
  }
  
  String _getHostScoreStatus(double score) {
    if (score >= 90) return '매우 신뢰할 수 있는 주최자';
    if (score >= 70) return '일반적인 수준의 주최자';
    if (score >= 50) return '최근 운영 평가가 낮아요';
    return '신뢰도가 낮아 주의가 필요해요';
  }
  
  Color _getRatingColor(double rating) {
    if (rating >= 4.0) return AppColors.success;
    if (rating >= 3.0) return Colors.yellow[700]!;
    if (rating >= 2.0) return Colors.orange;
    return AppColors.error;
  }
} 