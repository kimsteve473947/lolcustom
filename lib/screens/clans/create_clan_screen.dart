import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/models/enums/clan_enums.dart';
import 'package:lol_custom_game_manager/providers/clan_creation_provider.dart';

class CreateClanScreen extends StatefulWidget {
  const CreateClanScreen({Key? key}) : super(key: key);

  @override
  State<CreateClanScreen> createState() => _CreateClanScreenState();
}

class _CreateClanScreenState extends State<CreateClanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();
  
  bool _isPublic = true;
  bool _isRecruiting = true;
  bool _isLoading = false;
  
  // 활동 요일
  final List<String> _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final List<String> _selectedDays = [];
  
  // 활동 시간대
  final List<PlayTimeType> _selectedTimes = [];
  
  // 연령대
  final List<AgeGroup> _selectedAgeGroups = [];
  
  // 클랜 성향
  ClanFocus _clanFocus = ClanFocus.balanced;
  int _focusRating = 5;
  
  // 성별 선호
  GenderPreference _genderPreference = GenderPreference.any;
  
  final ClanService _clanService = ClanService();
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('클랜 생성'),
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfoSection(),
                    const SizedBox(height: 24),
                    _buildActivitySection(),
                    const SizedBox(height: 24),
                    _buildPreferencesSection(),
                    const SizedBox(height: 32),
                    _buildCreateButton(),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '기본 정보',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // 클랜 이름
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '클랜 이름',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '클랜 이름을 입력하세요';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        // 클랜 설명
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: '클랜 설명',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        
        // 웹사이트
        TextFormField(
          controller: _websiteController,
          decoration: const InputDecoration(
            labelText: '웹사이트 URL',
            border: OutlineInputBorder(),
            hintText: 'https://',
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        
        // 공개 여부 및 모집 상태 설정
        SwitchListTile(
          title: const Text('클랜 공개'),
          subtitle: const Text('클랜을 검색 결과에 표시합니다'),
          value: _isPublic,
          onChanged: (value) {
            setState(() {
              _isPublic = value;
            });
          },
          activeColor: AppColors.primary,
        ),
        
        SwitchListTile(
          title: const Text('멤버 모집'),
          subtitle: const Text('새로운 멤버를 모집합니다'),
          value: _isRecruiting,
          onChanged: (value) {
            setState(() {
              _isRecruiting = value;
            });
          },
          activeColor: AppColors.primary,
        ),
      ],
    );
  }
  
  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '활동 정보',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // 활동 요일
        const Text('활동 요일'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _weekdays.map((day) {
            final isSelected = _selectedDays.contains(day);
            return FilterChip(
              label: Text(day),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedDays.add(day);
                  } else {
                    _selectedDays.remove(day);
                  }
                });
              },
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        
        // 활동 시간대
        const Text('활동 시간대'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: PlayTimeType.values.map((time) {
            final isSelected = _selectedTimes.contains(time);
            return FilterChip(
              label: Text(_getPlayTimeText(time)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTimes.add(time);
                  } else {
                    _selectedTimes.remove(time);
                  }
                });
              },
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '선호 정보',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // 연령대
        const Text('선호 연령대'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: AgeGroup.values.map((age) {
            final isSelected = _selectedAgeGroups.contains(age);
            return FilterChip(
              label: Text(_getAgeGroupText(age)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedAgeGroups.add(age);
                  } else {
                    _selectedAgeGroups.remove(age);
                  }
                });
              },
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        
        // 성별 선호
        const Text('성별 선호'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: GenderPreference.values.map((gender) {
            return ChoiceChip(
              label: Text(_getGenderPreferenceText(gender)),
              selected: _genderPreference == gender,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _genderPreference = gender;
                  });
                }
              },
              selectedColor: AppColors.primary.withOpacity(0.2),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        
        // 클랜 성향
        const Text('클랜 성향'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ClanFocus.values.map((focus) {
            return ChoiceChip(
              label: Text(_getFocusText(focus)),
              selected: _clanFocus == focus,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _clanFocus = focus;
                  });
                }
              },
              selectedColor: AppColors.primary.withOpacity(0.2),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        
        // 클랜 성향 강도
        Row(
          children: [
            const Text('클랜 성향 강도: '),
            Text(
              _focusRating < 5 ? '캐주얼' :
              _focusRating > 5 ? '경쟁적' : '균형',
              style: TextStyle(
                color: _focusRating < 5 ? Colors.green :
                       _focusRating > 5 ? Colors.red : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: _focusRating.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          label: _focusRating.toString(),
          onChanged: (value) {
            setState(() {
              _focusRating = value.toInt();
            });
          },
          activeColor: _focusRating < 5 ? Colors.green :
                       _focusRating > 5 ? Colors.red : Colors.blue,
        ),
      ],
    );
  }
  
  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _createClan,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                '클랜 생성하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
  
  String _getPlayTimeText(PlayTimeType type) {
    switch (type) {
      case PlayTimeType.morning:
        return '아침 (6시~12시)';
      case PlayTimeType.afternoon:
        return '오후 (12시~6시)';
      case PlayTimeType.evening:
        return '저녁 (6시~12시)';
      case PlayTimeType.night:
        return '심야 (0시~6시)';
    }
  }
  
  String _getAgeGroupText(AgeGroup group) {
    switch (group) {
      case AgeGroup.teenager:
        return '10대';
      case AgeGroup.twenties:
        return '20대';
      case AgeGroup.thirties:
        return '30대';
      case AgeGroup.forties:
        return '40대';
      case AgeGroup.fiftyPlus:
        return '50대 이상';
    }
  }
  
  String _getGenderPreferenceText(GenderPreference preference) {
    switch (preference) {
      case GenderPreference.any:
        return '모든 성별';
      case GenderPreference.male:
        return '남성 선호';
      case GenderPreference.female:
        return '여성 선호';
    }
  }
  
  String _getFocusText(ClanFocus focus) {
    switch (focus) {
      case ClanFocus.competitive:
        return '경쟁';
      case ClanFocus.casual:
        return '캐주얼';
      case ClanFocus.balanced:
        return '밸런스';
    }
  }
  
  Future<void> _createClan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 클랜 데이터 구성
      final clanProvider = Provider.of<ClanCreationProvider>(context, listen: false);
      
      // 기본 정보 설정
      clanProvider.setName(_nameController.text.trim());
      clanProvider.setDescription(_descriptionController.text.trim());
      clanProvider.setWebsiteUrl(_websiteController.text.trim());
      
      // 활동 정보 설정
      clanProvider.activityDays.clear();
      clanProvider.activityDays.addAll(_selectedDays);
      
      clanProvider.activityTimes.clear();
      clanProvider.activityTimes.addAll(_selectedTimes);
      
      // 멤버 선호 정보 설정
      clanProvider.ageGroups.clear();
      clanProvider.ageGroups.addAll(_selectedAgeGroups);
      clanProvider.setGenderPreference(_genderPreference);
      
      // 클랜 성향 설정
      clanProvider.setFocus(_clanFocus);
      clanProvider.setFocusRating(_focusRating);
      
      // 플래그 설정
      clanProvider.setIsPublic(_isPublic);
      clanProvider.setIsRecruiting(_isRecruiting);
      
      // 다음 화면으로 이동 (엠블럼 선택 화면)
      if (mounted) {
        context.push('/clans/emblem');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('클랜 생성 중 오류가 발생했습니다: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
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
} 