import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/clan_creation_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';

class ClanBasicInfoScreen extends StatefulWidget {
  const ClanBasicInfoScreen({Key? key}) : super(key: key);

  @override
  State<ClanBasicInfoScreen> createState() => _ClanBasicInfoScreenState();
}

class _ClanBasicInfoScreenState extends State<ClanBasicInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();
  
  bool _isPublic = true;
  bool _isRecruiting = true;
  bool _isLoading = false;
  String? _errorMessage;
  
  final ClanService _clanService = ClanService();
  
  @override
  void initState() {
    super.initState();
    // 이전 단계에서 데이터가 있는지 확인
    try {
      final provider = Provider.of<ClanCreationProvider>(context, listen: false);
      _nameController.text = provider.name.isNotEmpty ? provider.name : '';
      _descriptionController.text = provider.description.isNotEmpty ? provider.description : '';
      _websiteController.text = provider.websiteUrl ?? '';
      _isPublic = provider.isPublic;
      _isRecruiting = provider.isRecruiting;
    } catch (e) {
      debugPrint('Provider 데이터 로드 실패: $e');
    }
  }
  
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
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildForm(),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
  
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '클랜 기본 정보',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '클랜의 기본 정보를 입력해주세요. 클랜 이름은 변경할 수 없으니 신중하게 결정해주세요.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 클랜 이름 입력 필드
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: '클랜 이름 *',
              hintText: '최대 20자까지 입력 가능합니다',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.groups),
            ),
            maxLength: 20,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '클랜 이름을 입력해주세요';
              }
              if (value.trim().length < 2) {
                return '클랜 이름은 최소 2자 이상이어야 합니다';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // 클랜 설명 입력 필드
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: '클랜 설명 *',
              hintText: '클랜에 대한 간단한 설명을 입력해주세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.description),
            ),
            maxLength: 200,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '클랜 설명을 입력해주세요';
              }
              if (value.trim().length < 10) {
                return '클랜 설명은 최소 10자 이상이어야 합니다';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // 웹사이트 입력 필드 (선택사항)
          TextFormField(
            controller: _websiteController,
            decoration: InputDecoration(
              labelText: '웹사이트 URL (선택사항)',
              hintText: '예: https://example.com',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.link),
            ),
            maxLength: 100,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final urlPattern = RegExp(
                  r'^(https?:\/\/)?(www\.)?[a-zA-Z0-9]+([\-\.]{1}[a-zA-Z0-9]+)*\.[a-zA-Z]{2,}(:[0-9]{1,5})?(\/.*)?$',
                );
                if (!urlPattern.hasMatch(value.trim())) {
                  return '올바른 URL 형식을 입력해주세요';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          // 공개 여부 설정
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '클랜 공개 설정',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('클랜 공개 여부'),
                    subtitle: Text(
                      _isPublic
                          ? '모든 사용자가 검색을 통해 클랜을 찾을 수 있습니다'
                          : '초대를 통해서만 클랜에 가입할 수 있습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    value: _isPublic,
                    onChanged: (value) {
                      setState(() {
                        _isPublic = value;
                      });
                    },
                    secondary: Icon(
                      _isPublic ? Icons.public : Icons.lock,
                      color: _isPublic ? Colors.green : Colors.orange,
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('멤버 모집 여부'),
                    subtitle: Text(
                      _isRecruiting
                          ? '새로운 멤버를 모집 중입니다'
                          : '현재 멤버 모집을 중단했습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    value: _isRecruiting,
                    onChanged: (value) {
                      setState(() {
                        _isRecruiting = value;
                      });
                    },
                    secondary: Icon(
                      _isRecruiting ? Icons.person_add : Icons.person_off,
                      color: _isRecruiting ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _createClan,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('다음'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _createClan() async {
    // 폼 검증
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }
      
      // Provider에 데이터 저장
      final provider = Provider.of<ClanCreationProvider>(context, listen: false);
      provider.setName(_nameController.text.trim());
      provider.setDescription(_descriptionController.text.trim());
      provider.setWebsiteUrl(_websiteController.text.trim());
      provider.setIsPublic(_isPublic);
      provider.setIsRecruiting(_isRecruiting);
      
      // 다음 화면으로 이동
      if (!mounted) return;
      context.push('/clans/emblem');
    } catch (e) {
      setState(() {
        _errorMessage = '클랜 생성 중 오류가 발생했습니다: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 