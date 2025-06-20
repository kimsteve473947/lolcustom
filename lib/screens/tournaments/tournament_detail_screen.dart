import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/providers/chat_provider.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/services/tournament_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:lol_custom_game_manager/utils/image_utils.dart';
import 'package:lol_custom_game_manager/utils/tournament_ui_utils.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/screens/main_screen.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';
import 'package:lol_custom_game_manager/widgets/lane_icon_widget.dart';
import 'package:lol_custom_game_manager/widgets/host_trust_score_widget.dart';
import 'package:lol_custom_game_manager/widgets/participant_trust_score_widget.dart';
import 'package:lol_custom_game_manager/services/participant_trust_score_manager.dart';
import 'package:lol_custom_game_manager/screens/evaluation/participant_evaluation_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lol_custom_game_manager/utils/image_utils.dart';

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;
  
  const TournamentDetailScreen({
    Key? key,
    required this.tournamentId,
  }) : super(key: key);

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

/// 토스 스타일 운영 신뢰도 상세 시트
class _TossStyleHostTrustSheet extends StatelessWidget {
  final String hostId;
  final String hostName;
  final String? hostProfileUrl;
  final double currentScore;

  const _TossStyleHostTrustSheet({
    Key? key,
    required this.hostId,
    required this.hostName,
    this.hostProfileUrl,
    required this.currentScore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 핸들 바
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 헤더
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFF0F0F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF0F0F0),
                      width: 1,
                    ),
                  ),
                  child: ClipOval(
                    child: hostProfileUrl != null
                        ? Image.network(
                            hostProfileUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.person, size: 24, color: Color(0xFF999999)),
                          )
                        : const Icon(Icons.person, size: 24, color: Color(0xFF999999)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hostName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '운영 신뢰도 상세',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF666666)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 현재 점수 카드
                  _buildScoreCard(),
                  const SizedBox(height: 32),
                  // 신뢰도란? 섹션
                  _buildInfoSection(
                    icon: Icons.help_outline,
                    title: '신뢰도란?',
                    content: '주최자가 토너먼트를 얼마나 성실하게 운영하는지를 나타내는 지표입니다. 참가자들의 평가를 바탕으로 계산되며, 높을수록 신뢰할 수 있는 주최자입니다.',
                  ),
                  const SizedBox(height: 24),
                  // 평가 기준 섹션
                  _buildCriteriaSection(),
                  const SizedBox(height: 24),
                  // 주최자 통계
                  _buildHostStats(),
                  const SizedBox(height: 24),
                  // 최근 평가
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

  Widget _buildScoreCard() {
    final scoreData = _getScoreData(currentScore);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scoreData.backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '운영 신뢰도',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: scoreData.textColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                scoreData.emoji,
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(width: 16),
              Text(
                '${currentScore.toInt()}',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: scoreData.textColor,
                  height: 1,
                ),
              ),
              Text(
                '점',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: scoreData.textColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              scoreData.description,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scoreData.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF666666)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaSection() {
    final criteria = [
      '시간 준수 및 공정한 진행',
      '원활한 소통 및 문제 해결',
      '규칙 준수 및 매너 있는 운영',
      '참가자들의 만족도',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.checklist, size: 20, color: Color(0xFF666666)),
              SizedBox(width: 8),
              Text(
                '평가 기준',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...criteria.map((criterion) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  criterion,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildHostStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .where('hostId', isEqualTo: hostId)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        int hostedCount = 0;
        int totalParticipants = 0;
        
        if (snapshot.hasData) {
          // completed 상태인 토너먼트만 카운트
          hostedCount = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            // 10명이 모두 찬 토너먼트의 참가자만 카운트
            final participants = (data['participants'] as List?)?.length ?? 0;
            if (participants >= 10) {
              totalParticipants += participants;
            }
          }
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFF0F0F0)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.bar_chart, size: 20, color: Color(0xFF666666)),
                  SizedBox(width: 8),
                  Text(
                    '주최자 통계',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.emoji_events,
                      value: hostedCount.toString(),
                      label: '주최한 내전',
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: const Color(0xFFF0F0F0),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.star,
                      value: currentScore.toStringAsFixed(1),
                      label: '평균 평점',
                      color: const Color(0xFFFFC107),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: const Color(0xFFF0F0F0),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.people,
                      value: totalParticipants.toString(),
                      label: '총 참가자',
                      color: const Color(0xFF2196F3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF999999),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentEvaluations() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('evaluations')
          .where('toUserId', isEqualTo: hostId)
          .where('type', isEqualTo: 'hostEvaluation')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: const [
                  Icon(
                    Icons.assessment_outlined,
                    size: 32,
                    color: Color(0xFFCCCCCC),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '아직 평가 내역이 없습니다',
                    style: TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFF0F0F0)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.rate_review, size: 20, color: Color(0xFF666666)),
                  SizedBox(width: 8),
                  Text(
                    '최근 평가',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...snapshot.data!.docs.take(5).map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final positiveItems = List<String>.from(data['positiveItems'] ?? []);
                final negativeItems = List<String>.from(data['negativeItems'] ?? []);
                final calculatedScore = (data['calculatedScore'] as num?)?.toDouble() ?? 0.0;
                final createdAt = (data['createdAt'] as Timestamp).toDate();
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: calculatedScore > 0 
                                  ? const Color(0xFF4CAF50).withOpacity(0.1)
                                  : const Color(0xFFF44336).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${calculatedScore > 0 ? "+" : ""}${calculatedScore.toStringAsFixed(1)}점',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: calculatedScore > 0 
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFF44336),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            DateFormat('MM.dd').format(createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF999999),
                            ),
                          ),
                        ],
                      ),
                      if (positiveItems.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: positiveItems.take(2).map((item) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                      if (negativeItems.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: negativeItems.take(2).map((item) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF44336).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFF44336),
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  _ScoreData _getScoreData(double score) {
    if (score >= 90) {
      return _ScoreData(
        backgroundColor: const Color(0xFFE8F5E9),
        textColor: const Color(0xFF2E7D32),
        emoji: '👍',
        description: '매우 신뢰할 수 있는 주최자',
      );
    } else if (score >= 70) {
      return _ScoreData(
        backgroundColor: const Color(0xFFFFF8E1),
        textColor: const Color(0xFFF57C00),
        emoji: '😊',
        description: '신뢰할 수 있는 주최자',
      );
    } else if (score >= 50) {
      return _ScoreData(
        backgroundColor: const Color(0xFFFFF3E0),
        textColor: const Color(0xFFE65100),
        emoji: '🙂',
        description: '일반적인 수준의 주최자',
      );
    } else if (score >= 30) {
      return _ScoreData(
        backgroundColor: const Color(0xFFFFEBEE),
        textColor: const Color(0xFFD32F2F),
        emoji: '😐',
        description: '주의가 필요한 주최자',
      );
    } else {
      return _ScoreData(
        backgroundColor: const Color(0xFFFFEBEE),
        textColor: const Color(0xFFB71C1C),
        emoji: '😟',
        description: '신뢰도가 매우 낮은 주최자',
      );
    }
  }
}

class _ScoreData {
  final Color backgroundColor;
  final Color textColor;
  final String emoji;
  final String description;

  _ScoreData({
    required this.backgroundColor,
    required this.textColor,
    required this.emoji,
    required this.description,
  });
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ParticipantTrustScoreManager _participantScoreManager = ParticipantTrustScoreManager();
  
  TournamentModel? _tournament;
  List<ApplicationModel> _applications = [];
  bool _isLoading = true;
  bool _isApplying = false; // 신청 중 상태
  bool _isJoining = false;
  bool _isLeaving = false;
  String? _errorMessage;
  String _selectedRole = 'top'; // nullable이 아닌 타입으로 변경하고 기본값 설정
  
  // 스크롤 컨트롤러 추가
  final ScrollController _scrollController = ScrollController();
  
  // 참가자 점수 캐시
  final Map<String, double> _participantScoreCache = {};
  
  @override
  void initState() {
    super.initState();
    _loadTournamentDetails();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  // 참가자 점수 가져오기
  Future<double> _getParticipantScore(String userId) async {
    if (_participantScoreCache.containsKey(userId)) {
      return _participantScoreCache[userId]!;
    }
    
    try {
      final info = await _participantScoreManager.getParticipantTrustInfo(userId);
      _participantScoreCache[userId] = info.score;
      return info.score;
    } catch (e) {
      debugPrint('Error getting participant score: $e');
      return 70.0; // 기본값
    }
  }
  
  // 참가자 점수에 따른 색상
  Color _getParticipantScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.yellow[700]!;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
  
  // 스크롤을 아래로 이동하는 메서드
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  Future<void> _loadTournamentDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 토너먼트 정보 로드
      final tournament = await _firebaseService.getTournament(widget.tournamentId);
      if (tournament == null) {
        setState(() {
          _errorMessage = '토너먼트 정보를 찾을 수 없습니다';
          _isLoading = false;
        });
        return;
      }

      // 신청 목록 로드
      final applications = await _firebaseService.getTournamentApplications(widget.tournamentId);

      setState(() {
        _tournament = tournament;
        _applications = applications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '토너먼트 정보를 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _applyToTournament() async {
    if (_tournament == null) return;

    setState(() {
      _isApplying = true;
    });

    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      if (appState.currentUser == null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('오류'),
            content: const Text('로그인이 필요합니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        return;
      }

      final success = await appState.joinTournamentByRole(
        tournamentId: _tournament!.id,
        role: _selectedRole,
      );

      if (success) {
        // 참가 후 채팅방이 있는지 확인하여 자동으로 추가
        final chatRoomId = await _firebaseService.findChatRoomByTournamentId(_tournament!.id);
        if (chatRoomId != null) {
          // 채팅방에 사용자 추가
          await _firebaseService.addParticipantToChatRoom(
            chatRoomId,
            appState.currentUser!.uid,
            appState.currentUser!.nickname,
            appState.currentUser!.profileImageUrl,
          );
        }

        // 토너먼트 정보 새로고침을 먼저 실행하고 완료될 때까지 기다림
        await _loadTournamentDetails();

        // 알림 표시
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('신청 완료'),
              content: const Text('신청이 완료되었습니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      } else {
        // 오류 발생
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('신청 오류'),
              content: Text(appState.errorMessage ?? '신청 중 오류가 발생했습니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error applying to tournament: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('오류 발생'),
            content: Text('신청 중 오류가 발생했습니다: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }
  
  Future<void> _startChat() async {
    if (_tournament == null) return;
    
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (appState.currentUser == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('오류'),
          content: const Text('로그인이 필요합니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 내전 주최자의 정보 가져오기
      final hostUser = await _firebaseService.getUserById(_tournament!.hostId);
      
      if (hostUser == null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('오류'),
            content: const Text('주최자 정보를 불러올 수 없습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        return;
      }
      
      // 채팅방이 이미 존재하는지 확인
      final existingChatRoomId = await _firebaseService.findChatRoomByTournamentId(_tournament!.id);
      debugPrint('Existing chat room ID for tournament ${_tournament!.id}: $existingChatRoomId');
      
      if (existingChatRoomId != null) {
        // 이미 존재하는 채팅방으로 이동
        context.go('/chat/$existingChatRoomId');
      } else {
        // 새 채팅방 생성
        final chatRoomId = await appState.createChatRoom(
          targetUserId: _tournament!.hostId,
          title: _tournament!.title,
          type: ChatRoomType.tournamentRecruitment,
          initialMessage: '${appState.currentUser!.nickname}님이 내전 채팅방에 참가했습니다.',
          tournamentId: _tournament!.id,
        );
        
        if (chatRoomId != null) {
          // 채팅방으로 이동 - 채팅방 아이디로 직접 이동하기
          context.go('/chat/$chatRoomId');
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('오류'),
              content: const Text('채팅방 생성에 실패했습니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('오류 발생'),
          content: Text('오류가 발생했습니다: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final hasApplied = _tournament != null && appState.currentUser != null && _applications.any((app) => 
        app.userUid == appState.currentUser!.uid && 
        app.status != ApplicationStatus.cancelled && 
        app.status != ApplicationStatus.rejected);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // 자동 뒤로가기 버튼 비활성화
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          if (_tournament != null)
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.share, color: Colors.black),
                onPressed: () {
                  // TODO: Implement share functionality
                },
              ),
            ),
          if (_isUserHost() && _tournament != null)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '내전 취소',
              onPressed: _deleteTournament,
            ),
        ],
      ),
      body: SafeArea(
        child: _errorMessage != null
          ? ErrorView(
              errorMessage: _errorMessage!,
              onRetry: _loadTournamentDetails,
            )
          : _isLoading && _tournament == null
              ? const LoadingIndicator()
              : _tournament == null
                  ? const Center(child: Text('내전 정보를 불러올 수 없습니다'))
                  : _buildContent(),
      ),
      bottomNavigationBar: _tournament != null
          ? _isUserHost()
              ? _buildHostActionButtons()  // 주최자 액션 버튼
              : _hasUserApplied() || _tournament!.status == TournamentStatus.open
                  ? _buildParticipationButtons()  // 참가 버튼 표시 위젯을 호출
                  : null
          : null,
    );
  }
  
  bool _isUserHost() {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final currentUserId = appState.currentUser?.uid;
    
    return _tournament != null && 
           currentUserId != null &&
           _tournament!.hostId == currentUserId;
  }
  
  Widget _buildContent() {
    return CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverToBoxAdapter(
            child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFF0F0F0),
                  width: 1,
                ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                    _tournament!.title,
                    style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                          height: 1.2,
                        ),
                    ),
                  ),
                    const SizedBox(width: 12),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        color: _getStatusColor(),
                      ),
                    ),
                    ),
                  ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFF0F0F0),
                          width: 1,
                        ),
                      ),
                      child: ClipOval(
                        child: _tournament!.hostProfileImageUrl != null
                            ? Image.network(
                                _tournament!.hostProfileImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.person, size: 16, color: Color(0xFF999999)),
                              )
                            : const Icon(Icons.person, size: 16, color: Color(0xFF999999)),
                      ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                          _tournament!.hostNickname ?? _tournament!.hostName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // 주최자 신뢰도 표시
                          HostTrustScoreLoader(
                            hostId: _tournament!.hostId,
                            isCompact: true,
                            showDetails: true,
                          ),
                        ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('yyyy.MM.dd').format(_tournament!.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time and date card
                  _buildDateTimeCard(),
                  
                  // Description
                  if (_tournament!.description != null && _tournament!.description!.isNotEmpty) ...[
                    _buildSectionTitle('내전 소개'),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _tournament!.description!,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Referee info
                  if (_tournament!.tournamentType == TournamentType.competitive) ...[
                    _buildRefereeInfo(),
                    if (_isUserHost() && _tournament!.status != TournamentStatus.completed)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: _buildRefereeManagementButtons(),
                      ),
                    const SizedBox(height: 24),
                  ],
                  
                  // 포지션별 참가 현황 및 참가자 목록 (통합된 UI)
                  _buildRolesList(),
                  const SizedBox(height: 24),
                  
                  // Host info
                  _buildHostInfo(),
                  
                  const SizedBox(height: 50), // Extra space for bottom button
                ],
              ),
            ),
          ),
        ],
    );
  }
  
  Widget _buildRefereeInfo() {
    if (_tournament == null || !_tournament!.isRefereed) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('심판 정보'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_off,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      '아직 배정된 심판이 없습니다.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('심판 정보'),
            const SizedBox(height: 16),
            if (_tournament!.referees != null && _tournament!.referees!.isNotEmpty)
              FutureBuilder<List<UserModel>>(
                future: _fetchReferees(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '심판 정보를 불러오는 중 오류가 발생했습니다: ${snapshot.error}',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  final referees = snapshot.data ?? [];
                  if (referees.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey),
                          SizedBox(width: 16),
                          Text('심판 정보가 없습니다.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  
                  return Column(
                    children: referees.map((referee) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade100,
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            ImageUtils.safeCircleAvatar(
                              imageUrl: referee.profileImageUrl,
                              radius: 20,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    referee.nickname ?? '익명',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Text(
                                      '심판',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
  
  Future<List<UserModel>> _fetchReferees() async {
    if (_tournament == null || _tournament!.referees == null || _tournament!.referees!.isEmpty) {
      return [];
    }
    
    try {
      final tournamentService = Provider.of<TournamentService>(context, listen: false);
      return await tournamentService.getTournamentReferees(_tournament!.id);
    } catch (e) {
      debugPrint('Error fetching referees: $e');
      return [];
    }
  }
  
  Widget _buildRolesList() {
    // Define role data in the correct order
    final roles = [
      {'name': '탑', 'key': 'top'},
      {'name': '정글', 'key': 'jungle'},
      {'name': '미드', 'key': 'mid'},
      {'name': '원딜', 'key': 'adc'},
      {'name': '서폿', 'key': 'support'},
    ];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('포지션별 참가 현황', useOrange: true),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${_tournament!.participants.length}/${_calculateTotalSlots()}명',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 포지션별 참가 현황을 세로로 배치 - 새로운 디자인
            Column(
              children: roles.map((role) {
                final key = role['key'] as String;
                final filled = _tournament!.filledSlotsByRole[key] ?? 0;
                final total = _tournament!.slotsByRole[key] ?? 2;
                final progress = total > 0 ? filled / total : 0.0;
                final isFull = filled >= total;
                
                // 해당 포지션의 참가자 목록 가져오기
                final participants = _tournament!.participantsByRole[key] ?? [];
                final applications = _applications.where((app) => 
                  app.role == key && app.status == ApplicationStatus.accepted).toList();
                
                // 역할별 색상 가져오기
                Color getRoleColor() {
                  switch (key) {
                    case 'top': return const Color(0xFFE74C3C);
                    case 'jungle': return const Color(0xFF27AE60);
                    case 'mid': return const Color(0xFF3498DB);
                    case 'adc': return const Color(0xFFF39C12);
                    case 'support': return const Color(0xFF9B59B6);
                    default: return AppColors.primary;
                  }
                }
                
                final roleColor = getRoleColor();
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: roleColor.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade100,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더 - 포지션 정보와 참가 현황
                      GestureDetector(
                        onTap: () {
                          // 모집이 마감되지 않았고 호스트가 아닐 때만 선택 가능
                          if (filled < total && !_isUserHost() && _tournament!.status == TournamentStatus.open) {
                            setState(() {
                              _selectedRole = key;
                            });
                            // 선택 후 아래로 스크롤하여 신청 버튼이 보이게 함
                            _scrollToBottom();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedRole == key 
                                ? roleColor.withOpacity(0.2) 
                                : roleColor.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              // 포지션 아이콘
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: roleColor,
                                    width: _selectedRole == key ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: LaneIconWidget(
                                    lane: key,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // 포지션 이름
                              Text(
                                role['name'] as String,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: roleColor,
                                ),
                              ),
                              const Spacer(),
                              // 참가 인원
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: roleColor),
                                ),
                                child: Text(
                                  '$filled/$total',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: roleColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // 참가자 목록
                      if (participants.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 참가자 목록 헤더
                              Row(
                                children: [
                                  Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Text(
                                    '참가자',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // 참가자 목록
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: applications.map((app) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: roleColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: roleColor.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ImageUtils.safeCircleAvatar(
                                          imageUrl: app.userProfileImageUrl,
                                          radius: 14,
                                          backgroundColor: roleColor.withOpacity(0.1),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          app.userName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        )
                      else if (filled == 0)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.person_off, size: 16, color: Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Text(
                                '아직 참가자가 없습니다',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
            
            // 역할 선택 안내 (신청 화면일 때만)
            if (!_isUserHost() && _tournament!.status == TournamentStatus.open) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(Icons.info_outline, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        '참가하려면 원하는 포지션을 선택하세요',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // 포지션 선택 버튼 (신청 화면일 때만)
            if (!_isUserHost() && _tournament!.status == TournamentStatus.open)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: roles.map((role) {
                    final key = role['key'] as String;
                    final filled = _tournament!.filledSlotsByRole[key] ?? 0;
                    final total = _tournament!.slotsByRole[key] ?? 2;
                    final isFull = filled >= total;
                    final isSelected = _selectedRole == key;
                    
                    // Get role-specific color
                    Color getRoleColor() {
                      switch (key) {
                        case 'top': return const Color(0xFFE74C3C);
                        case 'jungle': return const Color(0xFF27AE60);
                        case 'mid': return const Color(0xFF3498DB);
                        case 'adc': return const Color(0xFFF39C12);
                        case 'support': return const Color(0xFF9B59B6);
                        default: return AppColors.primary;
                      }
                    }
                    
                    final roleColor = getRoleColor();
                    
                    return SizedBox(
                      width: 55, // 모든 아이콘을 한 줄에 표시하기 위해 너비 조정
                      child: GestureDetector(
                        onTap: isFull ? null : () {
                          setState(() {
                            _selectedRole = key;
                          });
                        },
                        child: Container(
                          child: Opacity(
                            opacity: isFull ? 0.5 : 1.0,
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // 선택 표시 배경
                                    if (isSelected)
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: roleColor.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: roleColor,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    
                                    // 실제 아이콘 컨테이너
                                    Container(
                                      width: isSelected ? 42 : 40,
                                      height: isSelected ? 42 : 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? roleColor : Colors.grey.shade300,
                                          width: isSelected ? 2 : 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isSelected 
                                              ? roleColor.withOpacity(0.3)
                                              : Colors.grey.withOpacity(0.2),
                                            spreadRadius: 1,
                                            blurRadius: isSelected ? 6 : 3,
                                            offset: const Offset(0, 2),
                                          )
                                        ],
                                      ),
                                      child: Center(
                                        child: LaneIconWidget(
                                          lane: key,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${role['name']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? roleColor : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$filled/$total',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isFull 
                                      ? Colors.red.shade400 
                                      : (filled > 0 ? Colors.green.shade600 : Colors.grey.shade600),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPositionItemHorizontal(String key, String name) {
    final filled = _tournament!.filledSlotsByRole[key] ?? 0;
    final total = _tournament!.slotsByRole[key] ?? 2;
    final progress = total > 0 ? filled / total : 0.0;
    
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: _buildLaneIcon(key, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_tournament!.participantsByRole[key] != null && _tournament!.participantsByRole[key]!.isNotEmpty)
            ..._tournament!.participantsByRole[key]!.map((userId) {
              // 참가자 정보 찾기
              final app = _applications.firstWhere(
                (app) => app.userUid == userId && app.role == key,
                orElse: () => ApplicationModel(
                  id: '',
                  tournamentId: _tournament!.id,
                  userUid: userId,
                  userName: '참가자',
                  role: key,
                  message: '',
                  status: ApplicationStatus.accepted,
                  appliedAt: Timestamp.now(),
                ),
              );
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade100,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ImageUtils.safeCircleAvatar(
                      imageUrl: app.userProfileImageUrl,
                      radius: 18,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        app.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
  
  Widget _buildPositionItem(String key, {required List<Map<String, dynamic>> roles}) {
    final role = roles.firstWhere((r) => r['key'] == key);
    final filled = _tournament!.filledSlotsByRole[key] ?? 0;
    final total = _tournament!.slotsByRole[key] ?? 2;
    final progress = total > 0 ? filled / total : 0.0;
    
    // Get role-specific color for better visual distinction
    Color getRoleColor() {
      switch (key) {
        case 'top': return const Color(0xFFE74C3C);
        case 'jungle': return const Color(0xFF27AE60);
        case 'mid': return const Color(0xFF3498DB);
        case 'adc': return const Color(0xFFF39C12);
        case 'support': return const Color(0xFF9B59B6);
        default: return AppColors.primary;
      }
    }

    final roleColor = getRoleColor();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: roleColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: roleColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: roleColor,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: LaneIconWidget(
                    lane: key,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${role['name']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: roleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '참가자: $filled/$total명',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: roleColor,
                    width: 1,
                  ),
                ),
                child: Text(
                  isFull ? '모집 완료' : '모집 중',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: roleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  color: roleColor,
                  minHeight: 14,
                ),
                if (filled > 0)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        '$filled/$total',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_tournament!.participantsByRole[key]?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Text(
              '참가자',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: roleColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tournament!.participantsByRole[key]!.map((userId) {
                // 참가자 닉네임 찾기
                final app = _applications.firstWhere(
                  (app) => app.userUid == userId && app.role == key,
                  orElse: () => ApplicationModel(
                    id: '',
                    tournamentId: _tournament!.id,
                    userUid: userId,
                    userName: '참가자',
                    role: key,
                    message: '',
                    status: ApplicationStatus.accepted,
                    appliedAt: Timestamp.now(),
                  ),
                );
                
                return InkWell(
                  onTap: () async {
                    // 참가자 상세 정보 표시
                    final trustInfo = await _participantScoreManager.getParticipantTrustInfo(userId);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => Container(
                        height: MediaQuery.of(context).size.height * 0.7,
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ImageUtils.safeCircleAvatar(
                                  imageUrl: app.userProfileImageUrl,
                                  radius: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        app.userName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ParticipantTrustScoreWidget(
                                        score: trustInfo.score,
                                        isCompact: true,
                                        showBadge: true,
                                        isHonorParticipant: trustInfo.isHonorParticipant,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              child: SingleChildScrollView(
                                child: ParticipantTrustHistoryWidget(
                                  history: trustInfo.history,
                                  maxItems: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: roleColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (app.userProfileImageUrl != null) ...[
                        ImageUtils.safeCircleAvatar(
                          imageUrl: app.userProfileImageUrl,
                          radius: 14,
                          backgroundColor: roleColor.withOpacity(0.2),
                        ),
                        const SizedBox(width: 8),
                      ],
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                      Text(
                        app.userName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: roleColor,
                        ),
                      ),
                            // 참가자 신뢰도 점수 표시
                            FutureBuilder<double>(
                              future: _getParticipantScore(userId),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox.shrink();
                                }
                                final score = snapshot.data!;
                                final scoreColor = _getParticipantScoreColor(score);
                                return Text(
                                  '${score.toInt()}점',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: scoreColor,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                    ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
  
  bool get isFull => _tournament != null && 
    _tournament!.filledSlotsByRole[_selectedRole] != null && 
    _tournament!.slotsByRole[_selectedRole] != null && 
    _tournament!.filledSlotsByRole[_selectedRole]! >= _tournament!.slotsByRole[_selectedRole]!;
  
  Widget _buildPlayersList() {
    // Group applications by role
    final Map<String, List<ApplicationModel>> applicationsByRole = {};
    
    for (final app in _applications.where((app) => app.status == ApplicationStatus.accepted)) {
      if (!applicationsByRole.containsKey(app.role)) {
        applicationsByRole[app.role] = [];
      }
      applicationsByRole[app.role]!.add(app);
    }
    
    if (applicationsByRole.isEmpty) {
      return const SizedBox.shrink();
    }

    // Define the correct lane order
    final laneOrder = ['top', 'jungle', 'mid', 'adc', 'support'];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('참가자 목록', useOrange: true),
            const SizedBox(height: 16),
            // 포지션별 참가 현황을 가로로 나열
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: laneOrder.map((lane) {
                  if (!applicationsByRole.containsKey(lane) || applicationsByRole[lane]!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  
                  final roleName = _getRoleName(lane);
                  
                  // Get role-specific color
                  Color getRoleColor() {
                    switch (lane) {
                      case 'top': return const Color(0xFFE74C3C);
                      case 'jungle': return const Color(0xFF27AE60);
                      case 'mid': return const Color(0xFF3498DB);
                      case 'adc': return const Color(0xFFF39C12);
                      case 'support': return const Color(0xFF9B59B6);
                      default: return AppColors.primary;
                    }
                  }
                  
                  final roleColor = getRoleColor();
                  
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: roleColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: roleColor,
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    child: _buildLaneIcon(lane, size: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  roleName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: roleColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...applicationsByRole[lane]!.asMap().entries.map((playerEntry) {
                          final index = playerEntry.key;
                          final app = playerEntry.value;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: roleColor.withOpacity(0.3)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade100,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ImageUtils.safeCircleAvatar(
                                  imageUrl: app.userProfileImageUrl,
                                  radius: 18,
                                  backgroundColor: roleColor.withOpacity(0.1),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    app.userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getRoleName(String role) {
    return TournamentUIUtils.getRoleName(role);
  }
  
  Color _getRoleColor(String role) {
    // Return a neutral color instead of a role-specific color
    return Colors.grey.shade700;
  }
  
  String _getRoleImagePath(String role) {
    switch (role) {
      case 'top': return LolLaneIcons.top;
      case 'jungle': return LolLaneIcons.jungle;
      case 'mid': return LolLaneIcons.mid;
      case 'adc': return LolLaneIcons.adc;
      case 'support': return LolLaneIcons.support;
      default: return LolLaneIcons.top;
    }
  }
  
  // New method to render a lane icon using our custom widget
  Widget _buildLaneIcon(String role, {double size = 24}) {
    return LaneIconWidget(
      lane: role,
      size: size,
    );
  }
  
  Widget _buildHostInfo() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('주최자 정보'),
            const SizedBox(height: 16),
            // 주최자 신뢰도 표시 (상세 버전)
            HostTrustScoreLoader(
              hostId: _tournament!.hostId,
              isCompact: false,
              showDetails: true,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _showHostProfileInfo,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade100,
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ImageUtils.safeCircleAvatar(
                      imageUrl: _tournament!.hostProfileImageUrl,
                      radius: 30,
                      defaultIconSize: 30,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tournament!.hostNickname ?? _tournament!.hostName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.event_available,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '주최: ${DateFormat('yyyy.MM.dd').format(_tournament!.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _showHostProfileInfo() async {
    if (_tournament == null) return;
    
    try {
      // Fetch host user data for trust score
      final hostUser = await _firebaseService.getUserById(_tournament!.hostId);
      if (hostUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주최자 정보를 불러올 수 없습니다')),
        );
        return;
      }
      
      final hostScore = hostUser.hostScore ?? 80.0;
      
      if (!mounted) return;
      
      // Show trust score details bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _TossStyleHostTrustSheet(
          hostId: _tournament!.hostId,
          hostName: hostUser.nickname ?? '익명',
          hostProfileUrl: hostUser.profileImageUrl,
          currentScore: hostScore,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('주최자 정보를 불러오는 중 오류가 발생했습니다: $e')),
      );
    }
  }
  
  Future<List<TournamentModel>> _fetchHostedTournaments(String hostId) async {
    try {
      // Limit to maximum 10 recent tournaments
      final querySnapshot = await FirebaseFirestore.instance
          .collection('tournaments')
          .where('hostId', isEqualTo: hostId)
          .orderBy('startsAt', descending: true)
          .limit(10)
          .get();
      
      return querySnapshot.docs
          .map((doc) => TournamentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching hosted tournaments: $e');
      return [];
    }
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTournamentStatusChip(TournamentStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case TournamentStatus.draft:
        color = Colors.grey;
        text = '초안';
        break;
      case TournamentStatus.open:
        color = AppColors.success;
        text = '모집 중';
        break;
      case TournamentStatus.full:
        color = AppColors.primary;
        text = '모집 완료';
        break;
      case TournamentStatus.inProgress:
      case TournamentStatus.ongoing:
        color = AppColors.warning;
        text = '진행 중';
        break;
      case TournamentStatus.completed:
        color = AppColors.textSecondary;
        text = '완료됨';
        break;
      case TournamentStatus.cancelled:
        color = AppColors.error;
        text = '취소됨';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  String _getTierName(PlayerTier tier) {
    switch (tier) {
      case PlayerTier.iron:
        return '아이언';
      case PlayerTier.bronze:
        return '브론즈';
      case PlayerTier.silver:
        return '실버';
      case PlayerTier.gold:
        return '골드';
      case PlayerTier.platinum:
        return '플래티넘';
      case PlayerTier.emerald:
        return '에메랄드';
      case PlayerTier.diamond:
        return '다이아몬드';
      case PlayerTier.master:
        return '마스터';
      case PlayerTier.grandmaster:
        return '그랜드마스터';
      case PlayerTier.challenger:
        return '챌린저';
      default:
        return '없음';
    }
  }
  
  Widget _buildParticipationButtons() {
    final appState = Provider.of<AppStateProvider>(context);
    
    // 더 견고한 참가 여부 체크 - applications와 participants 모두 확인
    final hasAppliedInApplications = appState.currentUser != null && _applications.any((app) => 
        app.userUid == appState.currentUser!.uid && 
        app.status != ApplicationStatus.cancelled && 
        app.status != ApplicationStatus.rejected);
    
    final hasAppliedInParticipants = appState.currentUser != null && 
        _tournament != null && 
        _tournament!.participants.contains(appState.currentUser!.uid);
    
    final hasApplied = hasAppliedInApplications || hasAppliedInParticipants;
    
    debugPrint('🔍 참가 여부 체크: applications=$hasAppliedInApplications, participants=$hasAppliedInParticipants, final=$hasApplied');
    
    if (hasApplied) {
      final application = _applications.firstWhere(
        (app) => app.userUid == appState.currentUser!.uid && 
          app.status != ApplicationStatus.cancelled && 
          app.status != ApplicationStatus.rejected,
        orElse: () => ApplicationModel(
          id: '',
          tournamentId: _tournament!.id,
          userUid: appState.currentUser!.uid,
          userName: appState.currentUser!.nickname ?? '알 수 없음',
          role: _selectedRole,
          message: '',
          status: ApplicationStatus.pending,
          appliedAt: Timestamp.now(),
        ),
      );
      
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade100,
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _getRoleColor(_selectedRole).withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getRoleColor(_selectedRole),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: LaneIconWidget(
                        lane: _selectedRole, 
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '선택한 포지션: ${_getRoleName(_selectedRole)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(_selectedRole),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // 채팅방 이동 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _goToChatRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      disabledBackgroundColor: Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading 
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_outlined),
                              SizedBox(width: 8),
                              Text(
                                '채팅방으로 이동',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // 참가 취소 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _cancelRegistration(application.role),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade700,
                      minimumSize: const Size(double.infinity, 56),
                      disabledBackgroundColor: Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading 
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cancel_outlined),
                              SizedBox(width: 8),
                              Text(
                                '참가 취소',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getRoleColor(_selectedRole).withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getRoleColor(_selectedRole).withOpacity(0.1),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _getRoleColor(_selectedRole),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: LaneIconWidget(
                      lane: _selectedRole, 
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '선택한 포지션: ${_getRoleName(_selectedRole)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(_selectedRole),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 역할 선택 버튼 그룹
          _buildRoleButtons(),
          const SizedBox(height: 16),
          // 참가 신청 버튼
          ElevatedButton(
            onPressed: _isLoading ? null : _registerForTournament,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading 
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_esports),
                      SizedBox(width: 8),
                      Text(
                        '내전 참가 신청하기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _cancelRegistration(String role) async {
    if (_tournament == null) return;
    
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (appState.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }
    
    final isCompetitive = _tournament!.tournamentType == TournamentType.competitive;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('참가 취소 확인'),
        content: Text(isCompetitive 
          ? '정말로 참가를 취소하시겠습니까? 경쟁전 참가비 크레딧(20 크레딧)은 환불됩니다.'
          : '정말로 참가를 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('예, 취소합니다'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await appState.leaveTournamentByRole(
        tournamentId: widget.tournamentId,
        role: role,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCompetitive 
              ? '참가가 취소되었습니다. 크레딧이 환불되었습니다.'
              : '참가가 취소되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 토너먼트 정보와 참가 신청 정보를 다시 로드
        await _loadTournamentDetails();
      } else if (appState.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('참가 취소 중 오류가 발생했습니다'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error canceling tournament registration: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('참가 취소 중 오류가 발생했습니다: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // 심판 관리 버튼
  Widget _buildRefereeManagementButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('심판 추가'),
          onPressed: _showAddRefereeDialog,
        ),
      ],
    );
  }
  
  // 심판 추가 다이얼로그
  void _showAddRefereeDialog() {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('심판 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('추가할 심판의 사용자 ID를 입력하세요.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '사용자 ID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _addReferee(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
  
  // 심판 추가 처리
  Future<void> _addReferee(String refereeId) async {
    if (_tournament == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final tournamentService = Provider.of<TournamentService>(context, listen: false);
      await tournamentService.addReferee(_tournament!.id, refereeId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('심판이 추가되었습니다.')),
      );
      
      // 토너먼트 정보 다시 로드
      _loadTournamentDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('심판 추가 실패: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 심판 제거 처리
  Future<void> _removeReferee(String refereeId) async {
    if (_tournament == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final tournamentService = Provider.of<TournamentService>(context, listen: false);
      await tournamentService.removeReferee(_tournament!.id, refereeId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('심판이 제거되었습니다.')),
      );
      
      // 토너먼트 정보 다시 로드
      _loadTournamentDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('심판 제거 실패: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  String _getStatusText() {
    if (_tournament == null) return '';
    
    return TournamentUIUtils.getStatusText(_tournament!.status);
  }
  
  Color _getStatusColor() {
    if (_tournament == null) return Colors.grey;
    
    switch (_tournament!.status) {
      case TournamentStatus.open:
        return const Color(0xFF4CAF50); // 초록색
      case TournamentStatus.full:
        return const Color(0xFF2196F3); // 파란색
      case TournamentStatus.inProgress:
      case TournamentStatus.ongoing:
        return const Color(0xFFFF9800); // 주황색
      case TournamentStatus.completed:
        return const Color(0xFF9E9E9E); // 회색
      case TournamentStatus.cancelled:
        return const Color(0xFFF44336); // 빨간색
      default:
    return Colors.grey;
    }
  }
  
  int _calculateTotalSlots() {
    if (_tournament == null) return 0;
    
    return _tournament!.slotsByRole.values.fold(0, (sum, slots) => sum + slots);
  }
  
  Widget _buildSectionTitle(String title, {bool useOrange = false}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: useOrange ? AppColors.primary : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: useOrange ? AppColors.primary : Colors.black87,
          ),
        ),
      ],
    );
  }

  // 토너먼트 삭제 메서드
  // 주최자 액션 버튼
  Widget _buildHostActionButtons() {
    if (_tournament == null) return const SizedBox.shrink();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 경기 진행 상태에 따른 버튼 표시
          if (_tournament!.status == TournamentStatus.full ||
              _tournament!.status == TournamentStatus.inProgress ||
              _tournament!.status == TournamentStatus.ongoing) ...[
            // 경기 종료 및 평가 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showEndTournamentDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: const Text(
                  '경기 종료 및 참가자 평가',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ] else if (_tournament!.status == TournamentStatus.completed) ...[
            // 이미 종료된 경기 - 평가 수정 가능
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToEvaluation(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.rate_review, color: Colors.white),
                label: const Text(
                  '참가자 평가 수정',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // 경기 취소 버튼 (진행 중이 아닐 때만)
          if (_tournament!.status != TournamentStatus.completed) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleteTournament,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Colors.red),
                ),
                icon: const Icon(Icons.cancel, color: Colors.red),
                label: const Text(
                  '내전 취소',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // 경기 종료 확인 다이얼로그
  Future<void> _showEndTournamentDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('경기 종료'),
        content: const Text(
          '경기를 종료하고 참가자 평가를 진행하시겠습니까?\n\n'
          '경기 종료 후에는 참가자들을 평가할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('종료 및 평가'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await _endTournamentAndEvaluate();
    }
  }
  
  // 경기 종료 및 평가 화면으로 이동
  Future<void> _endTournamentAndEvaluate() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // 토너먼트 상태를 completed로 변경
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(_tournament!.id)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      
      // 평가 화면으로 이동
      _navigateToEvaluation();
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('오류'),
          content: Text('경기 종료 중 오류가 발생했습니다: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 참가자 평가 화면으로 이동
  void _navigateToEvaluation() {
    if (_tournament == null) return;
    
    // 참가자 목록 필터링 (accepted 상태인 참가자만)
    final participants = _applications
        .where((app) => app.status == ApplicationStatus.accepted)
        .map((app) => UserModel(
              uid: app.userUid,
              email: '', // 필수 필드이지만 평가에서는 사용하지 않음
              nickname: app.userName,
              profileImageUrl: app.userProfileImageUrl ?? '',
              joinedAt: Timestamp.now(),
              tier: PlayerTier.unranked,
              credits: 0,
              hostScore: 70,
              playerScore: 70,
              evaluationRate: 0,
            ))
        .toList();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParticipantEvaluationScreen(
          tournament: _tournament!,
          participants: participants,
          evaluatorId: FirebaseAuth.instance.currentUser!.uid,
        ),
      ),
    ).then((_) {
      // 평가 후 토너먼트 정보 새로고침
      _loadTournamentDetails();
    });
  }
  
  Future<void> _deleteTournament() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('내전 취소 확인'),
          content: const Text(
            '정말로 이 내전을 취소하시겠습니까? 이 작업은 되돌릴 수 없습니다.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('아니오'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('예, 취소합니다'),
            ),
          ],
        ),
      );
      
      if (confirmed == true) {
        final success = await appState.deleteTournament(widget.tournamentId);
        
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('내전이 성공적으로 취소되었습니다'),
              backgroundColor: AppColors.success,
            ),
          );
          
          // 메인 화면으로 이동
          if (mounted) {
            context.go('/tournaments');
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(appState.errorMessage ?? '내전 취소 중 오류가 발생했습니다'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('내전 취소 중 오류가 발생했습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 날짜 및 시간 카드
  Widget _buildDateTimeCard() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              icon: Icons.calendar_today,
              text: DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(_tournament!.startsAt.toDate().toLocal()),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.access_time,
              text: DateFormat('HH:mm').format(_tournament!.startsAt.toDate().toLocal()),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.people,
              text: '총 참가 인원: ${_tournament!.participants.length}/${_calculateTotalSlots()}명',
              isBold: true,
            ),
            if (_tournament!.tournamentType == TournamentType.competitive) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.monetization_on,
                text: '참가 비용: 20 크레딧',
                color: AppColors.warning,
                isBold: true,
              ),
            ],
            if (_tournament!.ovrLimit != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.fitness_center,
                text: '제한 OVR: ${_tournament!.ovrLimit}+',
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // 정보 행 (아이콘 + 텍스트)
  Widget _buildInfoRow({
    required IconData icon,
    String? text,
    String? title,
    String? value,
    Color color = AppColors.primary,
    bool isBold = false,
  }) {
    if (title != null && value != null) {
      // 새로운 스타일 (title/value 형식)
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // 기존 스타일 (text 형식)
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text ?? '',
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color == AppColors.primary ? Colors.black87 : color,
            ),
          ),
        ],
      );
    }
  }

  // 채팅방으로 이동
  Future<void> _goToChatRoom() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      if (_tournament == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('내전 정보가 없습니다'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      
      // 현재 사용자 확인
      if (appState.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인이 필요합니다'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      
      // ChatProvider를 통해 채팅방 생성 또는 조회
      final chatRoomId = await chatProvider.getOrCreateTournamentChatRoom(
        _tournament!,
        appState.currentUser!,
      );
      
      if (chatRoomId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chatProvider.error ?? '채팅방 연결 실패'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      
      // 채팅방으로 이동 - push를 사용하여 뒤로가기 버튼이 생기도록 함
      await context.push('/chat/$chatRoomId');
      // 채팅방에서 돌아온 후 데이터 새로고침
      _loadTournamentDetails();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 토너먼트 참가 시 역할 선택용 버튼 그룹 위젯
  Widget _buildRoleButtons() {
    // 역할 순서를 한국어 표준 순서로 정의 (탑, 정글, 미드, 원딜, 서폿)
    final orderedRoles = ['top', 'jungle', 'mid', 'adc', 'support'];
    
    // 필터링: 토너먼트에 존재하는 역할만 사용
    final availableRoles = orderedRoles.where((role) => 
      _tournament!.slotsByRole.containsKey(role)).toList();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: availableRoles.map((role) {
          final isSelected = _selectedRole == role;
          
          // 역할별 색상 정의
          Color getRoleColor(String role) {
            switch (role) {
              case 'top': return const Color(0xFFE74C3C);
              case 'jungle': return const Color(0xFF27AE60);
              case 'mid': return const Color(0xFF3498DB);
              case 'adc': return const Color(0xFFF39C12);
              case 'support': return const Color(0xFF9B59B6);
              default: return AppColors.primary;
            }
          }
          
          // 역할 한글 이름
          String getRoleNameKorean(String role) {
            switch (role) {
              case 'top': return '탑';
              case 'jungle': return '정글';
              case 'mid': return '미드';
              case 'adc': return '원딜';
              case 'support': return '서폿';
              default: return role.toUpperCase();
            }
          }
          
          final roleColor = getRoleColor(role);
          
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ElevatedButton(
                onPressed: () => setState(() { _selectedRole = role; }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? roleColor : Colors.white,
                  foregroundColor: isSelected ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(0, 48),
                  elevation: isSelected ? 3 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? roleColor : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                ),
                child: Text(
                  getRoleNameKorean(role),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  /// 토너먼트 참가 신청 처리
  Future<void> _registerForTournament() async {
    await _applyToTournament();
  }

  Widget _buildParticipantCountSummary() {
    if (_tournament == null) return const SizedBox.shrink();
    
    // 실제 참가자 수 계산 (토너먼트 데이터에서 가져옴)
    final totalParticipants = _tournament!.participants.length;
    final totalSlots = _tournament!.totalSlots;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '총 참가 인원: $totalParticipants/$totalSlots명',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 토너먼트 헤더 위젯
  Widget _buildTournamentHeader() {
    if (_tournament == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tournament!.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildStatusBadge(),
                        const SizedBox(width: 8),
                        Text(
                          TournamentUIUtils.getFormattedDate(_tournament!.startsAt),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_tournament!.tournamentType == TournamentType.competitive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '경쟁전',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: _tournament!.hostProfileImageUrl != null && 
                                _tournament!.hostProfileImageUrl!.isNotEmpty
                    ? NetworkImage(_tournament!.hostProfileImageUrl!)
                    : null,
                backgroundColor: _tournament!.hostProfileImageUrl == null || 
                                _tournament!.hostProfileImageUrl!.isEmpty
                    ? Colors.grey.shade300
                    : null,
                child: _tournament!.hostProfileImageUrl == null || 
                      _tournament!.hostProfileImageUrl!.isEmpty
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '주최자: ${_tournament!.hostNickname}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.verified,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '서버: ${_tournament!.location}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildParticipantCountSummary(),
          const SizedBox(height: 16),
          Text(
            _tournament!.description,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // 토너먼트 정보 표시 위젯
  Widget _buildTournamentDetails() {
    if (_tournament == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '대회 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.calendar_today,
            title: '경기 일시',
            value: TournamentUIUtils.getFullFormattedDate(_tournament!.startsAt),
          ),
          _buildInfoRow(
            icon: Icons.location_on,
            title: '경기 서버',
            value: _tournament!.location,
          ),
          _buildInfoRow(
            icon: Icons.people,
            title: '참가 현황',
            value: '${_tournament!.participants.length}/${_tournament!.totalSlots}명',
          ),
          _buildInfoRow(
            icon: Icons.format_list_numbered,
            title: '경기 방식',
            value: TournamentUIUtils.getGameFormatText(_tournament!.gameFormat),
          ),
          if (_tournament!.tournamentType == TournamentType.competitive)
            _buildInfoRow(
              icon: Icons.attach_money,
              title: '참가 비용',
              value: '${_tournament!.creditCost ?? 20} 크레딧',
            ),
          if (_tournament!.tierLimit != null)
            _buildInfoRow(
              icon: Icons.military_tech,
              title: '티어 제한',
              value: UserModel.tierToString(_tournament!.tierLimit!),
            ),
        ],
      ),
    );
  }

  // 토너먼트 상태 뱃지 위젯
  Widget _buildStatusBadge() {
    if (_tournament == null) return const SizedBox.shrink();
    return TournamentUIUtils.buildTournamentStatusChip(_tournament!.status);
  }

  bool _hasUserApplied() {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    return appState.currentUser != null && _applications.any((app) => 
        app.userUid == appState.currentUser!.uid && 
        app.status != ApplicationStatus.cancelled && 
        app.status != ApplicationStatus.rejected);
  }
} 