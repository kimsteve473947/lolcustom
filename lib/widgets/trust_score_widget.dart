import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/evaluation_model.dart';

class TrustScoreWidget extends StatelessWidget {
  final double score;
  final bool isHost;
  final bool showDetails;
  final double? evaluationRate;

  const TrustScoreWidget({
    Key? key,
    required this.score,
    required this.isHost,
    this.showDetails = false,
    this.evaluationRate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final trustInfo = TrustScoreInfo.fromScore(score, isHost: isHost);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showDetails ? 16 : 12,
        vertical: showDetails ? 12 : 6,
      ),
      decoration: BoxDecoration(
        color: Color(int.parse(trustInfo.colorCode.replaceFirst('#', '0xFF')))
            .withOpacity(0.15),
        borderRadius: BorderRadius.circular(showDetails ? 16 : 12),
        border: Border.all(
          color: Color(int.parse(trustInfo.colorCode.replaceFirst('#', '0xFF')))
              .withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            trustInfo.emoji,
            style: TextStyle(fontSize: showDetails ? 20 : 16),
          ),
          SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trustInfo.statusText,
                  style: TextStyle(
                    fontSize: showDetails ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showDetails && evaluationRate != null) ...[
                  SizedBox(height: 4),
                  Text(
                    '평가 참여율: ${(evaluationRate! * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 간단한 신뢰도 표시 아이콘
class TrustScoreBadge extends StatelessWidget {
  final double score;
  final double size;

  const TrustScoreBadge({
    Key? key,
    required this.score,
    this.size = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final trustInfo = TrustScoreInfo.fromScore(score);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(int.parse(trustInfo.colorCode.replaceFirst('#', '0xFF'))),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          trustInfo.emoji,
          style: TextStyle(fontSize: size * 0.6),
        ),
      ),
    );
  }
}

// 신뢰 점수 상세 정보 다이얼로그
class TrustScoreDetailDialog extends StatelessWidget {
  final double hostScore;
  final double playerScore;
  final double evaluationRate;

  const TrustScoreDetailDialog({
    Key? key,
    required this.hostScore,
    required this.playerScore,
    required this.evaluationRate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user,
                  color: AppColors.primary,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  '신뢰 점수',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            
            // 주최자 점수
            _buildScoreItem(
              title: '주최자 신뢰도',
              score: hostScore,
              isHost: true,
            ),
            SizedBox(height: 16),
            
            // 참가자 점수
            _buildScoreItem(
              title: '참가자 신뢰도',
              score: playerScore,
              isHost: false,
            ),
            SizedBox(height: 16),
            
            // 평가 참여율
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.rate_review,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '평가 참여율',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${(evaluationRate * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '확인',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreItem({
    required String title,
    required double score,
    required bool isHost,
  }) {
    final trustInfo = TrustScoreInfo.fromScore(score, isHost: isHost);
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(int.parse(trustInfo.colorCode.replaceFirst('#', '0xFF')))
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(int.parse(trustInfo.colorCode.replaceFirst('#', '0xFF')))
              .withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Text(
            trustInfo.emoji,
            style: TextStyle(fontSize: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  trustInfo.statusText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(int.parse(trustInfo.colorCode.replaceFirst('#', '0xFF'))),
            ),
          ),
        ],
      ),
    );
  }
} 