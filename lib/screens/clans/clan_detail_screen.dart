import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ClanDetailScreen extends StatefulWidget {
  final String clanId;
  
  const ClanDetailScreen({
    Key? key,
    required this.clanId,
  }) : super(key: key);

  @override
  State<ClanDetailScreen> createState() => _ClanDetailScreenState();
}

class _ClanDetailScreenState extends State<ClanDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  ClanModel? _clan;
  final ClanService _clanService = ClanService();
  bool _isCurrentUserMember = false;
  bool _isCurrentUserOwner = false;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _activities = [];
  bool _hasPendingApplication = false;
  bool _isJoining = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    debugPrint('ClanDetailScreen initState - clanId: ${widget.clanId}');
    _loadClanDetails();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadClanDetails() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 클랜 상세 정보 로드
      debugPrint('클랜 정보 로드 시작: ${widget.clanId}');
      final clan = await _clanService.getClanById(widget.clanId);
      debugPrint('클랜 정보 로드 결과: ${clan != null ? '성공' : '실패'}');
      
      if (clan != null) {
        // 현재 사용자 정보 확인
        final currentUser = FirebaseAuth.instance.currentUser;
        bool isMember = false;
        bool isOwner = false;
        
        if (currentUser != null) {
          isMember = clan.members.contains(currentUser.uid);
          isOwner = clan.ownerId == currentUser.uid;
          debugPrint('현재 사용자 정보: ${currentUser.uid}, 멤버: $isMember, 소유자: $isOwner');
        }
        
        // 멤버 정보 로드
        final membersList = await _loadMemberDetails(clan.members);
        
        // 활동 내역 로드 (예시로 구현)
        final activitiesList = await _loadClanActivities(widget.clanId);
        
        if (mounted) {
          setState(() {
            _clan = clan;
            _isCurrentUserMember = isMember;
            _isCurrentUserOwner = isOwner;
            _members = membersList;
            _activities = activitiesList;
            _isLoading = false;
          });
        }
      } else {
        debugPrint('클랜 정보를 찾을 수 없음: ${widget.clanId}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('클랜 정보를 찾을 수 없습니다')),
          );
          setState(() {
            _isLoading = false;
          });
          // 3초 후 이전 화면으로 돌아가기
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              context.pop();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('클랜 정보 로드 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('클랜 정보 로드 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }
  
  // 멤버 정보 로드
  Future<List<Map<String, dynamic>>> _loadMemberDetails(List<String> memberIds) async {
    final List<Map<String, dynamic>> members = [];
    
    // 멤버 정보가 없는 경우 기본 10명의 멤버를 생성
    if (memberIds.isEmpty) {
      for (int i = 1; i <= 10; i++) {
        members.add({
          'id': 'member$i',
          'displayName': '멤버 $i',
          'photoURL': null,
          'rank': '일반 멤버',
          'joinedAt': DateTime.now().subtract(Duration(days: i)),
        });
      }
      return members;
    }
    
    // 실제 멤버 정보 로드
    try {
      for (final memberId in memberIds) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(memberId).get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          members.add({
            'id': memberId,
            'displayName': userData['displayName'] ?? '익명 사용자',
            'photoURL': userData['photoURL'],
            'rank': memberId == _clan?.ownerId ? '클랜장' : '일반 멤버',
            'joinedAt': userData['joinedAt'] ?? DateTime.now(),
          });
        }
      }
    } catch (e) {
      print('멤버 정보 로드 오류: $e');
    }
    
    // 멤버가 10명 미만이면 나머지를 더미 데이터로 채움
    if (members.length < 10) {
      final int additionalCount = 10 - members.length;
      for (int i = 1; i <= additionalCount; i++) {
        members.add({
          'id': 'dummyMember$i',
          'displayName': '신규 멤버 $i',
          'photoURL': null,
          'rank': '일반 멤버',
          'joinedAt': DateTime.now().subtract(Duration(days: i)),
        });
      }
    }
    
    return members;
  }
  
  // 클랜 활동 내역 로드 (예시 구현)
  Future<List<Map<String, dynamic>>> _loadClanActivities(String clanId) async {
    // 실제로는 Firestore에서 활동 내역을 가져오는 코드를 작성해야 함
    // 지금은 예시 데이터로 대체
    return [
      {
        'id': 'activity1',
        'type': 'member_joined',
        'title': '새 멤버가 가입했습니다',
        'description': '홍길동님이 클랜에 가입했습니다.',
        'timestamp': DateTime.now().subtract(const Duration(days: 2)),
      },
      {
        'id': 'activity2',
        'type': 'tournament',
        'title': '클랜 내부 토너먼트',
        'description': '주말 클랜 내부 토너먼트가 예정되어 있습니다.',
        'timestamp': DateTime.now().subtract(const Duration(days: 5)),
      },
      {
        'id': 'activity3',
        'type': 'clan_update',
        'title': '클랜 정보 업데이트',
        'description': '클랜 소개가 업데이트되었습니다.',
        'timestamp': DateTime.now().subtract(const Duration(days: 7)),
      },
    ];
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(),
                _buildMembersTab(),
                _buildActivitiesTab(),
              ],
            ),
      bottomNavigationBar: !_isCurrentUserMember && !_isLoading
          ? _buildJoinButton()
          : null,
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    final bool isOwner = _clan?.ownerId == FirebaseAuth.instance.currentUser?.uid;
    
    return AppBar(
      title: Text(_clan?.name ?? '클랜 정보'),
      actions: [
        if (isOwner)
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/clans/manage');
            },
            tooltip: '클랜 관리',
          ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: '정보'),
          Tab(text: '멤버'),
          Tab(text: '활동'),
        ],
      ),
    );
  }
  
  Widget _buildInfoTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 클랜 정보 섹션
          const Text(
            '클랜 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // 클랜 설명
          if (_clan?.description != null && _clan!.description!.isNotEmpty)
            ...[
              const Text(
                '소개',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(_clan!.description!),
              const SizedBox(height: 16),
            ],
          
          // 웹사이트
          if (_clan?.websiteUrl != null && _clan!.websiteUrl!.isNotEmpty)
            ...[
              const Text(
                '웹사이트',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () {
                  // 웹사이트 URL 열기 로직
                  launchUrl(Uri.parse(_clan!.websiteUrl!));
                },
                child: Text(
                  _clan!.websiteUrl!,
                  style: TextStyle(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          
          // 활동 정보 섹션
          const Text(
            '활동 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // 활동 요일
          if (_clan?.activityDays != null && _clan!.activityDays.isNotEmpty)
            ...[
              const Text(
                '활동 요일',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(_clan!.activityDays.join(', ')),
              const SizedBox(height: 16),
            ],
          
          // 활동 시간대
          if (_clan?.activityTimes != null && _clan!.activityTimes.isNotEmpty)
            ...[
              const Text(
                '활동 시간대',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(_getActivityTimesText(_clan!.activityTimes)),
              const SizedBox(height: 16),
            ],
          
          // 선호 연령대
          if (_clan?.ageGroups != null && _clan!.ageGroups.isNotEmpty)
            ...[
              const Text(
                '선호 연령대',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(_getAgeGroupsText(_clan!.ageGroups)),
              const SizedBox(height: 16),
            ],
          
          // 클랜 성향
          ...[
            const Text(
              '클랜 성향',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(_getFocusText(_clan?.focus)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_clan?.focusRating ?? 5) / 10,
                      minHeight: 10,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _clan?.focusRating != null && _clan!.focusRating > 5
                            ? Colors.red
                            : _clan?.focusRating != null && _clan!.focusRating < 5
                                ? Colors.green
                                : Colors.blue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          
          // 생성일
          if (_clan?.createdAt != null)
            ...[
              const Text(
                '생성일',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(DateFormat('yyyy년 MM월 dd일').format(_clan!.createdAt.toDate())),
              const SizedBox(height: 16),
            ],
          
          // 가입 신청 버튼
          if (!_isCurrentUserMember && !_isCurrentUserOwner && !_hasPendingApplication)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isJoining ? null : _applyToClan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isJoining
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        '가입 신청',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          
          // 가입 신청 중인 경우
          if (_hasPendingApplication)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '가입 신청 중',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('클랜 관리자의 승인을 기다리고 있습니다.'),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildClanEmblem(ClanModel clan) {
    if (clan.emblem != null) {
      if (clan.emblem is String) {
        // URL 형태의 엠블럼
        return CachedNetworkImage(
          imageUrl: clan.emblem as String,
          imageBuilder: (context, imageProvider) => CircleAvatar(
            radius: 40,
            backgroundImage: imageProvider,
          ),
          placeholder: (context, url) => const CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary,
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.groups, size: 40, color: Colors.white),
          ),
        );
      } else if (clan.emblem is Map) {
        // 맵 형태의 엠블럼 (색상 정보 등)
        final emblem = clan.emblem as Map;
        Color backgroundColor = AppColors.primary;
        
        if (emblem.containsKey('backgroundColor') && emblem['backgroundColor'] is Color) {
          backgroundColor = emblem['backgroundColor'] as Color;
        }
        
        return CircleAvatar(
          radius: 40,
          backgroundColor: backgroundColor,
          child: Icon(
            Icons.groups,
            size: 40,
            color: Colors.white,
          ),
        );
      }
    }
    
    // 기본 엠블럼
    return CircleAvatar(
      radius: 40,
      backgroundColor: AppColors.primary,
      child: Icon(Icons.groups, size: 40, color: Colors.white),
    );
  }
  
  String _getActivityTimesText(List<PlayTimeType> activityTimes) {
    if (activityTimes.isEmpty) return '미지정';
    
    final List<String> timeTexts = activityTimes.map((time) {
      switch (time) {
        case PlayTimeType.morning:
          return '아침';
        case PlayTimeType.daytime:
          return '낮';
        case PlayTimeType.evening:
          return '저녁';
        case PlayTimeType.night:
          return '밤';
        default:
          return '';
      }
    }).toList();
    
    return timeTexts.join(', ');
  }
  
  String _getAgeGroupsText(List<AgeGroup> ageGroups) {
    if (ageGroups.isEmpty) return '제한 없음';
    
    final List<String> ageTexts = ageGroups.map((age) {
      switch (age) {
        case AgeGroup.teens:
          return '10대';
        case AgeGroup.twenties:
          return '20대';
        case AgeGroup.thirties:
          return '30대';
        case AgeGroup.fortyPlus:
          return '40대 이상';
        default:
          return '';
      }
    }).toList();
    
    return ageTexts.join(', ');
  }
  
  String _getGenderPreferenceText(GenderPreference preference) {
    switch (preference) {
      case GenderPreference.male:
        return '남성';
      case GenderPreference.female:
        return '여성';
      case GenderPreference.any:
        return '제한 없음';
      default:
        return '제한 없음';
    }
  }
  
  String _getFocusText(ClanFocus? focus) {
    if (focus == null) return '밸런스';
    
    String focusText = '';
    
    switch (focus) {
      case ClanFocus.casual:
        focusText = '캐주얼';
        break;
      case ClanFocus.balanced:
        focusText = '밸런스';
        break;
      case ClanFocus.competitive:
        focusText = '경쟁';
        break;
      default:
        focusText = '밸런스';
    }
    
    return focusText;
  }
  
  Widget _buildMembersTab() {
    if (_members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '아직 등록된 멤버가 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _members.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final member = _members[index];
        final dateFormat = DateFormat('yyyy.MM.dd');
        final joinedAtText = member['joinedAt'] is DateTime 
            ? dateFormat.format(member['joinedAt'])
            : '정보 없음';
            
        return ListTile(
          leading: member['photoURL'] != null
              ? CircleAvatar(
                  backgroundImage: NetworkImage(member['photoURL']),
                )
              : CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.8),
                  child: Text(
                    member['displayName'][0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
          title: Text(member['displayName']),
          subtitle: Text('가입일: $joinedAtText'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: member['rank'] == '클랜장' 
                  ? AppColors.primary.withOpacity(0.2)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              member['rank'],
              style: TextStyle(
                color: member['rank'] == '클랜장' 
                    ? AppColors.primary
                    : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          onTap: () {
            // 멤버 상세 정보 페이지로 이동 (미구현)
          },
        );
      },
    );
  }
  
  Widget _buildActivitiesTab() {
    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '아직 활동 내역이 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        final activity = _activities[index];
        final dateFormat = DateFormat('yyyy.MM.dd');
        final timestampText = activity['timestamp'] is DateTime 
            ? dateFormat.format(activity['timestamp'])
            : '';
            
        IconData activityIcon;
        Color activityColor;
        
        switch (activity['type']) {
          case 'member_joined':
            activityIcon = Icons.person_add;
            activityColor = Colors.green;
            break;
          case 'tournament':
            activityIcon = Icons.emoji_events;
            activityColor = Colors.amber;
            break;
          case 'clan_update':
            activityIcon = Icons.update;
            activityColor = Colors.blue;
            break;
          default:
            activityIcon = Icons.info;
            activityColor = Colors.grey;
        }
            
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(activityIcon, color: activityColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activity['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      timestampText,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (activity['description'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 32),
                    child: Text(
                      activity['description'],
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildJoinButton() {
    if (_clan == null) return const SizedBox.shrink();
    
    final isRecruiting = _clan!.isRecruiting;
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: isRecruiting ? _applyToClan : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          disabledBackgroundColor: Colors.grey.shade400,
        ),
        child: Text(
          isRecruiting ? '클랜 가입 신청하기' : '현재 모집 중단 상태',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
  
  Future<void> _applyToClan() async {
    setState(() {
      _isJoining = true;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }
      
      await _clanService.applyToClan(_clan!.id, user.uid);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클랜 가입 신청이 완료되었습니다')),
      );
      
      // 상태 업데이트
      setState(() {
        _hasPendingApplication = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('가입 신청 실패: $e')),
      );
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }
} 