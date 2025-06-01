import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';

class MercenaryEditScreen extends StatefulWidget {
  const MercenaryEditScreen({Key? key}) : super(key: key);

  @override
  State<MercenaryEditScreen> createState() => _MercenaryEditScreenState();
}

class _MercenaryEditScreenState extends State<MercenaryEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _riotIdController = TextEditingController();
  
  String? _selectedTier;
  File? _profileImage;
  bool _isLoading = false;
  
  // 티어 목록
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

  // PlayerTier enum을 한글 티어 문자열로 변환하는 헬퍼 메소드
  String _tierToString(PlayerTier tier) {
    switch (tier) {
      case PlayerTier.unranked: return '언랭';
      case PlayerTier.iron: return '아이언';
      case PlayerTier.bronze: return '브론즈';
      case PlayerTier.silver: return '실버';
      case PlayerTier.gold: return '골드';
      case PlayerTier.platinum: return '플래티넘';
      case PlayerTier.diamond: return '다이아몬드';
      case PlayerTier.master: return '마스터';
      case PlayerTier.grandmaster: return '그랜드마스터';
      case PlayerTier.challenger: return '챌린저';
      default: return '언랭';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _riotIdController.dispose();
    super.dispose();
  }

  // 사용자 데이터 로드
  Future<void> _loadUserData() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final user = appState.currentUser;
    
    if (user != null) {
      setState(() {
        _nicknameController.text = user.nickname;
        _riotIdController.text = user.riotId ?? '';
        _selectedTier = _tierToString(user.tier);
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

  // 프로필 저장
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      
      String? profileImageUrl;
      
      // 이미지가 선택되었다면 업로드
      if (_profileImage != null) {
        final bytes = await _profileImage!.readAsBytes();
        final userId = appState.currentUser!.uid;
        final path = 'users/$userId/profile.jpg';
        
        profileImageUrl = await appState.firebaseService.uploadImage(
          path, 
          bytes,
        );
      }
      
      // 프로필 업데이트
      await appState.updateUserProfile(
        nickname: _nicknameController.text.trim(),
        riotId: _riotIdController.text.trim(),
        tier: _selectedTier,
        profileImageUrl: profileImageUrl,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 업데이트되었습니다')),
        );
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필 업데이트 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final user = appState.currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('로그인이 필요합니다'),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 수정'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 프로필 이미지
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: _profileImage != null 
                    ? FileImage(_profileImage!) 
                    : (user.profileImageUrl != null 
                        ? NetworkImage(user.profileImageUrl!) as ImageProvider
                        : null),
                  child: _profileImage == null && user.profileImageUrl == null
                    ? const Icon(
                        Icons.person,
                        size: 60,
                        color: AppColors.primary,
                      )
                    : null,
                ),
              ),
              TextButton(
                onPressed: _pickImage,
                child: const Text('이미지 변경'),
              ),
              const SizedBox(height: 24),
              
              // 닉네임 필드
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  labelText: '닉네임',
                  hintText: '게임에서 사용하는 닉네임',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '닉네임을 입력해주세요';
                  }
                  if (value.length < 2) {
                    return '닉네임은 최소 2자 이상이어야 합니다';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 라이엇 ID 필드
              TextFormField(
                controller: _riotIdController,
                decoration: const InputDecoration(
                  labelText: '라이엇 ID',
                  hintText: '예: 닉네임#KR1',
                  prefixIcon: Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: 16),
              
              // 티어 선택
              DropdownButtonFormField<String>(
                value: _selectedTier,
                decoration: const InputDecoration(
                  labelText: '티어',
                  prefixIcon: Icon(Icons.emoji_events_outlined),
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
              ),
              const SizedBox(height: 32),
              
              // 저장 버튼
              _isLoading
                ? const LoadingIndicator()
                : ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      '저장하기',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
} 