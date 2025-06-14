import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/user_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _picker = ImagePicker();

  late TextEditingController _nicknameController;
  late TextEditingController _statusMessageController;
  String? _profileImageUrl;
  File? _imageFile;

  bool _isLoading = false;
  bool _isUploading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppStateProvider>(context, listen: false).currentUser;
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _statusMessageController = TextEditingController(text: user?.statusMessage ?? '');
    _profileImageUrl = user?.profileImageUrl;
    
    // Add listeners to detect changes
    _nicknameController.addListener(_checkChanges);
    _statusMessageController.addListener(_checkChanges);
  }

  @override
  void dispose() {
    _nicknameController.removeListener(_checkChanges);
    _statusMessageController.removeListener(_checkChanges);
    _nicknameController.dispose();
    _statusMessageController.dispose();
    super.dispose();
  }

  void _checkChanges() {
    final user = Provider.of<AppStateProvider>(context, listen: false).currentUser;
    final hasTextChanges = 
        _nicknameController.text != user?.nickname ||
        _statusMessageController.text != user?.statusMessage;
    final hasImageChanges = _imageFile != null;
    
    if (hasTextChanges || hasImageChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasTextChanges || hasImageChanges;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        final currentUser = appState.currentUser;
        if (currentUser == null) return;

        await _userService.updateUserProfile(
          uid: currentUser.uid,
          nickname: _nicknameController.text,
          statusMessage: _statusMessageController.text,
          profileImageUrl: _profileImageUrl,
        );

        // Refresh user data
        await appState.syncCurrentUser();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('프로필이 성공적으로 업데이트되었습니다.'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('프로필 업데이트 실패: $e'),
              backgroundColor: AppColors.error,
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

  Future<void> _pickImage() async {
    // Show bottom sheet with camera and gallery options
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '프로필 사진 선택',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.camera_alt, color: Colors.white),
                  ),
                  title: const Text('카메라로 촬영'),
                  onTap: () {
                    Navigator.pop(context);
                    _getImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.photo_library, color: Colors.white),
                  ),
                  title: const Text('갤러리에서 선택'),
                  onTap: () {
                    Navigator.pop(context);
                    _getImage(ImageSource.gallery);
                  },
                ),
                if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.error,
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    title: const Text('프로필 사진 삭제'),
                    onTap: () {
                      Navigator.pop(context);
                      _removeProfileImage();
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isUploading = true;
        _hasChanges = true;
      });

      try {
        final uid = Provider.of<AppStateProvider>(context, listen: false).currentUser!.uid;
        final downloadUrl = await _userService.uploadProfileImage(uid: uid, imageFile: _imageFile!);
        setState(() {
          _profileImageUrl = downloadUrl;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('이미지 업로드 실패: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  void _removeProfileImage() {
    setState(() {
      _imageFile = null;
      _profileImageUrl = '';
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppStateProvider>(context).currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('사용자 정보를 불러올 수 없습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 수정'),
        elevation: 0,
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: Text(
                '저장',
                style: TextStyle(
                  color: _isLoading ? Colors.grey : AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading ? 
        const Center(child: LoadingIndicator()) :
        _buildProfileForm(user),
    );
  }

  Widget _buildProfileForm(UserModel user) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile Image Section
          _buildProfileImageSection(),
          const SizedBox(height: 32),

          // Personal Info Section
          _buildSectionHeader('기본 정보'),
          const SizedBox(height: 16),
          
          // Nickname
          _buildTextField(
            controller: _nicknameController,
            label: '닉네임',
            hint: '게임에서 사용할 닉네임을 입력하세요',
            prefixIcon: Icons.person,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '닉네임을 입력해주세요.';
              }
              if (value.length < 2) {
                return '닉네임은 2자 이상이어야 합니다.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Status Message
          _buildTextField(
            controller: _statusMessageController,
            label: '상태 메시지',
            hint: '상태 메시지를 입력하세요 (선택사항)',
            prefixIcon: Icons.chat_bubble_outline,
            maxLines: 3,
          ),
          
          const SizedBox(height: 32),
          
          // Game Info Section
          _buildSectionHeader('게임 정보'),
          const SizedBox(height: 16),
          
          // Tier Info (Read-only)
          _buildInfoTile(
            icon: Icons.emoji_events,
            title: '티어',
            value: UserModel.tierToString(user.tier),
            onTap: () {
              // Could navigate to tier selection screen
            },
          ),
          
          // Preferred Positions (Read-only)
          _buildInfoTile(
            icon: Icons.sports_esports,
            title: '선호 포지션',
            value: user.preferredPositions != null && user.preferredPositions!.isNotEmpty
                ? user.preferredPositions!.join(', ')
                : '설정되지 않음',
            onTap: () {
              // Could navigate to position selection screen
            },
          ),
          
          const SizedBox(height: 32),
          
          // Account Info Section
          _buildSectionHeader('계정 정보'),
          const SizedBox(height: 16),
          
          // Email (Read-only)
          _buildInfoTile(
            icon: Icons.email_outlined,
            title: '이메일',
            value: user.email,
            isEditable: false,
          ),
          
          // Join Date (Read-only)
          _buildInfoTile(
            icon: Icons.calendar_today,
            title: '가입일',
            value: '${user.joinedAt.toDate().year}년 ${user.joinedAt.toDate().month}월 ${user.joinedAt.toDate().day}일',
            isEditable: false,
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isUploading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                      )
                    : ClipOval(
                        child: _imageFile != null
                            ? Image.file(_imageFile!, fit: BoxFit.cover)
                            : _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                ? Image.network(
                                    _profileImageUrl!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                              : null,
                                          color: AppColors.primary,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.grey,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                  ),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploading ? null : _pickImage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '프로필 사진',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '터치하여 사진을 변경하세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.grey[300],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    bool isEditable = true,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        trailing: isEditable
            ? const Icon(Icons.chevron_right, color: AppColors.primary)
            : null,
        onTap: isEditable ? onTap : null,
      ),
    );
  }
}