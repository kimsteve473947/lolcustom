import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/services/participant_trust_score_manager.dart';
import 'package:lol_custom_game_manager/models/participant_evaluation_model.dart';

/// 참가자 신뢰도 점수 위젯
class ParticipantTrustScoreWidget extends StatelessWidget {
  final double score;
  final bool showDetails;
  final bool isCompact;
  final bool showBadge;
  final bool isHonorParticipant;
  
  const ParticipantTrustScoreWidget({
    Key? key,
    required this.score,
    this.showDetails = true,
    this.isCompact = false,
    this.showBadge = true,
    this.isHonorParticipant = false,
  }) : super(key: key);
  
  Color get scoreColor {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.yellow[700]!;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
  
  IconData get scoreIcon {
    if (score >= 90) return Icons.verified_user;
    if (score >= 70) return Icons.person;
    if (score >= 50) return Icons.warning_amber;
    return Icons.error_outline;
  }
  
  String get statusText {
    if (score >= 90) return '매우 신뢰할 수 있는 참가자예요';
    if (score >= 70) return '일반적인 참가자입니다';
    if (score >= 50) return '최근 평가가 낮아요';
    return '주의가 필요한 유저입니다';
  }
  
  String get shortStatusText {
    if (score >= 90) return '우수';
    if (score >= 70) return '일반';
    if (score >= 50) return '주의';
    return '위험';
  }
  
  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactView();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scoreColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                scoreIcon,
                color: scoreColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '참가자 신뢰도',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (isHonorParticipant && showBadge) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.star,
                        size: 12,
                        color: Colors.amber,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '명예 참가자',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '점',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 점수 바
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
              minHeight: 8,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    scoreIcon,
                    size: 16,
                    color: scoreColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 14,
                        color: scoreColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildCompactView() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: scoreColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scoreColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            scoreIcon,
            size: 16,
            color: scoreColor,
          ),
          const SizedBox(width: 6),
          Text(
            '${score.toStringAsFixed(0)}점',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: scoreColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '- $shortStatusText',
            style: TextStyle(
              fontSize: 12,
              color: scoreColor,
            ),
          ),
          if (isHonorParticipant && showBadge) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.star,
              size: 14,
              color: Colors.amber,
            ),
          ],
        ],
      ),
    );
  }
}

/// 참가자 신뢰도 히스토리 위젯
class ParticipantTrustHistoryWidget extends StatelessWidget {
  final List<ParticipantTrustHistory> history;
  final int maxItems;
  
  const ParticipantTrustHistoryWidget({
    Key? key,
    required this.history,
    this.maxItems = 5,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final displayHistory = history.take(maxItems).toList();
    
    if (displayHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.textSecondary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              '아직 참가 기록이 없어요',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  '최근 참가 기록',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...displayHistory.map((record) => _buildHistoryItem(record)),
        ],
      ),
    );
  }
  
  Widget _buildHistoryItem(ParticipantTrustHistory record) {
    final isPositive = record.scoreChange >= 0;
    final color = isPositive ? Colors.green : Colors.red;
    final icon = isPositive ? Icons.add_circle : Icons.remove_circle;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.textSecondary.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  record.reason,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : ''}${record.scoreChange}점',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(record.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}분 전';
      }
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}일 전';
    } else {
      return '${date.month}월 ${date.day}일';
    }
  }
} 