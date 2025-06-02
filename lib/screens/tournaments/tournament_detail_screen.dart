import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/services/tournament_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;

  const TournamentDetailScreen({
    Key? key,
    required this.tournamentId,
  }) : super(key: key);

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = false;
  String? _errorMessage;
  TournamentModel? _tournament;
  List<ApplicationModel> _applications = [];
  String _selectedRole = 'top';
  
  @override
  void initState() {
    super.initState();
    _loadTournament();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  Future<void> _loadTournament() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final tournament = await _firebaseService.getTournament(widget.tournamentId);
      
      if (tournament == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '내전을 찾을 수 없습니다';
        });
        return;
      }
      
      final applications = await _firebaseService.getTournamentApplications(widget.tournamentId);
      
      setState(() {
        _tournament = tournament;
        _applications = applications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '내전 정보를 불러오는 중 오류가 발생했습니다: $e';
      });
    }
  }
  
  Future<void> _applyToTournament() async {
    if (_tournament == null || _selectedRole.isEmpty) {
      return;
    }
    
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (appState.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }
    
    // Check if tournament is full for the selected role
    final slotsForRole = _tournament!.slotsByRole[_selectedRole] ?? 0;
    final filledSlotsForRole = _tournament!.filledSlotsByRole[_selectedRole] ?? 0;
    
    if (filledSlotsForRole >= slotsForRole) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택한 역할은 이미 가득 찼습니다')),
      );
      return;
    }
    
    // Check credits for competitive tournaments
    if (_tournament!.tournamentType == TournamentType.competitive) {
      const requiredCredits = 20;
      
      if (appState.currentUser!.credits < requiredCredits) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('크레딧이 부족합니다. 필요: $requiredCredits, 보유: ${appState.currentUser!.credits}'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: '충전하기',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to credit purchase screen
                context.push('/credits/purchase');
              },
            ),
          ),
        );
        return;
      }
      
      // Ask for confirmation before spending credits
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('크레딧 사용 확인'),
          content: Text('이 경쟁전에 참가하기 위해 $requiredCredits 크레딧이 소모됩니다. 계속하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('확인'),
            ),
          ],
        ),
      ) ?? false;
      
      if (!confirmed) return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await appState.joinTournamentByRole(
        tournamentId: widget.tournamentId,
        role: _selectedRole,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신청이 완료되었습니다')),
        );
        _loadTournament();
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
            content: Text('신청 중 오류가 발생했습니다'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('신청 중 오류가 발생했습니다: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _startChat() async {
    if (_tournament == null) return;
    
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
        title: const Text('내전 상세'),
        actions: [
          if (_tournament != null)
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
              message: _errorMessage!,
              onRetry: _loadTournament,
            )
          : _isLoading && _tournament == null
              ? const LoadingIndicator()
              : _tournament == null
                  ? const Center(child: Text('내전 정보를 불러올 수 없습니다'))
                  : _buildTournamentDetails(),
      bottomNavigationBar: _tournament != null && !_isUserHost() && _tournament!.status == TournamentStatus.open
          ? _buildApplyButton()
          : null,
    );
  }
  
  bool _isUserHost() {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    return appState.currentUser != null && 
           _tournament != null && 
           appState.currentUser!.uid == _tournament!.hostUid;
  }
  
  Widget _buildTournamentDetails() {
    if (_tournament == null) return const SizedBox.shrink();
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildTimeAndLocation(),
        const SizedBox(height: 24),
        _buildDescription(),
        const SizedBox(height: 24),
        if (_tournament!.tournamentType == TournamentType.competitive)
          Column(
            children: [
              _buildRefereeInfo(),
              if (_isUserHost() && _tournament!.status != TournamentStatus.completed)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: _buildRefereeManagementButtons(),
                ),
              const SizedBox(height: 24),
            ],
          ),
        _buildRolesList(),
        const SizedBox(height: 24),
        _buildPlayersList(),
        const SizedBox(height: 24),
        _buildHostInfo(),
        if (_tournament?.status == TournamentStatus.open && !_isUserHost())
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: _buildParticipationButtons(),
          ),
        const SizedBox(height: 50), // Extra space for bottom button
      ],
    );
  }
  
  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('M월 d일 (E) HH:mm', 'ko_KR').format(_tournament!.startsAt.toDate()),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _tournament!.location,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _getStatusText(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _getStatusColor(),
            ),
          ),
        ),
      ],
    );
  }
  
  String _getStatusText() {
    switch (_tournament!.status) {
      case TournamentStatus.draft:
        return '초안';
      case TournamentStatus.open:
        return '모집 중';
      case TournamentStatus.full:
        return '모집 완료';
      case TournamentStatus.inProgress:
      case TournamentStatus.ongoing:
        return '진행 중';
      case TournamentStatus.completed:
        return '완료됨';
      case TournamentStatus.cancelled:
        return '취소됨';
    }
  }
  
  Color _getStatusColor() {
    switch (_tournament!.status) {
      case TournamentStatus.draft:
        return Colors.grey;
      case TournamentStatus.open:
        return AppColors.success;
      case TournamentStatus.full:
        return AppColors.primary;
      case TournamentStatus.inProgress:
      case TournamentStatus.ongoing:
        return AppColors.warning;
      case TournamentStatus.completed:
        return AppColors.textSecondary;
      case TournamentStatus.cancelled:
        return AppColors.error;
    }
  }
  
  Widget _buildTimeAndLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '시간 및 인원',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Text(
              DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(_tournament!.startsAt.toDate()),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(
              Icons.access_time,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Text(
              DateFormat('HH:mm').format(_tournament!.startsAt.toDate()),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(
              Icons.people,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Text(
              '총 참가 인원: ${_tournament!.participants.length}/${_calculateTotalSlots()}명',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (_tournament!.tournamentType == TournamentType.competitive) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.monetization_on,
                size: 20,
                color: AppColors.warning,
              ),
              const SizedBox(width: 12),
              const Text(
                '참가 비용: 20 크레딧',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
        if (_tournament!.ovrLimit != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.fitness_center,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Text(
                '제한 OVR: ${_tournament!.ovrLimit}+',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ],
      ],
    );
  }
  
  // 총 슬롯 수 계산 헬퍼 메서드
  int _calculateTotalSlots() {
    return _tournament!.slotsByRole.values.fold(0, (sum, count) => sum + count);
  }
  
  Widget _buildDescription() {
    if (_tournament!.description == null || _tournament!.description!.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '내전 소개',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _tournament!.description!,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }
  
  Widget _buildRefereeInfo() {
    if (_tournament == null || !_tournament!.isRefereed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '심판 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '아직 배정된 심판이 없습니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '심판 정보',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (_tournament!.referees != null && _tournament!.referees!.isNotEmpty)
          FutureBuilder<List<UserModel>>(
            future: _fetchReferees(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Text('심판 정보를 불러오는 중 오류가 발생했습니다: ${snapshot.error}');
              }
              
              final referees = snapshot.data ?? [];
              if (referees.isEmpty) {
                return const Text('심판 정보가 없습니다.');
              }
              
              return Column(
                children: referees.map((referee) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: referee.profileImageUrl != null
                          ? NetworkImage(referee.profileImageUrl!)
                          : null,
                      child: referee.profileImageUrl == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(referee.nickname ?? '익명'),
                    subtitle: Text('심판'),
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              );
            },
          ),
      ],
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
    // Define role data
    final roles = [
      {'name': 'Top', 'icon': Icons.arrow_upward, 'color': AppColors.roleTop, 'key': 'top'},
      {'name': 'Jungle', 'icon': Icons.nature_people, 'color': AppColors.roleJungle, 'key': 'jungle'},
      {'name': 'Mid', 'icon': Icons.adjust, 'color': AppColors.roleMid, 'key': 'mid'},
      {'name': 'ADC', 'icon': Icons.gps_fixed, 'color': AppColors.roleAdc, 'key': 'adc'},
      {'name': 'Support', 'icon': Icons.shield, 'color': AppColors.roleSupport, 'key': 'support'},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '포지션별 참가 현황',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_tournament!.participants.length}/${_calculateTotalSlots()}명',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // 역할별 상태 표시 막대그래프
        ...roles.map((role) {
          final key = role['key'] as String;
          final filled = _tournament!.filledSlotsByRole[key] ?? 0;
          final total = _tournament!.slotsByRole[key] ?? 2;
          final progress = total > 0 ? filled / total : 0.0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      role['icon'] as IconData,
                      color: role['color'] as Color,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${role['name']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$filled/$total',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: filled == total ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    color: role['color'] as Color,
                    minHeight: 8,
                  ),
                ),
                if (_tournament!.participantsByRole[key]?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
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
                      
                      return Chip(
                        label: Text(app.userName),
                        backgroundColor: (role['color'] as Color).withOpacity(0.1),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: role['color'] as Color,
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        
        // 역할 선택 안내 (신청 화면일 때만)
        if (!_isUserHost() && _tournament!.status == TournamentStatus.open)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '참가하려면 원하는 포지션을 선택하세요',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 8),
        
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
                
                return InkWell(
                  onTap: isFull ? null : () {
                    setState(() {
                      _selectedRole = key;
                    });
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Opacity(
                    opacity: isFull ? 0.5 : 1.0,
                    child: Column(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? role['color'] as Color
                                : (role['color'] as Color).withOpacity(0.7),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                            boxShadow: isSelected
                                ? [BoxShadow(
                                    color: (role['color'] as Color).withOpacity(0.5),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )]
                                : null,
                          ),
                          child: Icon(
                            role['icon'] as IconData,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${role['name']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isFull ? Colors.grey : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
  
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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '참가자 목록',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...applicationsByRole.entries.map((entry) {
          final roleName = _getRoleName(entry.key);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                roleName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getRoleColor(entry.key),
                ),
              ),
              const SizedBox(height: 8),
              ...entry.value.map((app) => _buildPlayerItem(app)),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ],
    );
  }
  
  String _getRoleName(String role) {
    switch (role) {
      case 'top': return '탑';
      case 'jungle': return '정글';
      case 'mid': return '미드';
      case 'adc': return '원딜';
      case 'support': return '서포터';
      default: return role;
    }
  }
  
  Color _getRoleColor(String role) {
    switch (role) {
      case 'top': return AppColors.roleTop;
      case 'jungle': return AppColors.roleJungle;
      case 'mid': return AppColors.roleMid;
      case 'adc': return AppColors.roleAdc;
      case 'support': return AppColors.roleSupport;
      default: return AppColors.primary;
    }
  }
  
  Widget _buildPlayerItem(ApplicationModel application) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundImage: application.userProfileImageUrl != null
            ? NetworkImage(application.userProfileImageUrl!)
            : null,
        child: application.userProfileImageUrl == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(
        application.userName,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        '역할: ${application.role.toUpperCase()}',
        style: const TextStyle(
          color: AppColors.textSecondary,
        ),
      ),
      trailing: application.userOvr != null
          ? Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${application.userOvr}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          : null,
    );
  }
  
  Widget _buildHostInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '주최자 정보',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: _tournament!.hostProfileImageUrl != null
                  ? NetworkImage(_tournament!.hostProfileImageUrl!)
                  : null,
              child: _tournament!.hostProfileImageUrl == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tournament!.hostNickname ?? _tournament!.hostName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '주최: ${DateFormat('yyyy.MM.dd').format(_tournament!.createdAt)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isUserHost())
              OutlinedButton.icon(
                onPressed: _tournament!.status != TournamentStatus.cancelled
                    ? _startChat
                    : null,
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
    );
  }
  
  Widget _buildApplyButton() {
    final appState = Provider.of<AppStateProvider>(context);
    final hasApplied = appState.currentUser != null && _applications.any((app) => 
        app.userUid == appState.currentUser!.uid && 
        app.status != ApplicationStatus.cancelled && 
        app.status != ApplicationStatus.rejected);
    
    if (hasApplied) {
      final application = _applications.firstWhere((app) => 
        app.userUid == appState.currentUser!.uid && 
        app.status != ApplicationStatus.cancelled && 
        app.status != ApplicationStatus.rejected);
      
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getRoleIcon(application.role),
                  color: _getRoleColor(application.role),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_getRoleName(application.role)} 역할로 참가 중',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(application.role),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : () => _cancelRegistration(application.role),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('참가 취소하기'),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getRoleIcon(_selectedRole),
                color: _getRoleColor(_selectedRole),
                size: 20,
              ),
              const SizedBox(width: 8),
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
          if (_tournament!.tournamentType == TournamentType.competitive && appState.currentUser != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.monetization_on,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  '필요 크레딧: ${_tournament!.creditCost ?? 20} / 보유 크레딧: ${appState.currentUser!.credits}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _applyToTournament,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: AppColors.primary,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text('${_getRoleName(_selectedRole)} 역할로 신청하기', style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _cancelRegistration(String role) async {
    if (_tournament == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('참가 취소 확인'),
        content: const Text('정말로 참가를 취소하시겠습니까? 경쟁전인 경우 크레딧은 환불되지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('예, 취소합니다'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed) return;
    
    setState(() {
      _isLoading = true;
    });
    
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    
    try {
      final success = await appState.leaveTournamentByRole(
        tournamentId: widget.tournamentId,
        role: role,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('참가가 취소되었습니다')),
        );
        _loadTournament();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('참가 취소 중 오류가 발생했습니다'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('참가 취소 중 오류가 발생했습니다: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
      _loadTournament();
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
      _loadTournament();
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
  
  // 참가 버튼 위젯
  Widget _buildParticipationButtons() {
    if (_tournament == null) return const SizedBox.shrink();
    
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final bool isParticipant = _tournament!.participants.contains(appState.currentUser?.uid);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (!isParticipant)
          Expanded(
            child: ElevatedButton(
              onPressed: _showRoleSelectionDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('참가 신청', style: TextStyle(fontSize: 16)),
            ),
          ),
        if (isParticipant)
          Expanded(
            child: ElevatedButton(
              onPressed: _showLeaveConfirmationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('참가 취소', style: TextStyle(fontSize: 16)),
            ),
          ),
        if (!isParticipant) 
          const SizedBox(width: 12),
        if (!isParticipant)
          Expanded(
            child: OutlinedButton(
              onPressed: _startChat,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('채팅하기', style: TextStyle(fontSize: 16)),
            ),
          ),
      ],
    );
  }
  
  // 참가 취소 확인 다이얼로그
  void _showLeaveConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('참가 취소'),
        content: const Text('정말로 이 내전 참가를 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveTournament();
            },
            child: const Text('예'),
          ),
        ],
      ),
    );
  }
  
  // 참가 취소 처리
  Future<void> _leaveTournament() async {
    if (_tournament == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      
      // 현재 사용자가 어떤 역할로 참가했는지 찾기
      String? userRole;
      for (final entry in _tournament!.participantsByRole.entries) {
        if (entry.value.contains(appState.currentUser?.uid)) {
          userRole = entry.key;
          break;
        }
      }
      
      if (userRole == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('참가 역할을 찾을 수 없습니다.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      
      final success = await appState.leaveTournamentByRole(
        tournamentId: widget.tournamentId,
        role: userRole,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('참가가 취소되었습니다')),
        );
        _loadTournament();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.errorMessage ?? '참가 취소 중 오류가 발생했습니다'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('참가 취소 중 오류가 발생했습니다: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 역할 선택 다이얼로그 표시
  void _showRoleSelectionDialog() {
    if (_tournament == null) return;
    
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (appState.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }
    
    final roles = [
      {'name': 'Top', 'icon': Icons.arrow_upward, 'color': AppColors.roleTop, 'key': 'top'},
      {'name': 'Jungle', 'icon': Icons.nature_people, 'color': AppColors.roleJungle, 'key': 'jungle'},
      {'name': 'Mid', 'icon': Icons.adjust, 'color': AppColors.roleMid, 'key': 'mid'},
      {'name': 'ADC', 'icon': Icons.gps_fixed, 'color': AppColors.roleAdc, 'key': 'adc'},
      {'name': 'Support', 'icon': Icons.shield, 'color': AppColors.roleSupport, 'key': 'support'},
    ];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '포지션 선택',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                '참가하고 싶은 포지션을 선택하세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // 포지션 선택 버튼들
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 16,
                runSpacing: 16,
                children: roles.map((role) {
                  final key = role['key'] as String;
                  final filled = _tournament!.filledSlotsByRole[key] ?? 0;
                  final total = _tournament!.slotsByRole[key] ?? 2;
                  final isFull = filled >= total;
                  
                  return InkWell(
                    onTap: isFull ? null : () {
                      setState(() {
                        _selectedRole = key;
                      });
                      Navigator.pop(context);
                      // Apply immediately after selecting role
                      _applyToTournament();
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: isFull
                                ? (role['color'] as Color).withOpacity(0.3)
                                : role['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            role['icon'] as IconData,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${role['name']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isFull ? Colors.grey : Colors.black,
                          ),
                        ),
                        Text(
                          '$filled/$total',
                          style: TextStyle(
                            fontSize: 12,
                            color: isFull ? Colors.grey : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 24),
              
              if (_tournament!.tournamentType == TournamentType.competitive)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '경쟁전 참가시 20 크레딧이 차감됩니다',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Add helper method for role icons
  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'top': return Icons.arrow_upward;
      case 'jungle': return Icons.nature_people;
      case 'mid': return Icons.adjust;
      case 'adc': return Icons.gps_fixed;
      case 'support': return Icons.shield;
      default: return Icons.sports_esports;
    }
  }
} 