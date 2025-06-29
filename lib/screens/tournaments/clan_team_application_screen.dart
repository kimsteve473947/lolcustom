import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/clan_team_application_model.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';

class ClanTeamApplicationScreen extends StatefulWidget {
  final TournamentModel tournament;

  const ClanTeamApplicationScreen({
    super.key,
    required this.tournament,
  });

  @override
  State<ClanTeamApplicationScreen> createState() => _ClanTeamApplicationScreenState();
}

class _ClanTeamApplicationScreenState extends State<ClanTeamApplicationScreen> {
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final Map<String, ClanTeamMember?> _selectedMembers = {
    'top': null,
    'jungle': null,
    'mid': null,
    'adc': null,
    'support': null,
  };

  ClanModel? _myClan;
  List<UserModel> _clanMembers = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadClanData();
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadClanData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      _myClan = appState.myClan;

      if (_myClan != null) {
        final clanService = ClanService();
        final memberData = await clanService.getClanMembers(_myClan!.id);
        
        // Map 데이터를 UserModel로 변환
        _clanMembers = memberData.map((data) => UserModel(
          uid: data['uid'] ?? '',
          email: '',
          nickname: data['displayName'] ?? '이름 없음',
          profileImageUrl: data['photoURL'] ?? '',
          joinedAt: Timestamp.now(),
          tier: PlayerTier.unranked,
          preferredPositions: [],
          credits: 0,
          isPremium: false,
        )).toList();
        
        // 팀 이름을 클랜명으로 초기 설정
        _teamNameController.text = _myClan!.name;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('클랜 정보를 불러오는 중 오류가 발생했습니다: $e'),
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

  Future<void> _submitApplication() async {
    if (!_validateForm()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final currentUser = appState.currentUser;

      if (currentUser == null || _myClan == null) {
        throw Exception('사용자 또는 클랜 정보가 없습니다');
      }

      // 팀 멤버 리스트 생성
      final teamMembers = _selectedMembers.entries
          .where((entry) => entry.value != null)
          .map((entry) => entry.value!)
          .toList();

      // 클랜전 팀 신청 생성
      final application = ClanTeamApplicationModel(
        id: '',
        tournamentId: widget.tournament.id,
        clanId: _myClan!.id,
        clanName: _myClan!.name,
        teamCaptainId: currentUser.uid,
        teamCaptainName: currentUser.nickname,
        teamCaptainProfileImageUrl: currentUser.profileImageUrl,
        teamName: _teamNameController.text.trim(),
        teamMembers: teamMembers,
        message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
        status: ClanTeamApplicationStatus.pending,
        appliedAt: Timestamp.now(),
      );

      // Firestore에 신청 저장
      await FirebaseFirestore.instance
          .collection('clanTeamApplications')
          .add(application.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('클랜전 신청이 완료되었습니다!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('신청 중 오류가 발생했습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  bool _validateForm() {
    if (_teamNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('팀 이름을 입력해주세요'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }

    // 모든 포지션이 선택되었는지 확인
    final requiredRoles = ['top', 'jungle', 'mid', 'adc', 'support'];
    for (final role in requiredRoles) {
      if (_selectedMembers[role] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_getRoleDisplayName(role)} 포지션을 선택해주세요'),
            backgroundColor: AppColors.error,
          ),
        );
        return false;
      }
    }

    // 중복 선택 확인
    final selectedUserIds = _selectedMembers.values
        .where((member) => member != null)
        .map((member) => member!.userId)
        .toList();

    if (selectedUserIds.length != selectedUserIds.toSet().length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('같은 클랜원을 중복으로 선택할 수 없습니다'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }

    return true;
  }

  String _getRoleDisplayName(String role) {
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
      case 'top': return const Color(0xFFE74C3C);
      case 'jungle': return const Color(0xFF27AE60);
      case 'mid': return const Color(0xFF3498DB);
      case 'adc': return const Color(0xFFF39C12);
      case 'support': return const Color(0xFF9B59B6);
      default: return AppColors.primary;
    }
  }

  Widget _buildMemberSelector(String role) {
    final selectedMember = _selectedMembers[role];
    final roleColor = _getRoleColor(role);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selectedMember != null ? roleColor : Colors.grey.shade300,
          width: selectedMember != null ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showMemberSelectionDialog(role),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getRoleIcon(role),
                  color: roleColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getRoleDisplayName(role),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: roleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (selectedMember != null) ...[
                      Text(
                        selectedMember.nickname,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        selectedMember.tier ?? '언랭크',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ] else
                      Text(
                        '클랜원 선택',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                selectedMember != null ? Icons.check_circle : Icons.add_circle_outline,
                color: selectedMember != null ? roleColor : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'top': return Icons.shield;
      case 'jungle': return Icons.forest;
      case 'mid': return Icons.flash_on;
      case 'adc': return Icons.gps_fixed;
      case 'support': return Icons.favorite;
      default: return Icons.person;
    }
  }

  Future<void> _showMemberSelectionDialog(String role) async {
    final availableMembers = _clanMembers.where((member) {
      // 이미 다른 포지션에 선택된 멤버는 제외
      final selectedUserIds = _selectedMembers.values
          .where((m) => m != null && m.role != role)
          .map((m) => m!.userId)
          .toSet();
      return !selectedUserIds.contains(member.uid);
    }).toList();

    if (availableMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('선택 가능한 클랜원이 없습니다'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final selectedMember = await showDialog<UserModel>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_getRoleDisplayName(role)} 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableMembers.length,
            itemBuilder: (context, index) {
              final member = availableMembers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: member.profileImageUrl != null
                      ? NetworkImage(member.profileImageUrl!)
                      : null,
                  child: member.profileImageUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(member.nickname),
                subtitle: Text(UserModel.tierToString(member.tier)),
                onTap: () => Navigator.of(context).pop(member),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          if (_selectedMembers[role] != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('선택 해제'),
            ),
        ],
      ),
    );

    if (selectedMember == null && _selectedMembers[role] != null) {
      // 선택 해제
      setState(() {
        _selectedMembers[role] = null;
      });
    } else if (selectedMember != null) {
      setState(() {
        _selectedMembers[role] = ClanTeamMember(
          userId: selectedMember.uid,
          nickname: selectedMember.nickname,
          profileImageUrl: selectedMember.profileImageUrl,
          role: role,
          riotId: selectedMember.riotId,
          tier: UserModel.tierToString(selectedMember.tier),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('클랜전 신청'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_myClan == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('클랜전 신청'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.group_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '클랜에 가입되어 있지 않습니다',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Text(
                '클랜전에 참가하려면 먼저 클랜에 가입해주세요',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('클랜전 신청'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 토너먼트 정보
            Card(
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
                    Text(
                      widget.tournament.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '주최자: ${widget.tournament.hostNickname}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 클랜 정보
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.groups,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _myClan!.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '멤버 ${_clanMembers.length}명',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 팀 이름 입력
            const Text(
              '팀 이름',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _teamNameController,
              decoration: InputDecoration(
                hintText: '팀 이름을 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 팀원 선택
            const Text(
              '팀원 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '각 포지션에 클랜원을 배정해주세요',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            // 포지션별 멤버 선택
            ...['top', 'jungle', 'mid', 'adc', 'support'].map((role) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMemberSelector(role),
              );
            }).toList(),

            const SizedBox(height: 24),

            // 신청 메시지
            const Text(
              '신청 메시지 (선택사항)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '주최자에게 전달할 메시지를 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitApplication,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '클랜전 신청하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
} 