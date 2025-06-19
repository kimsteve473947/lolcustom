import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';

/// 주최자 신뢰도 표시 위젯 - 토스 스타일
class HostTrustScoreWidget extends StatelessWidget {
  final double score;
  final bool showDetails;
  final bool isCompact;
  final VoidCallback? onTap;

  const HostTrustScoreWidget({
    Key? key,
    required this.score,
    this.showDetails = true,
    this.isCompact = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scoreData = _getScoreData(score);
    
    if (isCompact) {
      return _buildCompactView(scoreData);
    }
    
    return _buildDetailView(scoreData);
  }
  
  Widget _buildCompactView(_ScoreData scoreData) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: scoreData.backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '👍',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 4),
            Text(
              '${score.toInt()}점',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scoreData.textColor,
              ),
            ),
            if (showDetails) ...[
              const SizedBox(width: 4),
              Text(
                scoreData.shortText,
                style: TextStyle(
                  fontSize: 11,
                  color: scoreData.textColor.withOpacity(0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailView(_ScoreData scoreData) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 상단 점수 섹션
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scoreData.backgroundColor,
                    scoreData.backgroundColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Text(
                    '운영 신뢰도',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: scoreData.textColor.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '👍 ',
                        style: TextStyle(fontSize: 28),
                      ),
                      Text(
                        '${score.toInt()}',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: scoreData.textColor,
                          height: 1,
                        ),
                      ),
                      Text(
                        '점',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: scoreData.textColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 하단 설명 섹션
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    _getEmoji(score),
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      scoreData.fullText,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  _ScoreData _getScoreData(double score) {
    if (score >= 90) {
      return _ScoreData(
        backgroundColor: const Color(0xFFE8F5E9),
        textColor: const Color(0xFF2E7D32),
        shortText: '우수',
        fullText: '일반적인 수준의 진행자예요',
      );
    } else if (score >= 70) {
      return _ScoreData(
        backgroundColor: const Color(0xFFFFF8E1),
        textColor: const Color(0xFFF57C00),
        shortText: '양호',
        fullText: '일반적인 수준의 진행자예요',
      );
    } else if (score >= 50) {
      return _ScoreData(
        backgroundColor: const Color(0xFFFFF3E0),
        textColor: const Color(0xFFE65100),
        shortText: '주의',
        fullText: '최근 운영 평가가 낮아요',
      );
    } else {
      return _ScoreData(
        backgroundColor: const Color(0xFFFFEBEE),
        textColor: const Color(0xFFC62828),
        shortText: '위험',
        fullText: '신뢰도가 낮아 참여 전 주의가 필요해요',
      );
    }
  }
  
  String _getEmoji(double score) {
    if (score >= 90) return '😊';
    if (score >= 70) return '🙂';
    if (score >= 50) return '😐';
    return '😟';
  }
}

/// 주최자 신뢰도 로딩 위젯
class HostTrustScoreLoader extends StatelessWidget {
  final String hostId;
  final bool showDetails;
  final bool isCompact;
  final VoidCallback? onTap;

  const HostTrustScoreLoader({
    Key? key,
    required this.hostId,
    this.showDetails = true,
    this.isCompact = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(hostId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildLoadingWidget();
        }
        
        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final hostScore = (userData['hostScore'] as num?)?.toDouble() ?? 80.0;
        
        return HostTrustScoreWidget(
          score: hostScore,
          showDetails: showDetails,
          isCompact: isCompact,
          onTap: onTap ?? () => _showScoreDetails(context, hostId, hostScore),
        );
      },
    );
  }
  
  Widget _buildLoadingWidget() {
    return Container(
      padding: EdgeInsets.all(isCompact ? 6 : 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(isCompact ? 20 : 16),
      ),
      child: isCompact
          ? const SizedBox(
              width: 60,
              height: 16,
            )
          : const SizedBox(
              width: double.infinity,
              height: 120,
            ),
    );
  }
  
  void _showScoreDetails(BuildContext context, String hostId, double score) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _HostScoreDetailsSheet(
        hostId: hostId,
        currentScore: score,
      ),
    );
  }
}

/// 점수 상세 정보 시트 - 토스 스타일
class _HostScoreDetailsSheet extends StatelessWidget {
  final String hostId;
  final double currentScore;

  const _HostScoreDetailsSheet({
    Key? key,
    required this.hostId,
    required this.currentScore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들 바
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textDisabled,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  '운영 신뢰도 상세',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 현재 점수 카드
                  HostTrustScoreWidget(
                    score: currentScore,
                    showDetails: true,
                    isCompact: false,
                  ),
                  const SizedBox(height: 32),
                  // 신뢰도란? 섹션
                  _buildSection(
                    title: '신뢰도란?',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '주최자가 토너먼트를 얼마나 성실하게 운영하는지를 나타내는 지표입니다. 참가자들의 평가를 바탕으로 계산되며, 높을수록 신뢰할 수 있는 주최자입니다.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 평가 기준 섹션
                  _buildSection(
                    title: '평가 기준',
                    content: Column(
                      children: [
                        _buildCriteriaItem('시간 준수 및 공정한 진행'),
                        _buildCriteriaItem('원활한 소통 및 문제 해결'),
                        _buildCriteriaItem('규칙 준수 및 매너 있는 운영'),
                        _buildCriteriaItem('참가자들의 만족도'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 최근 평가 섹션
                  _buildRecentEvaluations(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSection({required String title, required Widget content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }
  
  Widget _buildCriteriaItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 12,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecentEvaluations() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('evaluations')
          .where('targetUserId', isEqualTo: hostId)
          .where('isHost', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final evaluations = snapshot.data!.docs;
        if (evaluations.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.backgroundGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.assessment_outlined,
                    size: 32,
                    color: AppColors.textDisabled,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '아직 평가 내역이 없습니다',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '최근 평가',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...evaluations.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final score = (data['score'] as num?)?.toDouble() ?? 0;
              final createdAt = (data['createdAt'] as Timestamp).toDate();
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: score >= 80 
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.warning.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          score >= 80 ? '😊' : '😐',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${score.toInt()}점',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return '오늘';
    } else if (difference.inDays == 1) {
      return '어제';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}주 전';
    } else {
      return '${(difference.inDays / 30).floor()}개월 전';
    }
  }
}

// 점수 데이터 클래스
class _ScoreData {
  final Color backgroundColor;
  final Color textColor;
  final String shortText;
  final String fullText;

  _ScoreData({
    required this.backgroundColor,
    required this.textColor,
    required this.shortText,
    required this.fullText,
  });
} 