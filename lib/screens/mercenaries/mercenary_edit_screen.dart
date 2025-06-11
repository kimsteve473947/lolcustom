import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';
import 'package:lol_custom_game_manager/models/mercenary_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';

class MercenaryEditScreen extends StatefulWidget {
  final String? mercenaryId;
  
  const MercenaryEditScreen({Key? key, this.mercenaryId}) : super(key: key);

  @override
  State<MercenaryEditScreen> createState() => _MercenaryEditScreenState();
}

class _MercenaryEditScreenState extends State<MercenaryEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  
  // 사용자 기본 정보
  UserModel? _user;
  File? _profileImage;
  String? _profileImageUrl;
  
  // 용병 상태
  bool _isAvailable = true;
  
  // 티어 목록
  String? _selectedTier;
  final List<String> _tiers = [
    '언랭',
    '아이언',
    '브론즈',
    '실버',
    '골드',
    '플래티넘',
    '에메랄드',
    '다이아몬드',
    '마스터',
    '그랜드마스터',
    '챌린저',
  ];

  // 포지션 관련 상태
  List<String> _selectedPositions = [];
  Map<String, int> _roleStats = {
    'top': 0,
    'jungle': 0,
    'mid': 0, 
    'adc': 0,
    'support': 0,
  };
  
  // 스킬 관련 상태
  Map<String, int> _skillStats = {
    'teamwork': 50,
    'vision': 50,
    'pass': 50,
  };
  
  // 로딩 상태
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  MercenaryModel? _existingMercenary;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
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
            _selectedPositions = List<String>.from(mercenary.preferredPositions);
            _roleStats = Map<String, int>.from(mercenary.roleStats);
            if (mercenary.skillStats != null) {
              _skillStats = Map<String, int>.from(mercenary.skillStats!);
            }
            _descriptionController.text = mercenary.description ?? '';
            _isAvailable = mercenary.isAvailable;
            _profileImageUrl = mercenary.profileImageUrl;
          });
        }
      }
      
      // 유저 정보 기반으로 기본 값 설정
      if (_user != null) {
        setState(() {
          _selectedTier = _tierToString(_user!.tier);
          _profileImageUrl ??= _user!.profileImageUrl;
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
        
        profileImageUrl = await _firebaseService.uploadImage(
          path, 
          bytes,
        );
      }
      
      // 각 포지션의 평균 능력치 계산
      final int sumRoleStats = _roleStats.values.fold(0, (sum, stat) => sum + stat);
      final double averageRoleStat = _roleStats.isNotEmpty ? sumRoleStats / _roleStats.length : 0;
      
      // 등록 또는 업데이트할 mercenary 객체 생성
      final mercenary = MercenaryModel(
        id: _existingMercenary?.id ?? '',
        userUid: currentUser.uid,
        createdAt: _existingMercenary?.createdAt ?? Timestamp.now(),
        description: _descriptionController.text.trim(),
        preferredPositions: _selectedPositions,
        roleStats: _roleStats,
        skillStats: _skillStats,
        averageRating: _existingMercenary?.averageRating ?? 0.0,
        totalRatings: _existingMercenary?.totalRatings ?? 0,
        averageRoleStat: averageRoleStat,
        nickname: currentUser.nickname,
        profileImageUrl: profileImageUrl,
        tier: _tierFromString(_selectedTier ?? '언랭'),
        isAvailable: _isAvailable,
        lastActiveAt: Timestamp.now(),
      );
      
      // 신규 등록 또는 업데이트
      if (_existingMercenary == null) {
        final mercenaryId = await _firebaseService.createMercenaryProfile(mercenary);
        debugPrint('Created new mercenary profile with ID: $mercenaryId');
      } else {
        await _firebaseService.updateMercenaryProfile(mercenary);
        debugPrint('Updated mercenary profile with ID: ${_existingMercenary!.id}');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('용병 프로필이 저장되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 뒤로 가기
        context.pop();
      }
    } catch (e) {
      debugPrint('Error saving mercenary profile: $e');
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('용병 프로필 저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
      );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  
  // 포지션 선택 토글
  void _togglePosition(String position) {
    setState(() {
      if (_selectedPositions.contains(position)) {
        _selectedPositions.remove(position);
      } else {
        _selectedPositions.add(position);
      }
    });
  }
  
  // 역할(role) 능력치 업데이트
  void _updateRoleStat(String role, int value) {
    setState(() {
      _roleStats[role] = value;
    });
  }
  
  // 스킬 능력치 업데이트
  void _updateSkillStat(String skill, int value) {
    setState(() {
      _skillStats[skill] = value;
    });
  }
  
  // 티어 문자열을 PlayerTier enum으로 변환하는 헬퍼 메소드
  PlayerTier _tierFromString(String tierStr) {
    switch (tierStr) {
      case '언랭': return PlayerTier.unranked;
      case '아이언': return PlayerTier.iron;
      case '브론즈': return PlayerTier.bronze;
      case '실버': return PlayerTier.silver;
      case '골드': return PlayerTier.gold;
      case '플래티넘': return PlayerTier.platinum;
      case '에메랄드': return PlayerTier.emerald;
      case '다이아몬드': return PlayerTier.diamond;
      case '마스터': return PlayerTier.master;
      case '그랜드마스터': return PlayerTier.grandmaster;
      case '챌린저': return PlayerTier.challenger;
      default: return PlayerTier.unranked;
    }
  }
  
  // PlayerTier enum을 한글 티어 문자열로 변환하는 헬퍼 메소드
  String _tierToString(PlayerTier tier) {
    switch (tier) {
      case PlayerTier.unranked: return '언랭';
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
      default: return '언랭';
      }
  }
  
  // 포지션 키를 한글 이름으로 변환
  String _positionToKorean(String position) {
    switch (position) {
      case 'top': return '탑';
      case 'jungle': return '정글';
      case 'mid': return '미드';
      case 'adc': return '원딜';
      case 'support': return '서포터';
      default: return position;
    }
  }
  
  // 스킬 키를 한글 이름으로 변환
  String _skillToKorean(String skill) {
    switch (skill) {
      case 'teamwork': return '팀워크';
      case 'vision': return '시야 관리';
      case 'pass': return 'cs 능력';
      default: return skill;
    }
  }
  
  // 능력치에 따른 색상 반환
  Color _getStatColor(int value) {
    if (value >= 90) return Colors.green.shade700;
    if (value >= 80) return Colors.green;
    if (value >= 70) return Colors.lime;
    if (value >= 60) return Colors.amber;
    if (value >= 50) return Colors.orange;
    return Colors.red;
  }
  
  // 포지션에 따른 색상 반환
  Color _getPositionColor(String position) {
    switch (position) {
      case 'top': return AppColors.roleTop;
      case 'jungle': return AppColors.roleJungle;
      case 'mid': return AppColors.roleMid;
      case 'adc': return AppColors.roleAdc;
      case 'support': return AppColors.roleSupport;
      default: return AppColors.primary;
    }
  }
  
  // 포지션에 따른 아이콘 경로 반환
  String _getPositionIconPath(String position) {
    switch (position) {
      case 'top': return LolLaneIcons.top;
      case 'jungle': return LolLaneIcons.jungle;
      case 'mid': return LolLaneIcons.mid;
      case 'adc': return LolLaneIcons.adc;
      case 'support': return LolLaneIcons.support;
      default: return LolLaneIcons.top;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: LoadingIndicator(),
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('용병 등록')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('용병 등록')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('로그인이 필요합니다'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  context.go('/login');
                },
                child: const Text('로그인하기'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_existingMercenary == null ? '용병 등록' : '용병 정보 수정'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveMercenaryProfile,
            child: _isSaving 
              ? const SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('저장', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
          key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProfileSection(),
            const SizedBox(height: 24),
            _buildPositionSelector(),
            const SizedBox(height: 24),
            _buildRoleStatsSection(),
            const SizedBox(height: 24),
            _buildSkillStatsSection(),
            const SizedBox(height: 24),
            _buildDescriptionSection(),
            const SizedBox(height: 32),
            _buildAvailabilityToggle(),
            const SizedBox(height: 40),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
          child: Column(
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
            Row(
            children: [
              // 프로필 이미지
              GestureDetector(
                onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: _profileImage != null 
                    ? FileImage(_profileImage!) 
                          : (_profileImageUrl != null 
                              ? NetworkImage(_profileImageUrl!) as ImageProvider
                        : null),
                        child: _profileImage == null && _profileImageUrl == null
                    ? const Icon(
                        Icons.person,
                              size: 40,
                        color: AppColors.primary,
                      )
                    : null,
                ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // 닉네임 및 기본 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user!.nickname,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_user!.riotId != null && _user!.riotId!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _user!.riotId!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                ),
              ),
              const SizedBox(height: 16),
                      // 티어 선택 드롭다운
              DropdownButtonFormField<String>(
                value: _selectedTier,
                decoration: const InputDecoration(
                  labelText: '티어',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                ),
                items: _tiers.map((tier) {
                  return DropdownMenuItem<String>(
                    value: tier,
                    child: Text(tier),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTier = value;
                  });
                },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '티어를 선택해주세요';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPositionSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '선호 포지션',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_selectedPositions.length}/5',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: _selectedPositions.isEmpty ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _selectedPositions.isEmpty ? '선호하는 포지션을 선택해주세요 (최소 1개)' : '플레이 가능한 모든 포지션을 선택해주세요',
              style: TextStyle(
                color: _selectedPositions.isEmpty ? Colors.red : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['top', 'jungle', 'mid', 'adc', 'support'].map((position) {
                final isSelected = _selectedPositions.contains(position);
                final positionColor = _getPositionColor(position);
                
                return GestureDetector(
                  onTap: () => _togglePosition(position),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? positionColor.withOpacity(0.2) : Colors.grey.shade100,
                          border: Border.all(
                            color: isSelected ? positionColor : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Image.asset(
                            _getPositionIconPath(position),
                            width: 30,
                            height: 30,
                            color: isSelected ? positionColor : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _positionToKorean(position),
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? positionColor : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRoleStatsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '포지션별 능력치',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '각 포지션별 자신의 능력치를 평가해주세요 (0~100)',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            ..._roleStats.entries.map((entry) {
              final position = entry.key;
              final value = entry.value;
              final positionColor = _getPositionColor(position);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          _getPositionIconPath(position),
                          width: 20,
                          height: 20,
                          color: positionColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _positionToKorean(position),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: positionColor,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$value',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getStatColor(value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _getStatColor(value),
                        inactiveTrackColor: Colors.grey.shade200,
                        thumbColor: _getStatColor(value),
                        overlayColor: _getStatColor(value).withOpacity(0.2),
                        trackHeight: 8,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                      ),
                      child: Slider(
                        value: value.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 10,
                        onChanged: (newValue) {
                          _updateRoleStat(position, newValue.round());
                        },
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSkillStatsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '스킬 능력치',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '각 스킬별 자신의 능력치를 평가해주세요 (0~100)',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            ..._skillStats.entries.map((entry) {
              final skill = entry.key;
              final value = entry.value;
              
              IconData skillIcon;
              switch (skill) {
                case 'teamwork':
                  skillIcon = Icons.people;
                  break;
                case 'vision':
                  skillIcon = Icons.visibility;
                  break;
                case 'pass':
                  skillIcon = Icons.trending_up;
                  break;
                default:
                  skillIcon = Icons.star;
              }
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(skillIcon, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          _skillToKorean(skill),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$value',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getStatColor(value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _getStatColor(value),
                        inactiveTrackColor: Colors.grey.shade200,
                        thumbColor: _getStatColor(value),
                        overlayColor: _getStatColor(value).withOpacity(0.2),
                        trackHeight: 8,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                      ),
                      child: Slider(
                        value: value.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 10,
                        onChanged: (newValue) {
                          _updateSkillStat(skill, newValue.round());
                        },
                    ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDescriptionSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '자기 소개',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '자신의 플레이 스타일이나 챔피언 풀을 소개해주세요',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: '플레이 스타일, 주로 하는 챔피언, 시간대 등을 자유롭게 작성해주세요',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAvailabilityToggle() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '용병 가능 여부',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isAvailable 
                      ? '현재 용병 참가가 가능한 상태입니다' 
                      : '현재 용병 참가가 불가능한 상태입니다',
                    style: TextStyle(
                      color: _isAvailable ? Colors.green : Colors.red,
                      fontSize: 13,
                    ),
                  ),
            ],
          ),
        ),
            Switch(
              value: _isAvailable,
              activeColor: AppColors.primary,
              onChanged: (value) {
                setState(() {
                  _isAvailable = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveMercenaryProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSaving
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 12),
                Text('저장 중...'),
              ],
            )
          : Text(_existingMercenary == null ? '용병 등록하기' : '정보 업데이트'),
      ),
    );
  }
} 