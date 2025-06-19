import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';

class MercenaryRegistrationScreen extends StatefulWidget {
  final String? mercenaryId;
  
  const MercenaryRegistrationScreen({Key? key, this.mercenaryId}) : super(key: key);

  @override
  State<MercenaryRegistrationScreen> createState() => _MercenaryRegistrationScreenState();
}

class _MercenaryRegistrationScreenState extends State<MercenaryRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _demographicController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  
  // 사용자 기본 정보
  UserModel? _user;
  File? _profileImage;
  String? _profileImageUrl;
  
  // 용병 상태
  bool _isAvailable = true;
  
  // 티어 목록
  PlayerTier _selectedTier = PlayerTier.unranked;
  
  // 포지션 관련 상태
  final List<String> _positions = ['TOP', 'JUNGLE', 'MID', 'ADC', 'SUPPORT'];
  Set<String> _selectedPositions = {};
  
  // 롤 스탯 (맵으로 관리)
  Map<String, int> _roleStats = {
    'top': 50,
    'jungle': 50,
    'mid': 50, 
    'adc': 50,
    'support': 50,
  };
  
  // 시간대 선택 관련
  Map<String, Set<String>> _availabilityTimeSlots = {};
  
  // 로딩 상태
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  MercenaryModel? _existingMercenary;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize time slots for each day
    for (var day in kDaysOfWeek) {
      _availabilityTimeSlots[day] = {};
    }
    
    _loadData();
  }
  
  @override
  void dispose() {
    _descriptionController.dispose();
    _demographicController.dispose();
    super.dispose();
  }
  
  // 데이터 로드
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 현재 로그인한 사용자 정보 가져오기
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      _user = appState.currentUser;
      
      if (_user == null) {
        setState(() {
          _errorMessage = '로그인이 필요합니다';
          _isLoading = false;
        });
        return;
      }
      
      // 기존 용병 정보가 있는지 확인
      if (widget.mercenaryId != null) {
        final mercenary = await _firebaseService.getMercenary(widget.mercenaryId!);
        
        if (mercenary != null) {
          setState(() {
            _existingMercenary = mercenary;
            _selectedPositions = Set<String>.from(mercenary.preferredPositions);
            _roleStats = Map<String, int>.from(mercenary.roleStats);
            _descriptionController.text = mercenary.description ?? '';
            _demographicController.text = mercenary.demographicInfo ?? '';
            _isAvailable = mercenary.isAvailable;
            _profileImageUrl = mercenary.profileImageUrl;
            _selectedTier = mercenary.tier;
            
            // Set availability time slots
            if (mercenary.availabilityTimeSlots.isNotEmpty) {
              mercenary.availabilityTimeSlots.forEach((day, slots) {
                _availabilityTimeSlots[day] = Set<String>.from(slots);
              });
            }
          });
        }
      }
      
      // 유저 정보 기반으로 기본 값 설정
      if (_user != null) {
        setState(() {
          if (_selectedTier == PlayerTier.unranked) {
            _selectedTier = _user!.tier;
          }
          _profileImageUrl ??= _user!.profileImageUrl;
          
          // Set default demographic if empty
          if (_demographicController.text.isEmpty) {
            String gender = _user!.gender ?? '미설정';
            String ageGroup = _user!.ageGroup ?? '미설정';
            _demographicController.text = '$gender/$ageGroup';
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '데이터를 불러오는 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 이미지 선택
  Future<void> _pickImage() async {
    final imagePicker = ImagePicker();
    final pickedImage = await imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    
    if (pickedImage != null) {
      setState(() {
        _profileImage = File(pickedImage.path);
      });
    }
  }
  
  // 시간대 토글
  void _toggleTimeSlot(String day, String timeSlot) {
    setState(() {
      if (_availabilityTimeSlots[day]!.contains(timeSlot)) {
        _availabilityTimeSlots[day]!.remove(timeSlot);
      } else {
        _availabilityTimeSlots[day]!.add(timeSlot);
      }
    });
  }
  
  // 용병 프로필 저장
  Future<void> _saveMercenaryProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    // 적어도 하나의 포지션이 선택되었는지 확인
    if (_selectedPositions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 1개 이상의 포지션을 선택해주세요')),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final currentUser = appState.currentUser!;
      
      String? profileImageUrl = _profileImageUrl;
      
      // 이미지가 변경되었다면 업로드
      if (_profileImage != null) {
        final bytes = await _profileImage!.readAsBytes();
        final userId = currentUser.uid;
        final path = 'mercenaries/$userId/profile.jpg';
        
        final newImageUrl = await _firebaseService.uploadImage(
          path, 
          bytes,
        );
        if (newImageUrl != null) {
          profileImageUrl = newImageUrl;
        }
      }
      
      // 각 포지션의 평균 능력치 계산
      final int sumRoleStats = _roleStats.values.fold(0, (sum, stat) => sum + stat);
      final double averageRoleStat = _roleStats.isNotEmpty ? sumRoleStats / _roleStats.length : 0;
      
      // Convert availability time slots to the format needed for Firestore
      final Map<String, List<String>> availabilityTimeSlots = {};
      _availabilityTimeSlots.forEach((day, slots) {
        if (slots.isNotEmpty) {
          availabilityTimeSlots[day] = slots.toList();
        }
      });
      
      // 등록 또는 업데이트할 mercenary 객체 생성
      final mercenary = MercenaryModel(
        id: _existingMercenary?.id ?? '',
        userUid: currentUser.uid,
        createdAt: _existingMercenary?.createdAt ?? Timestamp.now(),
        description: _descriptionController.text.trim(),
        preferredPositions: _selectedPositions.toList(),
        roleStats: _roleStats,
        averageRoleStat: averageRoleStat,
        nickname: currentUser.nickname,
        profileImageUrl: profileImageUrl,
        tier: _selectedTier,
        isAvailable: _isAvailable,
        lastActiveAt: Timestamp.now(),
        availabilityTimeSlots: availabilityTimeSlots,
        demographicInfo: _demographicController.text.trim(),
      );
      
      // 새로운 용병 프로필 등록 또는 기존 프로필 업데이트
      if (_existingMercenary == null) {
        final id = await _firebaseService.createMercenaryProfile(mercenary);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('용병 프로필이 등록되었습니다')),
        );
        context.pop(true);
      } else {
        await _firebaseService.updateMercenaryProfile(mercenary);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('용병 프로필이 업데이트되었습니다')),
        );
        context.pop(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existingMercenary == null ? '용병 등록' : '용병 프로필 수정'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveMercenaryProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('저장', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _buildForm(),
    );
  }
  
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 이미지 및 기본 정보
            _buildProfileSection(),
            const SizedBox(height: 24),
            
            // 한 줄 소개
            _buildDescriptionField(),
            const SizedBox(height: 24),
            
            // 인적 정보
            _buildDemographicField(),
            const SizedBox(height: 24),
            
            // 티어 선택
            _buildTierSelector(),
            const SizedBox(height: 24),
            
            // 선호 포지션
            _buildPositionSelector(),
            const SizedBox(height: 24),
            
            // 포지션 별 능력치
            _buildRoleStatsSelector(),
            const SizedBox(height: 24),
            
            // 가능 시간대
            _buildTimeSlotSelector(),
            const SizedBox(height: 24),
            
            // 가용 상태 토글
            _buildAvailabilityToggle(),
            const SizedBox(height: 32),
            
            // 저장 버튼 (하단 고정)
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }
  
  // 프로필 이미지 섹션
  Widget _buildProfileSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!) as ImageProvider
                      : _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!) as ImageProvider
                          : const AssetImage('assets/images/profile_placeholder.png') as ImageProvider,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _user?.nickname ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  // 한 줄 소개
  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '한 줄 소개',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          maxLength: 100,
          decoration: const InputDecoration(
            hintText: '소개를 입력해주세요. (예: 서폿 전문, 주말에만 활동 가능)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
  
  // 인적 정보 입력
  Widget _buildDemographicField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '인적 정보 (성별/나이대)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _demographicController,
          decoration: const InputDecoration(
            hintText: '예: 남/20대, 여/10대',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
  
  // 티어 선택기
  Widget _buildTierSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '티어',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<PlayerTier>(
              value: _selectedTier,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              items: PlayerTier.values.map((tier) {
                return DropdownMenuItem<PlayerTier>(
                  value: tier,
                  child: Text(_getTierName(tier)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedTier = value;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }
  
  // 포지션 선택기
  Widget _buildPositionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '선호 포지션',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _positions.map((position) {
            final isSelected = _selectedPositions.contains(position);
            return FilterChip(
              label: Text(position),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedPositions.add(position);
                  } else {
                    _selectedPositions.remove(position);
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
  
  // 역할 별 능력치 선택기
  Widget _buildRoleStatsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '역할별 능력치',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ..._roleStats.entries.map((entry) {
          final role = entry.key;
          final value = entry.value;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    _getRoleName(role),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: value.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 10,
                    label: value.toString(),
                    onChanged: (newValue) {
                      setState(() {
                        _roleStats[role] = newValue.round();
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
  
  // 가능 시간대 선택기
  Widget _buildTimeSlotSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '가능 시간대',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const SizedBox(width: 80),
                    ...kTimeSlots.map((slot) {
                      return Expanded(
                        child: Text(
                          slot,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...kDaysOfWeek.map((day) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              day,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...kTimeSlots.map((slot) {
                            final isSelected = _availabilityTimeSlots[day]!.contains(slot);
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => _toggleTimeSlot(day, slot),
                                child: Container(
                                  height: 40,
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? AppColors.primary 
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isSelected ? Icons.check : Icons.close,
                                    color: isSelected ? Colors.white : Colors.grey,
                                    size: 20,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    if (day != kDaysOfWeek.last) const Divider(height: 1),
                  ],
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }
  
  // 가용성 토글
  Widget _buildAvailabilityToggle() {
    return SwitchListTile(
      title: const Text(
        '현재 용병 가능 여부',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(_isAvailable ? '가능' : '불가능'),
      value: _isAvailable,
      activeColor: AppColors.primary,
      onChanged: (value) {
        setState(() {
          _isAvailable = value;
        });
      },
    );
  }
  
  // 저장 버튼
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveMercenaryProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _existingMercenary == null ? '용병 등록하기' : '용병 정보 업데이트',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
  
  // 헬퍼 메서드: 롤 이름 반환
  String _getRoleName(String role) {
    switch (role) {
      case 'top': return '탑';
      case 'jungle': return '정글';
      case 'mid': return '미드';
      case 'adc': return '원딜';
      case 'support': return '서폿';
      default: return role;
    }
  }
  
  // 헬퍼 메서드: 티어 이름 반환
  String _getTierName(PlayerTier tier) {
    switch (tier) {
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
      case PlayerTier.unranked: return '언랭크';
    }
  }
}