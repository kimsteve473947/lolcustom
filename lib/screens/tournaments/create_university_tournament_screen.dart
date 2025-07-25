import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/widgets/tier_selector.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';
import 'package:lol_custom_game_manager/providers/chat_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateUniversityTournamentScreen extends StatefulWidget {
  const CreateUniversityTournamentScreen({Key? key}) : super(key: key);

  @override
  State<CreateUniversityTournamentScreen> createState() => _CreateUniversityTournamentScreenState();
}

class _CreateUniversityTournamentScreenState extends State<CreateUniversityTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  String _autoGeneratedTitle = '대학 대항전';
  final _descriptionController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  
  TournamentType _tournamentType = TournamentType.casual;
  
  // 대학 관련 필드
  String? _userUniversity; // 사용자의 대학
  String? _userStudentId; // 학번
  bool _isUniversityVerified = false; // 대학 인증 상태
  
        // 대학 대항전 설정
  bool _isIntralUniversity = true; // 교내전 vs 교외전
  String? _opponentUniversity; // 교외전인 경우 상대 대학
  
  // 티어 제한
  PlayerTier _selectedTierLimit = PlayerTier.unranked;
  
  // 주최자 선택 포지션
  String _hostPosition = '';
  
  // 라인별 인원 - 각 2명으로 고정 (개인전과 동일)
  final Map<String, int> _slotsByRole = {
    'top': 2,
    'jungle': 2,
    'mid': 2,
    'adc': 2,
    'support': 2,
  };
  
  bool _isLoading = false;
  bool _isMounted = true;
  
  // 롤 포지션 목록
  final List<Map<String, dynamic>> _positions = [
    {'id': 'top', 'name': '탑', 'imagePath': LolLaneIcons.top},
    {'id': 'jungle', 'name': '정글', 'imagePath': LolLaneIcons.jungle},
    {'id': 'mid', 'name': '미드', 'imagePath': LolLaneIcons.mid},
    {'id': 'adc', 'name': '원딜', 'imagePath': LolLaneIcons.adc},
    {'id': 'support', 'name': '서폿', 'imagePath': LolLaneIcons.support},
  ];
  
  // 주요 대학 목록
  final List<String> _majorUniversities = [
    '서울대학교',
    '연세대학교', 
    '고려대학교',
    '성균관대학교',
    '한양대학교',
    '중앙대학교',
    '경희대학교',
    '한국외국어대학교',
    '서강대학교',
    '이화여자대학교',
    '카이스트',
    '포스텍',
    '부산대학교',
    '전남대학교',
    '경북대학교',
    '충남대학교',
  ];
  
  @override
  void initState() {
    super.initState();
    _initializeMinimumFutureTime();
    _loadUserUniversityInfo();
  }
  
  // 사용자의 대학 정보 로드
  Future<void> _loadUserUniversityInfo() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final currentUser = appState.currentUser;
    
    // 대학 정보는 additionalInfo에서 가져오거나 기본값 사용
    final universityInfo = currentUser?.additionalInfo?['university'] as String?;
    final studentId = currentUser?.additionalInfo?['studentId'] as String?;
    final isVerified = currentUser?.additionalInfo?['isUniversityVerified'] as bool? ?? false;
    
    if (universityInfo == null || !isVerified) {
      // 대학 인증이 안된 경우 에러 표시
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('대학 대항전을 만들려면 먼저 대학 인증을 받아야 합니다.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
      });
      return;
    }
    
    if (mounted) {
      setState(() {
        _userUniversity = universityInfo;
        _userStudentId = studentId;
        _isUniversityVerified = isVerified;
        _autoGeneratedTitle = '$_userUniversity 리그전';
      });
    }
  }
  
  void _initializeMinimumFutureTime() {
    final now = DateTime.now();
    final minimumTime = now.add(const Duration(minutes: 30));
    final minute = minimumTime.minute;
    final roundedMinute = minute < 30 ? 30 : 0;
    final hourAdjust = minute < 30 ? 0 : 1;
    
    final adjustedTime = TimeOfDay(
      hour: (minimumTime.hour + hourAdjust) % 24, 
      minute: roundedMinute
    );
    
    setState(() {
      _selectedTime = adjustedTime;
      _selectedDate = DateTime(
        minimumTime.year,
        minimumTime.month,
        minimumTime.day,
        adjustedTime.hour,
        adjustedTime.minute,
      );
    });
  }
  
  @override
  void dispose() {
    _descriptionController.dispose();
    _isMounted = false;
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isUniversityVerified) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('대학 대항전 만들기'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('대학 대항전 만들기'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUniversityInfoSection(),
              const SizedBox(height: 24),
              _buildTitleSection(),
              const SizedBox(height: 24),
              _buildDateTimeSection(),
              const SizedBox(height: 24),
              _buildMatchTypeSection(),
              const SizedBox(height: 24),
              _buildHostPositionSection(),
              const SizedBox(height: 24),
              _buildDescriptionSection(),
              const SizedBox(height: 32),
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildUniversityInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _userUniversity ?? '알 수 없는 대학',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '인증됨',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '학번: ${_userStudentId ?? '미확인'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '리그전 제목',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _autoGeneratedTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '리그전 시작 시간',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDateTimeCard(
                icon: Icons.calendar_today,
                title: '날짜',
                subtitle: DateFormat('MM월 dd일 (E)', 'ko_KR').format(_selectedDate),
                onTap: () => _selectDate(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateTimeCard(
                icon: Icons.access_time,
                title: '시간',
                subtitle: _selectedTime.format(context),
                onTap: () => _selectTime(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildDateTimeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMatchTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '대전 유형',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMatchTypeOption(
                isInternal: true,
                title: '교내전',
                description: '같은 대학 학생들끼리 대전',
                icon: Icons.school,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMatchTypeOption(
                isInternal: false,
                title: '교외전',
                description: '다른 대학과의 대항전',
                icon: Icons.public,
              ),
            ),
          ],
        ),
        if (!_isIntralUniversity) ...[
          const SizedBox(height: 16),
          _buildOpponentUniversitySelector(),
        ],
      ],
    );
  }
  
  Widget _buildMatchTypeOption({
    required bool isInternal,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _isIntralUniversity == isInternal;
    
    return InkWell(
      onTap: () {
        setState(() {
          _isIntralUniversity = isInternal;
          _updateGeneratedTitle();
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.primary : Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOpponentUniversitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '상대 대학 선택',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _opponentUniversity,
          decoration: InputDecoration(
            hintText: '상대 대학을 선택해주세요',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
          items: _majorUniversities
              .where((university) => university != _userUniversity)
              .map((university) => DropdownMenuItem(
                    value: university,
                    child: Text(university),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _opponentUniversity = value;
              _updateGeneratedTitle();
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildHostPositionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '주최자 포지션',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '리그전에서 플레이할 포지션을 선택해주세요',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _positions.map((position) {
            final isSelected = _hostPosition == position['id'];
            return InkWell(
              onTap: () {
                setState(() {
                  _hostPosition = position['id'];
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      position['imagePath'],
                      width: 20,
                      height: 20,
                      color: isSelected ? AppColors.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      position['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.primary : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildTournamentTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '리그전 유형',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTournamentTypeOption(
                TournamentType.casual,
                '일반전',
                '무료로 참가 가능한 일반 대학 대항전입니다.',
                Icons.sports_esports,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTournamentTypeOption(
                TournamentType.competitive,
                '경쟁전',
                '참가자는 20 크레딧을 소모하며, 심판이 배정되는 경쟁적인 리그전입니다.',
                Icons.emoji_events,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildTournamentTypeOption(
    TournamentType type,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = _tournamentType == type;
    
    return InkWell(
      onTap: () {
        setState(() {
          _tournamentType = type;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.primary : Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTierLimitSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '티어 제한',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TierSelector(
          initialTier: _selectedTierLimit,
          onTierChanged: (tier) {
            setState(() {
              _selectedTierLimit = tier;
              _updateGeneratedTitle();
            });
          },
          title: '티어 제한',
          subtitle: '참가자 제한 티어를 선택하세요',
        ),
      ],
    );
  }
  
  void _updateGeneratedTitle() {
    if (_userUniversity != null) {
      String tierText = _selectedTierLimit == PlayerTier.unranked
          ? '랜덤'
          : _selectedTierLimit.toString().split('.').last.toUpperCase();
      
      String typeText = _isIntralUniversity ? '교내전' : '교외전';
      String opponentText = !_isIntralUniversity && _opponentUniversity != null 
          ? ' vs $_opponentUniversity'
          : '';
      
      setState(() {
        _autoGeneratedTitle = '$_userUniversity $tierText $typeText$opponentText';
      });
    }
  }
  
  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '추가 설명 (선택사항)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: InputDecoration(
                            hintText: '대학 대항전에 대한 추가 정보를 입력해주세요',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCreateButton() {
    final isFormValid = _validateForm();
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isFormValid && !_isLoading ? _createUniversityTournament : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                '대학 대항전 만들기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
  
  bool _validateForm() {
    // 주최자 포지션 선택 확인
    if (_hostPosition.isEmpty) return false;
    
    // 교외전인 경우 상대 대학 선택 확인
    if (!_isIntralUniversity && _opponentUniversity == null) return false;
    
    return true;
  }
  
  Future<void> _createUniversityTournament() async {
    if (!_validateForm()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final currentUser = appState.currentUser;
      
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }
      
      // 대학 대항전 토너먼트 생성
      final newTournament = await appState.createTournament(
        title: _autoGeneratedTitle,
        location: '한국 서버',
        startsAt: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        ),
        slotsByRole: _slotsByRole,
        tournamentType: _tournamentType,
        gameCategory: GameCategory.university,
        tierLimit: _selectedTierLimit,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : '$_userUniversity 대학 대항전입니다',
        hostPosition: _hostPosition,
      );

      if (!mounted) return;

      if (newTournament != null) {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.refreshChatRoomsAfterTournamentCreation(newTournament.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('대학 대항전이 생성되었습니다'),
            backgroundColor: AppColors.success,
          ),
        );

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('대학 대항전 생성에 실패했습니다');
      }
    } catch (e) {
      debugPrint('대학 대항전 생성 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('대학 대항전 생성 실패: $e'),
            backgroundColor: Colors.red,
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
  
  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }
} 