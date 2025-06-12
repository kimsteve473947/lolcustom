import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/models/clan_application_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart' as CustomAuth;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClanManageScreen extends StatefulWidget {
  final String clanId;
  
  const ClanManageScreen({
    Key? key,
    required this.clanId,
  }) : super(key: key);

  @override
  State<ClanManageScreen> createState() => _ClanManageScreenState();
}

class _ClanManageScreenState extends State<ClanManageScreen> with SingleTickerProviderStateMixin {
  final ClanService _clanService = ClanService();
  bool _isLoading = true;
  bool _isOwner = false;
  ClanModel? _clan;
  List<Map<String, dynamic>> _members = [];
  
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadClanData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadClanData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 클랜 정보 로드
      final clan = await _clanService.getClan(widget.clanId);
      
      // 현재 사용자가 클랜장인지 확인
      bool isOwner = false;
      if (clan != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          isOwner = clan.ownerId == user.uid;
          
          // 멤버 정보 로드
          final members = await _clanService.getClanMembers(clan.id);
          
          if (mounted) {
            setState(() {
              _members = members;
            });
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _clan = clan;
          _isOwner = isOwner;
          _isLoading = false;
        });
        
        // 클랜장이 아니면 접근 거부
        if (!_isOwner) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('클랜 관리 페이지는 클랜장만 접근할 수 있습니다')),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('클랜 정보를 불러오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_clan?.name ?? '클랜 관리'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '가입 신청'),
            Tab(text: '멤버'),
            Tab(text: '클랜 정보'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _clan == null
              ? const Center(child: Text('클랜 정보를 찾을 수 없습니다'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildApplicationsTab(),
                    _buildMembersTab(),
                    _buildClanInfoTab(),
                  ],
                ),
    );
  }
  
  Widget _buildApplicationsTab() {
    return StreamBuilder<List<ClanApplicationModel>>(
      stream: _clanService.getClanApplications(_clan!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('오류가 발생했습니다: ${snapshot.error}'),
          );
        }
        
        final applications = snapshot.data ?? [];
        
        if (applications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  '가입 신청이 없습니다',
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
          itemCount: applications.length,
          itemBuilder: (context, index) {
            return _buildApplicationItem(applications[index]);
          },
        );
      },
    );
  }
  
  Widget _buildApplicationItem(ClanApplicationModel application) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: application.userProfileImageUrl != null
                      ? NetworkImage(application.userProfileImageUrl!)
                      : null,
                  child: application.userProfileImageUrl == null
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '신청일: ${_formatDate(application.appliedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 추가 정보 (있는 경우)
            if (application.position != null && application.position!.isNotEmpty)
              _buildInfoItem('포지션', application.position!),
              
            if (application.experience != null && application.experience!.isNotEmpty)
              _buildInfoItem('경험/경력', application.experience!),
              
            if (application.contactInfo != null && application.contactInfo!.isNotEmpty)
              _buildInfoItem('연락처', application.contactInfo!),
            
            const SizedBox(height: 8),
            
            // 신청 메시지
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '신청 메시지',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    application.message ?? '(메시지 없음)',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 수락/거절 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _processApplication(
                    application.id,
                    ClanApplicationStatus.rejected,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    '거절',
                    style: TextStyle(color: Colors.red[600]),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _processApplication(
                    application.id,
                    ClanApplicationStatus.accepted,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '수락',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _processApplication(String applicationId, ClanApplicationStatus status) async {
    try {
      await _clanService.processClanApplication(
        applicationId: applicationId,
        newStatus: status,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == ClanApplicationStatus.accepted
                  ? '가입 신청이 승인되었습니다'
                  : '가입 신청이 거절되었습니다',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }
  
  Widget _buildMembersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final isOwner = member['isOwner'] == true;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[200],
              backgroundImage: member['photoURL'] != null
                  ? NetworkImage(member['photoURL'])
                  : null,
              child: member['photoURL'] == null
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            title: Text(
              member['displayName'] ?? '이름 없음',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              isOwner ? '클랜장' : '클랜원',
              style: TextStyle(
                color: isOwner ? Colors.amber[700] : Colors.grey[600],
              ),
            ),
            trailing: isOwner
                ? null
                : IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      // 팝업 메뉴 표시
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (context) {
                          return SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.admin_panel_settings),
                                  title: const Text('클랜장 권한 이전'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showTransferOwnershipDialog(member);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.person_remove, color: Colors.red),
                                  title: const Text('멤버 제거'),
                                  textColor: Colors.red,
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showRemoveMemberDialog(member);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
  
  void _showTransferOwnershipDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('클랜장 권한 이전'),
          content: Text('정말로 ${member['displayName']}에게 클랜장 권한을 이전하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: 클랜장 권한 이전 기능 구현
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('클랜장 권한 이전 기능은 준비 중입니다')),
                );
              },
              child: const Text('이전'),
            ),
          ],
        );
      },
    );
  }
  
  void _showRemoveMemberDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('멤버 제거'),
          content: Text('정말로 ${member['displayName']}을(를) 클랜에서 제거하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: 멤버 제거 기능 구현
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('멤버 제거 기능은 준비 중입니다')),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('제거'),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildClanInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
                  _buildInfoRow('클랜 이름', _clan!.name),
                  _buildInfoRow('생성일', _formatDate(_clan!.createdAt)),
                  _buildInfoRow('멤버 수', '${_clan!.memberCount}/${_clan!.maxMembers}명'),
                  if (_clan!.description != null)
                    _buildInfoRow('설명', _clan!.description!),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '모집 설정',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('멤버 모집'),
                    subtitle: const Text('활성화하면 다른 사용자가 클랜에 가입 신청을 할 수 있습니다'),
                    value: _clan!.isRecruiting,
                    onChanged: (value) {
                      // TODO: 모집 상태 변경 기능 구현
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('모집 상태 변경 기능은 준비 중입니다')),
                      );
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('공개 클랜'),
                    subtitle: const Text('활성화하면 모든 사용자가 클랜 정보를 볼 수 있습니다'),
                    value: _clan!.isPublic,
                    onChanged: (value) {
                      // TODO: 공개 상태 변경 기능 구현
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('공개 상태 변경 기능은 준비 중입니다')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.push('/clans/${_clan!.id}/edit');
              },
              icon: const Icon(Icons.edit),
              label: const Text('클랜 정보 수정'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일';
  }
} 