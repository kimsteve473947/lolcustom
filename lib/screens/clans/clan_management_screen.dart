import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/constants/app_colors.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';

class ClanManagementScreen extends StatefulWidget {
  const ClanManagementScreen({Key? key}) : super(key: key);

  @override
  State<ClanManagementScreen> createState() => _ClanManagementScreenState();
}

class _ClanManagementScreenState extends State<ClanManagementScreen> {
  final ClanService _clanService = ClanService();
  ClanModel? _clan;
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _discordController = TextEditingController();
  
  bool _areMembersPublic = true;
  bool _isRecruiting = true;
  
  @override
  void initState() {
    super.initState();
    _loadClanData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _discordController.dispose();
    super.dispose();
  }
  
  Future<void> _loadClanData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
        context.go('/auth/login');
        return;
      }
      
      // 사용자의 클랜 정보 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용자 정보를 찾을 수 없습니다')),
        );
        context.go('/');
        return;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final clanId = userData['clanId'];
      
      if (clanId == null) {
        // 클랜이 없는 경우
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('소속된 클랜이 없습니다')),
        );
        context.go('/clans');
        return;
      }
      
      // 클랜 정보 가져오기
      final clan = await _clanService.getClanById(clanId);
      
      if (clan == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('클랜 정보를 찾을 수 없습니다')),
        );
        context.go('/clans');
        return;
      }
      
      // 클랜장인지 확인
      if (clan.ownerId != currentUser.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('클랜 관리 권한이 없습니다')),
        );
        context.go('/clans/detail/$clanId');
        return;
      }
      
      setState(() {
        _clan = clan;
        _nameController.text = clan.name;
        _descriptionController.text = clan.description ?? '';
        _discordController.text = clan.discordUrl ?? '';
        _areMembersPublic = clan.areMembersPublic;
        _isRecruiting = clan.isRecruiting;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _updateClan() async {
    if (_formKey.currentState!.validate() && _clan != null) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        // 업데이트할 클랜 데이터
        final Map<String, dynamic> updates = {
          'name': _nameController.text,
          'description': _descriptionController.text,
          'discordUrl': _discordController.text,
          'areMembersPublic': _areMembersPublic,
          'isRecruiting': _isRecruiting,
        };
        
        // 클랜 정보 업데이트
        await _clanService.updateClan(_clan!.id, updates);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('클랜 정보가 업데이트되었습니다')),
        );
        
        // 클랜 상세 페이지로 이동
        context.go('/clans/detail/${_clan!.id}');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('클랜 정보 업데이트 실패: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('클랜 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              context.push('/clans/members/${_clan!.id}');
            },
            tooltip: '멤버 관리',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 16.0),
              
              // 클랜 설명
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '클랜 설명',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16.0),
              
              // 디스코드
              TextFormField(
                controller: _discordController,
                decoration: const InputDecoration(
                  labelText: '디스코드 URL',
                  border: OutlineInputBorder(),
                  hintText: 'https://discord.gg/your-server',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24.0),
              
              // 멤버 공개 여부 및 모집 상태 설정
              SwitchListTile(
                title: const Text('멤버 공개 여부'),
                subtitle: const Text('다른 사용자들이 클랜원들을 참고할 수 있습니다.'),
                value: _areMembersPublic,
                onChanged: (value) {
                  setState(() {
                    _areMembersPublic = value;
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
              
              const SizedBox(height: 32.0),
              
              // 저장 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _updateClan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  child: const Text(
                    '변경사항 저장',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16.0),
              
              // 클랜 삭제 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _showDeleteConfirmationDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  child: const Text(
                    '클랜 삭제',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
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
  
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('클랜 삭제'),
        content: const Text(
          '정말로 클랜을 삭제하시겠습니까? 이 작업은 되돌릴 수 없으며, 모든 클랜 데이터가 영구적으로 삭제됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteClan();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _deleteClan() async {
    if (_clan == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _clanService.deleteClan(_clan!.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클랜이 삭제되었습니다')),
      );
      
      context.go('/clans');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('클랜 삭제 실패: $e')),
      );
      
      setState(() {
        _isLoading = false;
      });
    }
  }
} 