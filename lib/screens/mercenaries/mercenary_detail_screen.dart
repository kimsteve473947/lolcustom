import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';
import 'package:lol_custom_game_manager/utils/tournament_ui_utils.dart';

class MercenaryDetailScreen extends StatefulWidget {
  final String mercenaryId;

  const MercenaryDetailScreen({
    Key? key,
    required this.mercenaryId,
  }) : super(key: key);

  @override
  State<MercenaryDetailScreen> createState() => _MercenaryDetailScreenState();
}

class _MercenaryDetailScreenState extends State<MercenaryDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = true;
  String? _errorMessage;
  MercenaryModel? _mercenary;
  UserModel? _user;
  List<RatingModel> _ratings = [];
  bool _isSendingMessage = false;
  
  // PlayerTier enum을 한글 티어 문자열로 변환하는 헬퍼 메소드
  String _tierToString(PlayerTier tier) {
    switch (tier) {
      case PlayerTier.unranked: return '언랭';
      case PlayerTier.iron: return '아이언';
      case PlayerTier.bronze: return '브론즈';
      case PlayerTier.silver: return '실버';
      case PlayerTier.gold: return '골드';
      case PlayerTier.platinum: return '플래티넘';
      case PlayerTier.emerald: return '에메랄드';
      case PlayerTier.diamond: return '다이아몬드';
      case PlayerTier.master: return '마스터';
      case PlayerTier.grandmaster: return '그랜드마스터';
      case PlayerTier.challenger: return '챌린저';
      default: return '언랭';
    }
  }
  
  @override
  void initState() {
    super.initState();
    _loadMercenary();
  }
  
  Future<void> _loadMercenary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final mercenary = await _firebaseService.getMercenary(widget.mercenaryId);
      
      if (mercenary == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '용병을 찾을 수 없습니다';
        });
        return;
      }
      
      final user = await _firebaseService.getUserById(mercenary.userUid);
      final ratings = await _firebaseService.getUserRatings(mercenary.userUid);
      
      setState(() {
        _mercenary = mercenary;
        _user = user;
        _ratings = ratings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '용병 정보를 불러오는 중 오류가 발생했습니다: $e';
      });
    }
  }
  
  Future<void> _startChat() async {
    if (_mercenary == null) return;
    
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (appState.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // This is a placeholder until we implement the actual chat creation logic
      await Future.delayed(const Duration(seconds: 1));
      
      // TODO: Create chat room and navigate to it
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('채팅방을 만들었습니다')),
      );
      
      // Navigate to chat room
      // context.push('/chat/chat_room_id');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('채팅방 생성 중 오류가 발생했습니다: $e'),
          backgroundColor: AppColors.error,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('용병 정보'),
        actions: [
          if (_mercenary != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                // TODO: Implement share functionality
              },
            ),
        ],
      ),
      body: _errorMessage != null
          ? ErrorView(
              errorMessage: _errorMessage!,
              onRetry: _loadMercenary,
            )
          : _isLoading
              ? const LoadingIndicator()
              : _mercenary == null
                  ? const Center(child: Text('용병 정보를 불러올 수 없습니다'))
                  : _buildMercenaryDetails(),
    );
  }
  
  Widget _buildMercenaryDetails() {
    if (_mercenary == null) return const SizedBox.shrink();
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildProfileHeader(),
        const SizedBox(height: 24),
        _buildPositionStats(),
        const SizedBox(height: 24),
        _buildSkillStats(),
        const SizedBox(height: 24),
        _buildRatings(),
        const SizedBox(height: 24),
      ],
    );
  }
  
  Widget _buildProfileHeader() {
    final isCurrentUser = Provider.of<AppStateProvider>(context).currentUser?.uid == _mercenary!.userUid;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: _mercenary!.profileImageUrl != null
                      ? NetworkImage(_mercenary!.profileImageUrl!)
                      : null,
                  child: _mercenary!.profileImageUrl == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _mercenary!.nickname,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _tierToString(_mercenary!.tier),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (_user?.riotId != null)
                        Text(
                          _user!.riotId!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _mercenary!.averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '가입: ${DateFormat('yyyy.MM.dd').format(_user?.joinedAt.toDate() ?? DateTime.now())}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_mercenary!.preferredPositions.isNotEmpty) ...[
                  const Text(
                    '선호 포지션: ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: _mercenary!.preferredPositions.map((position) {
                      Color positionColor;
                      String imagePath;
                      
                      switch (position.toLowerCase()) {
                        case 'top':
                          positionColor = AppColors.roleTop;
                          imagePath = LolLaneIcons.top;
                          break;
                        case 'jungle':
                          positionColor = AppColors.roleJungle;
                          imagePath = LolLaneIcons.jungle;
                          break;
                        case 'mid':
                          positionColor = AppColors.roleMid;
                          imagePath = LolLaneIcons.mid;
                          break;
                        case 'adc':
                          positionColor = AppColors.roleAdc;
                          imagePath = LolLaneIcons.adc;
                          break;
                        case 'support':
                          positionColor = AppColors.roleSupport;
                          imagePath = LolLaneIcons.support;
                          break;
                        default:
                          positionColor = AppColors.textSecondary;
                          imagePath = LolLaneIcons.top;
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: positionColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: positionColor,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                imagePath,
                                width: 14,
                                height: 14,
                                color: positionColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                TournamentUIUtils.getRoleName(position.toLowerCase()),
                                style: TextStyle(
                                  color: positionColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const Spacer(),
                          if (isCurrentUser)
            OutlinedButton.icon(
              onPressed: () {
                context.push('/mercenaries/${_mercenary!.id}/edit');
              },
              icon: const Icon(Icons.edit),
              label: const Text('프로필 수정'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            )
          else
                  OutlinedButton.icon(
                    onPressed: _startChat,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('메시지'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPositionStats() {
    // Define position data
    final positions = [
      {'name': 'TOP', 'key': 'top', 'color': AppColors.roleTop, 'imagePath': LolLaneIcons.top},
      {'name': 'JGL', 'key': 'jungle', 'color': AppColors.roleJungle, 'imagePath': LolLaneIcons.jungle},
      {'name': 'MID', 'key': 'mid', 'color': AppColors.roleMid, 'imagePath': LolLaneIcons.mid},
      {'name': 'ADC', 'key': 'adc', 'color': AppColors.roleAdc, 'imagePath': LolLaneIcons.adc},
      {'name': 'SUP', 'key': 'support', 'color': AppColors.roleSupport, 'imagePath': LolLaneIcons.support},
    ];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '포지션별 능력치',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: positions.map((position) {
                final key = position['key'] as String;
                final stat = _mercenary!.roleStats[key] ?? 0;
                
                return Column(
                  children: [
                    Text(
                      position['name'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: position['color'] as Color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: (position['color'] as Color).withOpacity(stat / 100),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: position['color'] as Color,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$stat',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: stat > 60
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSkillStats() {
    if (_mercenary!.skillStats == null || _mercenary!.skillStats!.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final skills = [
      {'name': '팀워크', 'key': 'teamwork', 'icon': Icons.people},
      {'name': '패스', 'key': 'pass', 'icon': Icons.send},
      {'name': '시야', 'key': 'vision', 'icon': Icons.visibility},
    ];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '기술 능력치',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...skills.map((skill) {
              final key = skill['key'] as String;
              final stat = _mercenary!.skillStats![key] ?? 0;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      skill['icon'] as IconData,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      skill['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: stat / 100,
                        backgroundColor: Colors.grey.shade200,
                        color: _getColorForStat(stat),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '$stat',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getColorForStat(stat),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Color _getColorForStat(int stat) {
    if (stat >= 90) return Colors.green.shade700;
    if (stat >= 80) return Colors.green;
    if (stat >= 70) return Colors.lime;
    if (stat >= 60) return Colors.amber;
    if (stat >= 50) return Colors.orange;
    return Colors.red;
  }
  
  Widget _buildRatings() {
    if (_ratings.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '평가',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_ratings.length}개',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  '아직 평가가 없습니다',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '평가',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_ratings.length}개',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._ratings.take(3).map((rating) => _buildRatingItem(rating)),
            if (_ratings.length > 3) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    // TODO: Navigate to all ratings page
                  },
                  child: Text('모든 평가 보기 (${_ratings.length}개)'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildRatingItem(RatingModel rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                rating.raterName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('yyyy.MM.dd').format(rating.createdAt.toDate()),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating.stars ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 16,
              ),
            ),
          ),
          if (rating.comment != null) ...[
            const SizedBox(height: 4),
            Text(
              rating.comment!,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ],
          if (_ratings.indexOf(rating) != _ratings.length - 1 && _ratings.indexOf(rating) != 2)
            const Divider(height: 24),
        ],
      ),
    );
  }
} 