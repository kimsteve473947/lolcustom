import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:lol_custom_game_manager/services/user_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ClanMemberManagementScreen extends StatefulWidget {
  final String clanId;
  
  const ClanMemberManagementScreen({
    Key? key,
    required this.clanId,
  }) : super(key: key);

  @override
  State<ClanMemberManagementScreen> createState() => _ClanMemberManagementScreenState();
}

class _ClanMemberManagementScreenState extends State<ClanMemberManagementScreen> with SingleTickerProviderStateMixin {
  final ClanService _clanService = ClanService();
  final UserService _userService = UserService();
  
  bool _isLoading = true;
  ClanModel? _clan;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _pendingMembers = [];
  bool _isCurrentUserOwner = false;
  
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
        context.go('/auth/login');
        return;
      }
      
      // 클랜 정보 가져오기
      final clan = await _clanService.getClanById(widget.clanId);
      
      if (clan == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('클랜 정보를 찾을 수 없습니다')),
        );
        context.go('/clans');
        return;
      }
      
      // 클랜장인지 확인
      final isOwner = clan.ownerId == currentUser.uid;
      
      if (!isOwner) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('클랜 멤버 관리 권한이 없습니다')),
        );
        context.go('/clans/detail/${widget.clanId}');
        return;
      }
      
      // 멤버 정보 가져오기
      final List<Map<String, dynamic>> memberDataList = [];
      
      for (final memberId in clan.members) {
        final user = await _userService.getUserById(memberId);
        if (user != null) {
          memberDataList.add({
            'id': user.id,
            'name': user.displayName,
            'photoUrl': user.photoURL,
            'isOwner': memberId == clan.ownerId,
          });
        }
      }
      
      // 가입 신청자 정보 가져오기
      final List<Map<String, dynamic>> pendingMemberDataList = [];
      
      for (final memberId in clan.pendingMembers) {
        final user = await _userService.getUserById(memberId);
        if (user != null) {
          pendingMemberDataList.add({
            'id': user.id,
            'name': user.displayName,
            'photoUrl': user.photoURL,
          });
        }
      }
      
      setState(() {
        _clan = clan;
        _members = memberDataList;
        _pendingMembers = pendingMemberDataList;
        _isCurrentUserOwner = isOwner;
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
        title: const Text('멤버 관리'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '멤버'),
            Tab(text: '가입 신청'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMembersTab(),
          _buildPendingMembersTab(),
        ],
      ),
    );
  }
  
  Widget _buildMembersTab() {
    if (_members.isEmpty) {
      return const Center(
        child: Text('멤버가 없습니다'),
      );
    }
    
    return ListView.builder(
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: member['photoUrl'] != null
                ? NetworkImage(member['photoUrl'])
                : null,
            child: member['photoUrl'] == null
                ? const Icon(Icons.person)
                : null,
          ),
          title: Text(member['name'] ?? '이름 없음'),
          subtitle: member['isOwner'] ? const Text('클랜장') : null,
          trailing: !member['isOwner'] && _isCurrentUserOwner
              ? IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => _showRemoveMemberDialog(member),
                )
              : null,
        );
      },
    );
  }
  
  Widget _buildPendingMembersTab() {
    if (_pendingMembers.isEmpty) {
      return const Center(
        child: Text('가입 신청이 없습니다'),
      );
    }
    
    return ListView.builder(
      itemCount: _pendingMembers.length,
      itemBuilder: (context, index) {
        final member = _pendingMembers[index];
        
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: member['photoUrl'] != null
                ? NetworkImage(member['photoUrl'])
                : null,
            child: member['photoUrl'] == null
                ? const Icon(Icons.person)
                : null,
          ),
          title: Text(member['name'] ?? '이름 없음'),
          subtitle: const Text('가입 신청 중'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => _acceptMember(member['id']),
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () => _rejectMember(member['id']),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _showRemoveMemberDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('멤버 제거'),
        content: Text('${member['name']}님을 클랜에서 제거하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeMember(member['id']);
            },
            child: const Text('제거', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _removeMember(String memberId) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _clanService.removeMember(widget.clanId, memberId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('멤버가 제거되었습니다')),
      );
      
      _loadClanData(); // 멤버 목록 새로고침
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('멤버 제거 실패: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _acceptMember(String memberId) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _clanService.acceptMember(widget.clanId, memberId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가입 신청이 승인되었습니다')),
      );
      
      _loadClanData(); // 멤버 목록 새로고침
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('가입 승인 실패: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _rejectMember(String memberId) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _clanService.rejectMember(widget.clanId, memberId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가입 신청이 거부되었습니다')),
      );
      
      _loadClanData(); // 멤버 목록 새로고침
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('가입 거부 실패: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
} 