import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/evaluation_model.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/evaluation_service.dart';

class EvaluationScreen extends StatefulWidget {
  final String tournamentId;
  final bool isHost;

  const EvaluationScreen({
    Key? key,
    required this.tournamentId,
    required this.isHost,
  }) : super(key: key);

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  final EvaluationService _evaluationService = EvaluationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  TournamentModel? _tournament;
  List<UserModel> _usersToEvaluate = [];
  Map<String, Set<String>> _selectedPositiveItems = {};
  Map<String, Set<String>> _selectedNegativeItems = {};
  Map<String, bool> _reportedUsers = {};
  Map<String, String> _reportReasons = {};
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 토너먼트 정보 로드
      final tournamentDoc = await _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .get();
      
      if (!tournamentDoc.exists) {
        Navigator.of(context).pop();
        return;
      }
      
      _tournament = TournamentModel.fromFirestore(tournamentDoc);
      
      // 평가할 사용자 목록 로드
      if (widget.isHost) {
        // 주최자는 참가자들을 평가
        for (final participantId in _tournament!.participants) {
          final userDoc = await _firestore
              .collection('users')
              .doc(participantId)
              .get();
          if (userDoc.exists) {
            _usersToEvaluate.add(UserModel.fromFirestore(userDoc));
            _selectedPositiveItems[participantId] = {};
            _selectedNegativeItems[participantId] = {};
            _reportedUsers[participantId] = false;
          }
        }
      } else {
        // 참가자는 주최자를 평가
        final hostDoc = await _firestore
            .collection('users')
            .doc(_tournament!.hostId)
            .get();
        if (hostDoc.exists) {
          _usersToEvaluate.add(UserModel.fromFirestore(hostDoc));
          _selectedPositiveItems[_tournament!.hostId] = {};
          _selectedNegativeItems[_tournament!.hostId] = {};
          _reportedUsers[_tournament!.hostId] = false;
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading evaluation data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitEvaluations() async {
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      final currentUser = Provider.of<AppStateProvider>(context, listen: false).currentUser;
      if (currentUser == null) return;
      
      // 각 사용자에 대한 평가 제출
      for (final user in _usersToEvaluate) {
        final positiveItems = _selectedPositiveItems[user.uid] ?? {};
        final negativeItems = _selectedNegativeItems[user.uid] ?? {};
        final isReported = _reportedUsers[user.uid] ?? false;
        
        // 평가 항목이 하나도 없고 신고도 하지 않았으면 건너뛰기
        if (positiveItems.isEmpty && negativeItems.isEmpty && !isReported) {
          continue;
        }
        
        await _evaluationService.createEvaluation(
          tournamentId: widget.tournamentId,
          fromUserId: currentUser.uid,
          toUserId: user.uid,
          type: widget.isHost 
              ? EvaluationType.playerEvaluation 
              : EvaluationType.hostEvaluation,
          positiveItems: positiveItems.toList(),
          negativeItems: negativeItems.toList(),
          reported: isReported,
          reportReason: _reportReasons[user.uid],
        );
      }
      
      // 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('평가가 완료되었습니다. 감사합니다!'),
          backgroundColor: AppColors.success,
        ),
      );
      
      Navigator.of(context).pop();
    } catch (e) {
      print('Error submitting evaluations: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('평가 제출 중 오류가 발생했습니다.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('평가하기'),
          backgroundColor: AppColors.primary,
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('평가하기'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          // 토너먼트 정보
          Container(
            padding: EdgeInsets.all(16),
            color: AppColors.primary.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  Icons.sports_esports,
                  color: AppColors.primary,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tournament?.title ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.isHost 
                            ? '참가자들을 평가해주세요'
                            : '주최자를 평가해주세요',
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
          
          // 평가 목록
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _usersToEvaluate.length,
              itemBuilder: (context, index) {
                final user = _usersToEvaluate[index];
                return _buildEvaluationCard(user);
              },
            ),
          ),
          
          // 제출 버튼
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitEvaluations,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          '평가 완료',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationCard(UserModel user) {
    final positiveItems = widget.isHost 
        ? EvaluationItem.playerPositiveItems 
        : EvaluationItem.hostPositiveItems;
    final negativeItems = widget.isHost 
        ? EvaluationItem.playerNegativeItems 
        : EvaluationItem.hostNegativeItems;
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사용자 정보
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: user.profileImageUrl.isNotEmpty
                      ? NetworkImage(user.profileImageUrl)
                      : null,
                  child: user.profileImageUrl.isEmpty
                      ? Text(user.nickname[0].toUpperCase())
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nickname,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (user.tier != PlayerTier.unranked)
                        Text(
                          UserModel.tierToString(user.tier),
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
            
            SizedBox(height: 20),
            
            // 좋았던 점
            Text(
              '좋았던 점',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: positiveItems.map((item) {
                final isSelected = _selectedPositiveItems[user.uid]?.contains(item) ?? false;
                return FilterChip(
                  label: Text(item),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPositiveItems[user.uid]?.add(item);
                      } else {
                        _selectedPositiveItems[user.uid]?.remove(item);
                      }
                    });
                  },
                  selectedColor: AppColors.success.withOpacity(0.2),
                  checkmarkColor: AppColors.success,
                );
              }).toList(),
            ),
            
            SizedBox(height: 20),
            
            // 아쉬웠던 점
            Text(
              '아쉬웠던 점',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: negativeItems.map((item) {
                final isSelected = _selectedNegativeItems[user.uid]?.contains(item) ?? false;
                return FilterChip(
                  label: Text(item),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedNegativeItems[user.uid]?.add(item);
                      } else {
                        _selectedNegativeItems[user.uid]?.remove(item);
                      }
                    });
                  },
                  selectedColor: AppColors.warning.withOpacity(0.2),
                  checkmarkColor: AppColors.warning,
                );
              }).toList(),
            ),
            
            SizedBox(height: 20),
            
            // 신고하기
            Divider(),
            SizedBox(height: 12),
            InkWell(
              onTap: () => _showReportDialog(user),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      color: _reportedUsers[user.uid] == true 
                          ? AppColors.error 
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _reportedUsers[user.uid] == true 
                          ? '신고됨' 
                          : '심각한 문제가 있었나요?',
                      style: TextStyle(
                        color: _reportedUsers[user.uid] == true 
                            ? AppColors.error 
                            : AppColors.textSecondary,
                        fontSize: 14,
                      ),
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

  void _showReportDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('신고하기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${user.nickname}님을 신고하시겠습니까?'),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: '신고 사유를 입력해주세요',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) {
                _reportReasons[user.uid] = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _reportedUsers[user.uid] = true;
              });
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: Text('신고'),
          ),
        ],
      ),
    );
  }
} 