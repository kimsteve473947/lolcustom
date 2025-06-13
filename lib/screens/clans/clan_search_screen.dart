import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClanSearchScreen extends StatefulWidget {
  const ClanSearchScreen({Key? key}) : super(key: key);

  @override
  State<ClanSearchScreen> createState() => _ClanSearchScreenState();
}

class _ClanSearchScreenState extends State<ClanSearchScreen> {
  final ClanService _clanService = ClanService();
  final TextEditingController _searchController = TextEditingController();
  List<ClanModel> _clans = [];
  bool _isLoading = false;
  String? _selectedCategory;
  AgeGroup? _selectedAgeGroup;
  String? _selectedGender;
  bool _onlyRecruiting = true;

  @override
  void initState() {
    super.initState();
    _loadClans();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClans() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final clans = await _clanService.getRecruitingClans(limit: 50);
      setState(() {
        _clans = clans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('클랜 정보를 불러오는 중 오류가 발생했습니다: $e')),
      );
    }
  }

  List<ClanModel> get filteredClans {
    List<ClanModel> result = List.from(_clans);
    
    // 검색어로 필터링
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      result = result.where((clan) => 
        clan.name.toLowerCase().contains(query) || 
        (clan.description?.toLowerCase().contains(query) ?? false)
      ).toList();
    }
    
    // 카테고리로 필터링
    if (_selectedCategory != null) {
      if (_selectedCategory == '플랜 팀 리그') {
        result = result.where((clan) => clan.focus == ClanFocus.competitive).toList();
      } else if (_selectedCategory == '자체전') {
        result = result.where((clan) => clan.activityDays.isNotEmpty).toList();
      } else if (_selectedCategory == '대회 준비') {
        result = result.where((clan) => clan.focus == ClanFocus.balanced || clan.focus == ClanFocus.competitive).toList();
      } else if (_selectedCategory == '팀 매칭') {
        result = result.where((clan) => clan.areMembersPublic).toList();
      } else if (_selectedCategory == '5vs5 풀살') {
        result = result.where((clan) => clan.description?.contains('5vs5') ?? false).toList();
      } else if (_selectedCategory == '전문 코치') {
        result = result.where((clan) => clan.description?.contains('코치') ?? false).toList();
      } else if (_selectedCategory == '함께 성장') {
        result = result.where((clan) => clan.focus == ClanFocus.casual).toList();
      }
    }
    
    // 나이대로 필터링
    if (_selectedAgeGroup != null) {
      result = result.where((clan) => clan.ageGroups.contains(_selectedAgeGroup)).toList();
    }
    
    // 성별로 필터링
    if (_selectedGender != null) {
      if (_selectedGender == '남자') {
        result = result.where((clan) => 
          clan.genderPreference == GenderPreference.male || 
          clan.genderPreference == GenderPreference.any
        ).toList();
      } else if (_selectedGender == '여자') {
        result = result.where((clan) => 
          clan.genderPreference == GenderPreference.female || 
          clan.genderPreference == GenderPreference.any
        ).toList();
      }
    }
    
    // 모집중인 클랜만 필터링
    if (_onlyRecruiting) {
      result = result.where((clan) => clan.isRecruiting).toList();
    }
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('원하는 유형의 팀을 찾아보세요'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _buildCategoryFilters(),
          _buildSearchBar(),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildClanList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final categories = [
      '플랜 팀 리그',
      '자체전',
      '대회 준비',
      '팀 매칭',
      '5vs5 풀살',
      '전문 코치',
      '함께 성장',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: categories.map((category) {
          final isSelected = _selectedCategory == category;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedCategory = null;
                } else {
                  _selectedCategory = category;
                }
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '클랜 이름 검색',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) {
          setState(() {
            // 검색어가 변경되면 UI 갱신
          });
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      child: Row(
        children: [
          _buildFilterButton('인기순', Icons.trending_up),
          const SizedBox(width: 8),
          _buildFilterButton('종목', Icons.category_outlined),
          const SizedBox(width: 8),
          _buildFilterButton('성별', Icons.people_outline),
          const SizedBox(width: 8),
          _buildFilterButton('레벨', Icons.sort),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, IconData icon) {
    bool isSelected = false;
    
    if (label == '성별' && _selectedGender != null) {
      isSelected = true;
    } else if (label == '종목' && _selectedCategory != null) {
      isSelected = true;
    }
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (label == '성별') {
            _showGenderFilterDialog();
          } else if (label == '종목') {
            // 이미 상단에 표시됨
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            border: Border.all(color: isSelected ? AppColors.primary : Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppColors.primary : Colors.grey[700]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGenderFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('성별 필터'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('모두'),
                leading: Radio<String?>(
                  value: null,
                  groupValue: _selectedGender,
                  onChanged: (value) {
                    Navigator.pop(context);
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                ),
              ),
              ListTile(
                title: const Text('남자'),
                leading: Radio<String?>(
                  value: '남자',
                  groupValue: _selectedGender,
                  onChanged: (value) {
                    Navigator.pop(context);
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                ),
              ),
              ListTile(
                title: const Text('여자'),
                leading: Radio<String?>(
                  value: '여자',
                  groupValue: _selectedGender,
                  onChanged: (value) {
                    Navigator.pop(context);
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClanList() {
    final clans = filteredClans;
    
    if (clans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '검색 결과가 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: clans.length,
      itemBuilder: (context, index) {
        return _buildClanItem(clans[index]);
      },
    );
  }

  Widget _buildClanItem(ClanModel clan) {
    String memberText = '${clan.memberCount}/${clan.maxMembers}명';
    String activityText = clan.activityDays.isEmpty ? '활동일 미지정' : clan.activityDays.join(', ');
    
    // 나이대 텍스트 생성
    String ageGroupText = '';
    if (clan.ageGroups.contains(AgeGroup.teens)) ageGroupText += '10대';
    if (clan.ageGroups.contains(AgeGroup.twenties)) {
      if (ageGroupText.isNotEmpty) ageGroupText += '~';
      ageGroupText += '20대';
    }
    if (clan.ageGroups.contains(AgeGroup.thirties)) {
      if (ageGroupText.isNotEmpty) ageGroupText += '~';
      ageGroupText += '30대';
    }
    if (clan.ageGroups.contains(AgeGroup.fortyPlus)) {
      if (ageGroupText.isNotEmpty) ageGroupText += '~';
      ageGroupText += '40대+';
    }
    if (ageGroupText.isEmpty) ageGroupText = '제한 없음';
    
    // 성별 텍스트 생성
    String genderText = '';
    switch (clan.genderPreference) {
      case GenderPreference.male:
        genderText = '남자';
        break;
      case GenderPreference.female:
        genderText = '여자';
        break;
      case GenderPreference.any:
        genderText = '남녀 모두';
        break;
    }
    
    // 활동 시간대 텍스트 생성
    List<String> timeTexts = [];
    if (clan.activityTimes.contains(PlayTimeType.morning)) timeTexts.add('아침');
    if (clan.activityTimes.contains(PlayTimeType.daytime)) timeTexts.add('낮');
    if (clan.activityTimes.contains(PlayTimeType.evening)) timeTexts.add('저녁');
    if (clan.activityTimes.contains(PlayTimeType.night)) timeTexts.add('심야');
    String timeText = timeTexts.join('+') + (timeTexts.isNotEmpty ? ' 시간대' : '제한 없음');
    
    // 클랜 로고
    Widget clanLogo;
    if (clan.emblem != null) {
      if (clan.emblem is String) {
        // URL
        clanLogo = CircleAvatar(
          radius: 30,
          backgroundImage: NetworkImage(clan.emblem as String),
        );
      } else {
        // 기본 아이콘
        clanLogo = CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[200],
          child: const Icon(Icons.group, size: 30, color: Colors.grey),
        );
      }
    } else {
      clanLogo = CircleAvatar(
        radius: 30,
        backgroundColor: Colors.grey[200],
        child: const Icon(Icons.group, size: 30, color: Colors.grey),
      );
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          final clanId = clan.id;
          debugPrint('검색 화면에서 클랜 상세로 이동: $clanId');
          context.push('/clans/detail/$clanId');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              clanLogo,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          clan.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '멤버 모집',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$activityText · $memberText',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '남녀 모두 · $ageGroupText · $timeText',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 