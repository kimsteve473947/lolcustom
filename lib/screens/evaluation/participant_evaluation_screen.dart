import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/services/participant_trust_score_manager.dart';

/// 참가자 평가 화면
class ParticipantEvaluationScreen extends StatefulWidget {
  final TournamentModel tournament;
  final List<UserModel> participants;
  final String evaluatorId;
  
  const ParticipantEvaluationScreen({
    Key? key,
    required this.tournament,
    required this.participants,
    required this.evaluatorId,
  }) : super(key: key);
  
  @override
  State<ParticipantEvaluationScreen> createState() => _ParticipantEvaluationScreenState();
}

class _ParticipantEvaluationScreenState extends State<ParticipantEvaluationScreen> {
  final ParticipantTrustScoreManager _scoreManager = ParticipantTrustScoreManager();
  
  // 평가 상태 관리
  final Map<String, Map<String, bool>> _evaluations = {};
  final Map<String, TextEditingController> _commentControllers = {};
  final Set<String> _submittedParticipants = {};
  bool _isSubmitting = false;
  
  @override
  void initState() {
    super.initState();
    _initializeEvaluations();
  }
  
  void _initializeEvaluations() {
    for (final participant in widget.participants) {
      _evaluations[participant.uid] = {
        'onTimeAttendance': false,
        'completedMatch': false,
        'goodManner': false,
        'activeParticipation': false,
        'followedRules': false,
        'noShow': false,
        'late': false,
        'leftEarly': false,
        'badManner': false,
        'trolling': false,
      };
      _commentControllers[participant.uid] = TextEditingController();
    }
  }
  
  @override
  void dispose() {
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('참가자 평가'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.participants.length,
              itemBuilder: (context, index) {
                final participant = widget.participants[index];
                return _buildParticipantCard(participant);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sports_esports,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.tournament.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '경기 종료 후 참가자들을 평가해주세요. 평가는 참가자의 신뢰도 점수에 반영됩니다.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildParticipantCard(UserModel participant) {
    final isSubmitted = _submittedParticipants.contains(participant.uid);
    final evaluation = _evaluations[participant.uid]!;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSubmitted 
              ? Colors.green.withOpacity(0.3)
              : AppColors.textSecondary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 참가자 정보
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSubmitted 
                  ? Colors.green.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child:                       Text(
                        participant.nickname[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participant.nickname,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        participant.riotId ?? '소환사명 미등록',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSubmitted) ...[
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  ),
                ],
              ],
            ),
          ),
          
          if (!isSubmitted) ...[
            const Divider(height: 1),
            
            // 긍정적 평가
            _buildEvaluationSection(
              title: '긍정적 평가',
              icon: Icons.thumb_up,
              color: Colors.green,
              items: [
                EvaluationItem(
                  key: 'onTimeAttendance',
                  label: '정시에 입장했어요',
                  icon: Icons.access_time,
                ),
                EvaluationItem(
                  key: 'completedMatch',
                  label: '끝까지 참여했어요',
                  icon: Icons.check_circle_outline,
                ),
                EvaluationItem(
                  key: 'goodManner',
                  label: '매너가 좋았어요',
                  icon: Icons.sentiment_satisfied_alt,
                ),
                EvaluationItem(
                  key: 'activeParticipation',
                  label: '적극적으로 참여했어요',
                  icon: Icons.sports_handball,
                ),
                EvaluationItem(
                  key: 'followedRules',
                  label: '규칙을 잘 지켰어요',
                  icon: Icons.rule,
                ),
              ],
              participantId: participant.uid,
            ),
            
            const Divider(height: 1),
            
            // 부정적 평가
            _buildEvaluationSection(
              title: '부정적 평가',
              icon: Icons.thumb_down,
              color: Colors.red,
              items: [
                EvaluationItem(
                  key: 'noShow',
                  label: '무단으로 불참했어요',
                  icon: Icons.person_off,
                ),
                EvaluationItem(
                  key: 'late',
                  label: '10분 이상 지각했어요',
                  icon: Icons.schedule,
                ),
                EvaluationItem(
                  key: 'leftEarly',
                  label: '중도 이탈했어요',
                  icon: Icons.exit_to_app,
                ),
                EvaluationItem(
                  key: 'badManner',
                  label: '비매너 행위를 했어요',
                  icon: Icons.sentiment_dissatisfied,
                ),
                EvaluationItem(
                  key: 'trolling',
                  label: '트롤링을 했어요',
                  icon: Icons.warning,
                ),
              ],
              participantId: participant.uid,
            ),
            
            // 추가 코멘트
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _commentControllers[participant.uid],
                decoration: InputDecoration(
                  labelText: '추가 코멘트 (선택)',
                  hintText: '참가자에 대한 추가 의견을 남겨주세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
                maxLines: 2,
              ),
            ),
            
            // 제출 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting 
                      ? null 
                      : () => _submitEvaluation(participant),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    '평가 제출',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildEvaluationSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<EvaluationItem> items,
    required String participantId,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              final isSelected = _evaluations[participantId]![item.key] ?? false;
              
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(item.label),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _evaluations[participantId]![item.key] = selected;
                  });
                },
                selectedColor: color,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Future<void> _submitEvaluation(UserModel participant) async {
    final evaluation = _evaluations[participant.uid]!;
    
    // 평가 항목이 하나도 선택되지 않은 경우
    final hasPositive = evaluation['onTimeAttendance']! ||
        evaluation['completedMatch']! ||
        evaluation['goodManner']! ||
        evaluation['activeParticipation']! ||
        evaluation['followedRules']!;
    
    final hasNegative = evaluation['noShow']! ||
        evaluation['late']! ||
        evaluation['leftEarly']! ||
        evaluation['badManner']! ||
        evaluation['trolling']!;
    
    if (!hasPositive && !hasNegative) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 하나 이상의 평가 항목을 선택해주세요.')),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      await _scoreManager.submitParticipantEvaluation(
        tournamentId: widget.tournament.id,
        tournamentTitle: widget.tournament.title,
        participantId: participant.uid,
        evaluatorId: widget.evaluatorId,
        onTimeAttendance: evaluation['onTimeAttendance']!,
        completedMatch: evaluation['completedMatch']!,
        goodManner: evaluation['goodManner']!,
        activeParticipation: evaluation['activeParticipation']!,
        followedRules: evaluation['followedRules']!,
        noShow: evaluation['noShow']!,
        late: evaluation['late']!,
        leftEarly: evaluation['leftEarly']!,
        badManner: evaluation['badManner']!,
        trolling: evaluation['trolling']!,
        comment: _commentControllers[participant.uid]!.text.trim().isEmpty 
            ? null 
            : _commentControllers[participant.uid]!.text.trim(),
      );
      
      setState(() {
        _submittedParticipants.add(participant.uid);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${participant.nickname}님 평가가 완료되었습니다.')),
      );
      
      // 모든 참가자 평가 완료 시
      if (_submittedParticipants.length == widget.participants.length) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('평가 완료'),
            content: const Text('모든 참가자 평가가 완료되었습니다.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('평가 제출 실패: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}

/// 평가 항목 모델
class EvaluationItem {
  final String key;
  final String label;
  final IconData icon;
  
  const EvaluationItem({
    required this.key,
    required this.label,
    required this.icon,
  });
} 