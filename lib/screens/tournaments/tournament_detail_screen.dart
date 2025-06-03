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
import 'package:lol_custom_game_manager/utils/image_utils.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/screens/main_screen.dart';

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;
  
  const TournamentDetailScreen({
    Key? key,
    required this.tournamentId,
  }) : super(key: key);

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = false;
  String? _errorMessage;
  TournamentModel? _tournament;
  List<ApplicationModel> _applications = [];
  String _selectedRole = 'top';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Set up animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    _loadTournament();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
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
      
      _animationController.forward();
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
      // 메시지 파라미터는 선택 사항
      final success = await appState.joinTournamentByRole(
        tournamentId: widget.tournamentId,
        role: _selectedRole,
      );
      
      if (success) {
        // 신청 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신청이 완료되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 토너먼트 정보 다시 로드
        await _loadTournament();
      } else if (appState.errorMessage != null) {
        // 에러 메시지가 있다면 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        // 기본 에러 메시지
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신청 중 오류가 발생했습니다'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      // 예외 발생 시 에러 메시지
      debugPrint('Error applying to tournament: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('신청 중 오류가 발생했습니다: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      // 로딩 상태 종료
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      // 내전 주최자의 정보 가져오기
      final hostUser = await _firebaseService.getUserById(_tournament!.hostId);
      
      if (hostUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('주최자 정보를 불러올 수 없습니다'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      
      // 채팅방이 이미 존재하는지 확인
      final existingChatRoomId = await _firebaseService.findChatRoomByTournamentId(_tournament!.id);
      
      if (existingChatRoomId != null) {
        // 이미 채팅방이 있으면 해당 채팅방으로 이동
        context.push('/chat/$existingChatRoomId');
        return;
      }
      
      // 새 채팅방 생성
      final chatRoomId = await appState.createChatRoom(
        targetUserId: _tournament!.hostId,
        title: _tournament!.title,
        type: ChatRoomType.tournamentRecruitment,
        initialMessage: '${appState.currentUser!.nickname}님이 내전 채팅방에 참가했습니다.',
      );
      
      if (chatRoomId != null) {
        // 채팅방과 내전 연결
        await _firebaseService.linkChatRoomToTournament(chatRoomId, _tournament!.id);
        
        // 채팅방으로 이동
        if (mounted) {
          context.push('/chat/$chatRoomId');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('채팅방 생성에 실패했습니다'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error starting chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('채팅방 생성 중 오류가 발생했습니다: $e'),
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
        ],
      ),
      body: SafeArea(
        child: _errorMessage != null
          ? ErrorView(
              message: _errorMessage!,
              onRetry: _loadTournament,
            )
          : _isLoading && _tournament == null
              ? const LoadingIndicator()
              : _tournament == null
                  ? const Center(child: Text('내전 정보를 불러올 수 없습니다'))
                  : _buildTournamentDetails(),
      ),
      bottomNavigationBar: _tournament != null && !_isUserHost() && _tournament!.status == TournamentStatus.open
          ? Container(
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
                      color: _getRoleColor(_selectedRole).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getRoleColor(_selectedRole).withOpacity(0.3),
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
                        Icon(
                          _getRoleIcon(_selectedRole),
                          color: _getRoleColor(_selectedRole),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          hasApplied 
                              ? '${_getRoleName(_selectedRole)} 역할로 참가 중'
                              : '선택한 포지션: ${_getRoleName(_selectedRole)}',
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
                  ElevatedButton(
                    onPressed: _isLoading 
                        ? null 
                        : hasApplied
                            ? () {
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
                                _cancelRegistration(application.role);
                              }
                            : _applyToTournament,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasApplied ? AppColors.error : _getRoleColor(_selectedRole),
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
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                hasApplied ? Icons.cancel_outlined : _getRoleIcon(_selectedRole),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hasApplied
                                    ? '참가 취소하기'
                                    : '${_getRoleName(_selectedRole)} 역할로 신청하기', 
                                style: const TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            )
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
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Colors.white,
                    _getStatusColor().withOpacity(0.3),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _tournament!.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getStatusColor().withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: _tournament!.hostProfileImageUrl != null
                            ? NetworkImage(_tournament!.hostProfileImageUrl!)
                            : null,
                        child: _tournament!.hostProfileImageUrl == null
                            ? const Icon(Icons.person, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _tournament!.hostNickname ?? _tournament!.hostName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                  Card(
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.calendar_today,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(_tournament!.startsAt.toDate()),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.access_time,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('HH:mm').format(_tournament!.startsAt.toDate()),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.people,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
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
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.monetization_on,
                                    size: 20,
                                    color: AppColors.warning,
                                  ),
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
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.fitness_center,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
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
                      ),
                    ),
                  ),
                  
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
                  
                  // Roles list
                  _buildRolesList(),
                  const SizedBox(height: 24),
                  
                  // Players list
                  _buildPlayersList(),
                  const SizedBox(height: 24),
                  
                  // Host info
                  _buildHostInfo(),
                  
                  const SizedBox(height: 50), // Extra space for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
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
    // Define role data
    final roles = [
      {'name': 'Top', 'icon': Icons.arrow_upward, 'color': AppColors.roleTop, 'key': 'top'},
      {'name': 'Jungle', 'icon': Icons.nature_people, 'color': AppColors.roleJungle, 'key': 'jungle'},
      {'name': 'Mid', 'icon': Icons.adjust, 'color': AppColors.roleMid, 'key': 'mid'},
      {'name': 'ADC', 'icon': Icons.gps_fixed, 'color': AppColors.roleAdc, 'key': 'adc'},
      {'name': 'Support', 'icon': Icons.shield, 'color': AppColors.roleSupport, 'key': 'support'},
    ];
    
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('포지션별 참가 현황'),
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
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
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: (role['color'] as Color).withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (role['color'] as Color).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            role['icon'] as IconData,
                            color: role['color'] as Color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${role['name']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: filled == total 
                                ? AppColors.success.withOpacity(0.1)
                                : (role['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: filled == total 
                                  ? AppColors.success.withOpacity(0.3)
                                  : (role['color'] as Color).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '$filled/$total',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: filled == total ? AppColors.success : (role['color'] as Color),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.shade200,
                        color: role['color'] as Color,
                        minHeight: 10,
                      ),
                    ),
                    if (_tournament!.participantsByRole[key]?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
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
                          
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: (role['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (role['color'] as Color).withOpacity(0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade100,
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (app.userProfileImageUrl != null) ...[
                                  ImageUtils.safeCircleAvatar(
                                    imageUrl: app.userProfileImageUrl,
                                    radius: 12,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  app.userName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: role['color'] as Color,
                                  ),
                                ),
                              ],
                            ),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
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
                      child: const Icon(Icons.info_outline, color: AppColors.primary),
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
            
            const SizedBox(height: 20),
            
            // 포지션 선택 버튼 (신청 화면일 때만)
            if (!_isUserHost() && _tournament!.status == TournamentStatus.open)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: roles.map((role) {
                    final key = role['key'] as String;
                    final filled = _tournament!.filledSlotsByRole[key] ?? 0;
                    final total = _tournament!.slotsByRole[key] ?? 2;
                    final isFull = filled >= total;
                    final isSelected = _selectedRole == key;
                    
                    return GestureDetector(
                      onTap: isFull ? null : () {
                        setState(() {
                          _selectedRole = key;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Opacity(
                          opacity: isFull ? 0.5 : 1.0,
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? role['color'] as Color
                                      : (role['color'] as Color).withOpacity(0.7),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.white : (role['color'] as Color).withOpacity(0.3),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [BoxShadow(
                                          color: (role['color'] as Color).withOpacity(0.5),
                                          spreadRadius: 1,
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        )]
                                      : null,
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
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isFull ? Colors.grey : Colors.black,
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: role['color'] as Color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
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
              final roleColor = _getRoleColor(entry.key);
              final roleIcon = _getRoleIcon(entry.key);
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(roleIcon, color: roleColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          roleName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: roleColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            '${entry.value.length}명',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: roleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...entry.value.asMap().entries.map((playerEntry) {
                    final index = playerEntry.key;
                    final app = playerEntry.value;
                    
                    // Calculate a small delay for each item to create a staggered animation effect
                    final delay = Duration(milliseconds: 50 * index);
                    
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutQuad,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
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
                              radius: 24,
                              backgroundColor: roleColor.withOpacity(0.1),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        roleIcon,
                                        size: 14,
                                        color: roleColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        roleName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: roleColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (app.userOvr != null)
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      roleColor.withOpacity(0.8),
                                      roleColor,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: roleColor.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '${app.userOvr}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                ],
              );
            }).toList(),
          ],
        ),
      ),
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
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Fetch host user data
      final hostUser = await _firebaseService.getUserById(_tournament!.hostId);
      if (hostUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주최자 정보를 불러올 수 없습니다')),
        );
        return;
      }
      
      // Fetch host's ratings
      final hostRatings = await _firebaseService.getUserRatings(_tournament!.hostId);
      
      // Calculate average rating
      double averageRating = 0.0;
      if (hostRatings.isNotEmpty) {
        final totalStars = hostRatings.fold<int>(0, (sum, rating) => sum + rating.stars);
        averageRating = totalStars / hostRatings.length;
      }
      
      // Fetch tournaments hosted by this user
      final hostedTournaments = await _fetchHostedTournaments(_tournament!.hostId);
      
      if (!mounted) return;
      
      // Show bottom sheet with host profile info
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
              // Header with profile info
              Row(
                children: [
                  ImageUtils.safeCircleAvatar(
                    imageUrl: hostUser.profileImageUrl,
                    radius: 32,
                    defaultIconSize: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hostUser.nickname ?? '익명',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (hostUser.tier != null)
                          Text(
                            '티어: ${_getTierName(hostUser.tier!)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '${averageRating.toStringAsFixed(1)} (${hostRatings.length}개의 평가)',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              // Stats section
              const Text(
                '주최자 통계',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.emoji_events,
                    value: '${hostedTournaments.length}',
                    label: '주최한 내전',
                  ),
                  _buildStatItem(
                    icon: Icons.star,
                    value: averageRating.toStringAsFixed(1),
                    label: '평균 평점',
                  ),
                  _buildStatItem(
                    icon: Icons.people,
                    value: '${hostRatings.length}',
                    label: '받은 평가',
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              // Recent tournaments section
              const Text(
                '최근 주최한 내전',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              Expanded(
                child: hostedTournaments.isEmpty
                    ? const Center(child: Text('주최한 내전이 없습니다'))
                    : ListView.builder(
                        itemCount: hostedTournaments.length,
                        itemBuilder: (context, index) {
                          final tournament = hostedTournaments[index];
                          return ListTile(
                            title: Text(tournament.title),
                            subtitle: Text(
                              '${DateFormat('yyyy.MM.dd').format(tournament.startsAt.toDate())} | ${tournament.participants.length}명 참가',
                            ),
                            trailing: _buildTournamentStatusChip(tournament.status),
                            onTap: () {
                              // Close bottom sheet and navigate to tournament if it's not the current one
                              Navigator.pop(context);
                              if (tournament.id != _tournament!.id) {
                                context.push('/tournaments/${tournament.id}');
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('주최자 정보를 불러오는 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
    final hasApplied = appState.currentUser != null && _applications.any((app) => 
        app.userUid == appState.currentUser!.uid && 
        app.status != ApplicationStatus.cancelled && 
        app.status != ApplicationStatus.rejected);
    
    if (hasApplied) {
      final application = _applications.firstWhere((app) => 
        app.userUid == appState.currentUser!.uid && 
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
                color: _getRoleColor(application.role).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getRoleColor(application.role).withOpacity(0.3),
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
                  Icon(
                    _getRoleIcon(application.role),
                    color: _getRoleColor(application.role),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
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
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : () => _cancelRegistration(application.role),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
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
                        Icon(Icons.cancel_outlined),
                        SizedBox(width: 8),
                        Text(
                          '참가 취소하기',
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
              color: _getRoleColor(_selectedRole).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getRoleColor(_selectedRole).withOpacity(0.3),
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
                Icon(
                  _getRoleIcon(_selectedRole),
                  color: _getRoleColor(_selectedRole),
                  size: 24,
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
          if (_tournament!.tournamentType == TournamentType.competitive && appState.currentUser != null) ...[
          const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.warning.withOpacity(0.3),
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
                  const Icon(
                    Icons.monetization_on,
                    size: 24,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '필요 크레딧: ${_tournament!.creditCost ?? 20} / 보유 크레딧: ${appState.currentUser!.credits}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _applyToTournament,
            style: ElevatedButton.styleFrom(
              backgroundColor: _getRoleColor(_selectedRole),
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
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getRoleIcon(_selectedRole),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_getRoleName(_selectedRole)} 역할로 신청하기', 
                        style: const TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold
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
        await _loadTournament();
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
  
  String _getStatusText() {
    if (_tournament == null) return '';
    
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
    if (_tournament == null) return Colors.grey;
    
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
  
  int _calculateTotalSlots() {
    if (_tournament == null) return 0;
    
    return _tournament!.slotsByRole.values.fold(0, (sum, slots) => sum + slots);
  }
  
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
} 