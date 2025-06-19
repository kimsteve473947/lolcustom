import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/providers/clan_recruitment_provider.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';

class ClanRecruitmentScreen extends StatefulWidget {
  const ClanRecruitmentScreen({Key? key}) : super(key: key);

  @override
  State<ClanRecruitmentScreen> createState() => _ClanRecruitmentScreenState();
}

class _ClanRecruitmentScreenState extends State<ClanRecruitmentScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isPublishing = false;
  late AnimationController _fadeController;
  late AnimationController _progressController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    
    _fadeController.forward();
    _updateProgress();
    
    // 클랜장 권한 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppStateProvider>();
      if (appState.currentUser == null || appState.myClan == null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('클랜 정보를 찾을 수 없습니다.')),
        );
        return;
      }
      
      // 클랜장만 접근 가능
      if (appState.myClan!.ownerId != appState.currentUser!.uid) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('클랜장만 모집 공고를 작성할 수 있습니다.')),
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _updateProgress() {
    _progressController.animateTo((_currentPage + 1) / 3);
  }

  void _nextPage() {
    if (_currentPage < 2) {
      // 페이지별 검증
      if (!_validateCurrentPage()) {
        return;
      }
      
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  bool _validateCurrentPage() {
    final provider = context.read<ClanRecruitmentProvider>();
    
    if (_currentPage == 0) {
      // 첫 번째 페이지 검증
      if (provider.teamFeatures.isEmpty) {
        _showValidationError('팀 특징을 선택해주세요.');
        return false;
      }
      if (provider.preferredPositions.isEmpty) {
        _showValidationError('모집 중인 주요 포지션을 선택해주세요.');
        return false;
      }
      if (provider.activityDays.isEmpty) {
        _showValidationError('주요 활동 요일을 선택해주세요.');
        return false;
      }
      if (provider.activityTimes.isEmpty) {
        _showValidationError('주요 활동 시간을 선택해주세요.');
        return false;
      }
    } else if (_currentPage == 1) {
      // 두 번째 페이지 검증
      if (provider.preferredGender == null) {
        _showValidationError('성별을 선택해주세요.');
        return false;
      }
      if (provider.preferredTiers.isEmpty) {
        _showValidationError('티어를 선택해주세요.');
        return false;
      }
      if (provider.preferredAgeGroups.isEmpty) {
        _showValidationError('나이를 선택해주세요.');
        return false;
      }
    }
    
    return true;
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
                  _updateProgress();
        },
        children: [
          _buildInfoPage(),
          _buildTargetPage(),
          _buildDetailPage(),
        ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      centerTitle: true,
      title: Text(
        '멤버 모집 (${_currentPage + 1}/3)',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
        onPressed: () {
          if (_currentPage == 0) {
            Navigator.of(context).pop();
          } else {
            _previousPage();
          }
        },
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          children: [
            Row(
              children: [
                _buildStepIndicator(0, '팀 정보'),
                _buildProgressLine(0),
                _buildStepIndicator(1, '영입 대상'),
                _buildProgressLine(1),
                _buildStepIndicator(2, '상세 정보'),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progressAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String title) {
    final isActive = step <= _currentPage;
    final isCompleted = step < _currentPage;
    
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive ? [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Icon(
            isCompleted ? Icons.check : Icons.circle,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppColors.primary : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(int step) {
    final isActive = step < _currentPage;
    
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _previousPage,
                        child: Container(
                          height: 56,
                          alignment: Alignment.center,
                          child: const Text(
                            '이전',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_currentPage > 0) const SizedBox(width: 12),
              Expanded(
                flex: _currentPage > 0 ? 1 : 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _isPublishing ? null : () async {
                if (_currentPage < 2) {
                  _nextPage();
                } else {
                  setState(() => _isPublishing = true);
                  try {
                    final appState = context.read<AppStateProvider>();
                    final recruitmentProvider = context.read<ClanRecruitmentProvider>();
                    
                    if (appState.currentUser == null || appState.myClan == null) {
                      throw Exception('사용자 또는 클랜 정보를 찾을 수 없습니다.');
                    }

                    await recruitmentProvider.publishPost(
                      currentUser: appState.currentUser!,
                      currentClan: appState.myClan!,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('모집 공고가 성공적으로 등록되었습니다.'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green.shade400,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                      );
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.error, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('등록 실패: $e')),
                                    ],
                                  ),
                                  backgroundColor: Colors.red.shade400,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isPublishing = false);
                    }
                  }
                }
              },
                      child: Container(
                        height: 56,
                        alignment: Alignment.center,
                        child: _isPublishing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _currentPage == 2 ? '등록하기' : '다음',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  // Page 1: 팀 정보
  Widget _buildInfoPage() {
    final provider = context.watch<ClanRecruitmentProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            '본인클랜의 정보를 확인하세요',
            '클랜의 특징과 활동 정보를 설정해주세요',
            Icons.info_outline,
          ),
          const SizedBox(height: 20),
          _buildChipSection(
            title: '팀 특징',
            chips: ['솔랭전사', '칼바람 나락', '대회 준비', '내전', '초보 환영', '실력자만'],
            selectedChips: provider.teamFeatures,
            onSelected: (feature) => provider.toggleTeamFeature(feature),
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildChipSection(
            title: '모집 중인 주요 포지션',
            chips: ['탑', '정글', '미드', '원딜', '서폿', '상관 없음'],
            selectedChips: provider.preferredPositions,
            onSelected: (pos) => provider.togglePosition(pos),
            isRequired: true,
            description: '중복 선택 가능',
          ),
          const SizedBox(height: 16),
          _buildChipSection(
            title: '주요 활동 요일',
            chips: ['월', '화', '수', '목', '금', '토', '일'],
            selectedChips: provider.activityDays,
            onSelected: (day) => provider.toggleActivityDay(day),
            isRequired: true,
            description: '중복 선택 가능',
          ),
          const SizedBox(height: 16),
          _buildChipSection(
            title: '주요 활동 시간',
            chips: ['아침', '낮', '저녁', '심야'],
            selectedChips: provider.activityTimes,
            onSelected: (time) => provider.toggleActivityTime(time),
            isRequired: true,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Page 2: 영입 대상
  Widget _buildTargetPage() {
    final provider = context.watch<ClanRecruitmentProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            '어떤 사람을 영입할까요?',
            '원하는 클랜원의 조건을 설정해주세요',
            Icons.person_search,
          ),
          const SizedBox(height: 20),
          _buildSingleChoiceChipSection(
            title: '성별',
            chips: ['남자', '여자', '무관'],
            selectedChip: provider.preferredGender,
            onSelected: (gender) => provider.setGender(gender),
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildChipSection(
            title: '티어',
            chips: ['티어 무관', '아이언', '브론즈', '실버', '골드', '플래티넘', '에메랄드', '다이아 이상'],
            selectedChips: provider.preferredTiers,
            onSelected: (tier) => provider.toggleTier(tier),
            isRequired: true,
            description: '중복 선택 가능',
          ),
          const SizedBox(height: 16),
          _buildChipSection(
            title: '나이',
            chips: ['10대', '20대', '30대', '40대', '50대', '60대 이상'],
            selectedChips: provider.preferredAgeGroups,
            onSelected: (age) => provider.toggleAgeGroup(age),
            isRequired: true,
            description: '중복 선택 가능',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Page 3: 상세 소개 및 등록
  Widget _buildDetailPage() {
    final provider = context.watch<ClanRecruitmentProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            '멤버 모집',
            '클랜을 소개하고 모집 공고를 작성해주세요',
            Icons.edit_note,
          ),
          const SizedBox(height: 24),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '팀 단체 사진 추가하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '선택사항',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '모집 공고 제목',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Text(
                      ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
          TextField(
            onChanged: (value) => provider.updateTitle(value),
                  decoration: InputDecoration(
                    hintText: '함께 즐겁게 게임할 팀원 구해요!',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '클랜 소개',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Text(
                      ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
          TextField(
            onChanged: (value) => provider.updateDescription(value),
                  maxLines: 6,
                  decoration: InputDecoration(
              hintText: '여기를 누르고 클랜을 소개하세요',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '이런 내용이 포함되면 좋아요',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Text(
                      ' 🙂',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTipItem('주로 접속하는 시간대'),
                    _buildTipItem('현재 클랜원 수'),
                    _buildTipItem('주로 하는 게임 모드(랭크, 칼바람 등)'),
                    _buildTipItem('가입 조건 및 절차'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              '클랜 가입을 신청하면 신청자의 프로필을 확인할 수 있어요. \'멤버 모집\'을 위한 목적으로만 프로필을 확인하고, 과도한 개인정보 요구는 삼가주세요.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPageHeader(String title, String subtitle, IconData icon) {
    return _buildCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildChipSection({
    required String title,
    required List<String> chips,
    required Set<String> selectedChips,
    required ValueChanged<String> onSelected,
    required bool isRequired,
    String? description,
  }) {
    return _buildCard(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (isRequired)
                const Text(
                  ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 16),
        Wrap(
          spacing: 8.0,
            runSpacing: 8.0,
          children: chips.map((chip) {
            final isSelected = selectedChips.contains(chip);
              return _buildModernChip(
                label: chip,
                isSelected: isSelected,
                onTap: () => onSelected(chip),
            );
          }).toList(),
        ),
      ],
      ),
    );
  }
  
  Widget _buildSingleChoiceChipSection({
    required String title,
    required List<String> chips,
    required String? selectedChip,
    required ValueChanged<String> onSelected,
    required bool isRequired,
  }) {
    return _buildCard(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (isRequired)
                const Text(
                  ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        Wrap(
          spacing: 8.0,
            runSpacing: 8.0,
          children: chips.map((chip) {
            final isSelected = selectedChip == chip;
              return _buildModernChip(
                label: chip,
                isSelected: isSelected,
                onTap: () => onSelected(chip),
            );
          }).toList(),
        ),
        ],
      ),
    );
  }

  Widget _buildModernChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
      builder: (context, value, child) {
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? AppColors.primary 
                    : Colors.grey.shade200,
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}