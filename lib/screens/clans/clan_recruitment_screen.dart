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

class _ClanRecruitmentScreenState extends State<ClanRecruitmentScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isPublishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
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
      appBar: AppBar(
        title: Text('클랜원 모집 (${_currentPage + 1}/3)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentPage == 0) {
              Navigator.of(context).pop();
            } else {
              _previousPage();
            }
          },
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
        },
        children: [
          _buildInfoPage(),
          _buildTargetPage(),
          _buildDetailPage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0).copyWith(bottom: 32),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('뒤로'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isPublishing ? null : () async {
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
                        const SnackBar(content: Text('모집 공고가 성공적으로 등록되었습니다.')),
                      );
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('등록 실패: $e')),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isPublishing = false);
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: _isPublishing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_currentPage == 2 ? '등록하기' : '다음'),
            ),
          ),
        ],
      ),
    );
  }

  // Page 1: 팀 정보
  Widget _buildInfoPage() {
    final provider = context.watch<ClanRecruitmentProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('클랜의 정보를 확인하세요', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildChipSection(
            title: '팀 특징',
            chips: ['자유 랭크 위주', '내전 위주', '대회 준비', '칼바람 나락 즐겨요', '초보 환영', '실력자만', '함께 실력 성장'],
            selectedChips: provider.teamFeatures,
            onSelected: (feature) => provider.toggleTeamFeature(feature),
          ),
          _buildChipSection(
            title: '주요 포지션 (중복 가능)',
            chips: ['탑', '정글', '미드', '원딜', '서폿'],
            selectedChips: provider.preferredPositions,
            onSelected: (pos) => provider.togglePosition(pos),
          ),
          _buildChipSection(
            title: '주요 활동 요일 (중복 가능)',
            chips: ['월', '화', '수', '목', '금', '토', '일'],
            selectedChips: provider.activityDays,
            onSelected: (day) => provider.toggleActivityDay(day),
          ),
          _buildChipSection(
            title: '주요 활동 시간',
            chips: ['아침', '낮', '저녁', '심야'],
            selectedChips: provider.activityTimes,
            onSelected: (time) => provider.toggleActivityTime(time),
          ),
        ],
      ),
    );
  }

  // Page 2: 영입 대상
  Widget _buildTargetPage() {
    final provider = context.watch<ClanRecruitmentProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('어떤 사람을 영입할까요?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildSingleChoiceChipSection(
            title: '성별',
            chips: ['남자', '여자', '무관'],
            selectedChip: provider.preferredGender,
            onSelected: (gender) => provider.setGender(gender),
          ),
          _buildChipSection(
            title: '티어 (중복 가능)',
            chips: ['티어 무관', '아이언', '브론즈', '실버', '골드', '플래티넘', '에메랄드', '다이아 이상'],
            selectedChips: provider.preferredTiers,
            onSelected: (tier) => provider.toggleTier(tier),
          ),
          _buildChipSection(
            title: '나이 (중복 가능)',
            chips: ['10대', '20대', '30대', '40대', '50대', '60대 이상'],
            selectedChips: provider.preferredAgeGroups,
            onSelected: (age) => provider.toggleAgeGroup(age),
          ),
        ],
      ),
    );
  }

  // Page 3: 상세 소개 및 등록
  Widget _buildDetailPage() {
    final provider = context.watch<ClanRecruitmentProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('멤버 모집', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('가입 신청이 들어오면 알림톡으로 알려드려요. 개인 정보 보호를 위해 연락처를 공개하지 마세요.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () { /* TODO: 이미지 선택 로직 */ },
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('팀 단체 사진 추가하기'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            onChanged: (value) => provider.updateTitle(value),
            decoration: const InputDecoration(
              hintText: '모집 공고 제목을 입력하세요 (예: 함께 즐겁게 게임할 팀원 구해요!)',
              border: UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (value) => provider.updateDescription(value),
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: '여기를 누르고 클랜을 소개하세요',
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('이런 내용이 포함되면 좋아요 🙂', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('• 주로 접속하는 시간대', style: TextStyle(color: Colors.grey.shade700)),
                Text('• 현재 클랜원 수', style: TextStyle(color: Colors.grey.shade700)),
                Text('• 주로 하는 게임 모드(랭크, 칼바람 등)', style: TextStyle(color: Colors.grey.shade700)),
                Text('• 가입 조건 및 절차', style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '클랜 가입을 신청하면 신청자의 프로필을 확인할 수 있어요. \'멤버 모집\'을 위한 목적으로만 프로필을 확인하고, 과도한 개인정보 요구는 삼가주세요.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: chips.map((chip) {
            final isSelected = selectedChips.contains(chip);
            return ChoiceChip(
              label: Text(chip),
              selected: isSelected,
              onSelected: (_) => onSelected(chip),
              selectedColor: AppColors.primary.withOpacity(0.2),
              labelStyle: TextStyle(color: isSelected ? AppColors.primary : Colors.black87),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
  
  Widget _buildSingleChoiceChipSection({
    required String title,
    required List<String> chips,
    required String? selectedChip,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: chips.map((chip) {
            final isSelected = selectedChip == chip;
            return ChoiceChip(
              label: Text(chip),
              selected: isSelected,
              onSelected: (_) => onSelected(chip),
              selectedColor: AppColors.primary.withOpacity(0.2),
              labelStyle: TextStyle(color: isSelected ? AppColors.primary : Colors.black87),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}