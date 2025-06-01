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
  final TextEditingController _messageController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadTournament();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
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
    if (_tournament == null) return;
    
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (appState.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }
    
    // Check if user already applied
    final userApplied = _applications.any((app) => 
        app.userUid == appState.currentUser!.uid && 
        app.status != ApplicationStatus.cancelled && 
        app.status != ApplicationStatus.rejected);
        
    if (userApplied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 신청한 내전입니다')),
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
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await appState.applyToTournament(
        tournamentId: widget.tournamentId,
        role: _selectedRole,
        message: _messageController.text.trim().isNotEmpty ? _messageController.text.trim() : null,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신청이 완료되었습니다')),
        );
        _messageController.clear();
        _loadTournament();
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
        _buildRolesList(),
        const SizedBox(height: 24),
        _buildPlayersList(),
        const SizedBox(height: 24),
        _buildHostInfo(),
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
          '시간 및 장소',
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
              Icons.location_on,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _tournament!.location,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        if (_tournament!.isPaid) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.monetization_on,
                size: 20,
                color: AppColors.warning,
              ),
              const SizedBox(width: 12),
              Text(
                '참가비: ${NumberFormat('#,###').format(_tournament!.price ?? 0)}원',
                style: const TextStyle(
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
              '포지션별 인원',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_tournament!.totalFilledSlots}/${_tournament!.totalSlots}명',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: roles.map((role) {
            final key = role['key'] as String;
            final filled = _tournament!.filledSlotsByRole[key] ?? 0;
            final total = _tournament!.slotsByRole[key] ?? 2;
            final isFull = filled >= total;
            
            return Column(
              children: [
                InkWell(
                  onTap: !_isUserHost() && _tournament!.status == TournamentStatus.open && !isFull
                      ? () {
                          setState(() {
                            _selectedRole = key;
                          });
                        }
                      : null,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: key == _selectedRole
                          ? (role['color'] as Color)
                          : (role['color'] as Color).withOpacity(isFull ? 0.3 : 0.7),
                      shape: BoxShape.circle,
                      border: key == _selectedRole
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: Icon(
                      role['icon'] as IconData,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${role['name']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isFull ? AppColors.textDisabled : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$filled/$total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isFull ? AppColors.textDisabled : AppColors.primary,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildPlayersList() {
    // Filter applications by role and accepted status
    final acceptedApplications = _applications
        .where((app) => app.status == ApplicationStatus.accepted)
        .toList();
    
    if (acceptedApplications.isEmpty) {
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
        ...acceptedApplications.map((app) => _buildPlayerItem(app)),
      ],
    );
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
      
      final statusText = application.status == ApplicationStatus.pending
          ? '신청 검토 중'
          : '신청 완료됨';
      
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
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success.withOpacity(0.7),
          ),
          child: Text(statusText),
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
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              hintText: '주최자에게 하고싶은 메시지 (선택사항)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            minLines: 1,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _applyToTournament,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('내전 신청하기'),
          ),
        ],
      ),
    );
  }
} 