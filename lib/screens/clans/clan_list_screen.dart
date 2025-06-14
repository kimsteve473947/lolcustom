import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/models/clan_application_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart' as CustomAuth;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClanListScreen extends StatefulWidget {
  const ClanListScreen({Key? key}) : super(key: key);

  @override
  State<ClanListScreen> createState() => _ClanListScreenState();
}

class _ClanListScreenState extends State<ClanListScreen> {
  final ClanService _clanService = ClanService();
  ClanModel? _userClan;
  bool _isLoading = true;
  bool _isUserClanOwner = false;
  
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _loadUserClan();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = GoRouter.of(context);
    final uri = route.routeInformationProvider.value.uri;
    if (uri.queryParameters['refresh'] == 'true') {
      _loadUserClan();
    }
  }
  
  Future<void> _loadUserClan() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 현재 사용자의 클랜 정보 가져오기
      final clan = await _clanService.getCurrentUserClan();
      
      // 현재 사용자가 클랜장인지 확인
      bool isOwner = false;
      if (clan != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          isOwner = clan.ownerId == user.uid;
        }
      }
      
      if (mounted) {
        setState(() {
          _userClan = clan;
          _isUserClanOwner = isOwner;
          _isLoading = false;
        });
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
    final authProvider = Provider.of<CustomAuth.AuthProvider>(context);
    final isLoggedIn = authProvider.isLoggedIn;
    
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserClan,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroSection(),
                        
                        // 내 클랜 정보 (클랜이 있는 경우)
                        if (_userClan != null)
                          _buildUserClanSection(_userClan!, _isUserClanOwner),
                          
                        _buildRecruitingClansSection(),
                        _buildClanTournamentsSection(),
                        
                        // 로그인한 경우에만 신청 내역 표시
                        if (isLoggedIn)
                          _buildApplicationHistorySection(),
                          
                        const SizedBox(height: 80), // Bottom padding for safe area
                      ],
                    ),
                  ),
                  if (_userClan == null && authProvider.isLoggedIn)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: () {
                          context.push('/clans/create');
                        },
                        backgroundColor: Colors.orange,
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildHeroSection() {
    return Stack(
      children: [
        // Background with gradient
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.7),
              ],
            ),
          ),
          // Dark overlay for better text visibility
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.5),
                ],
              ),
            ),
          ),
        ),
        
        // App bar elements
        Positioned(
          top: 40,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '팀',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    // 임시 데이터 초기화 버튼
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () async {
                        await _clanService.removeAllClanDataFromUsers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('모든 유저의 클랜 데이터가 초기화되었습니다.')),
                        );
                        _loadUserClan(); // UI 새로고침
                      },
                      tooltip: '모든 유저 클랜 데이터 삭제',
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: () {
                        context.push('/clans/search');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('알림 기능은 준비 중입니다')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Hero content
        Positioned(
          bottom: 40,
          left: 24,
          right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _userClan != null
                    ? _isUserClanOwner
                        ? '내 클랜을 관리해보세요'
                        : '클랜 활동을 즐겨보세요'
                    : '우리 팀의 역사가 시작돼요',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              if (_userClan == null)
                ElevatedButton(
                  onPressed: () {
                    // 팀 생성의 첫 화면으로 이동 (기본 정보 입력 화면)
                    context.push('/clans/create');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(150, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    '클랜 만들기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildUserClanSection(ClanModel clan, bool isOwner) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '내 클랜',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isOwner)
                TextButton(
                  onPressed: () {
                    context.push('/clan/${clan.id}/manage');
                  },
                  child: const Text('관리하기'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              debugPrint('클랜 상세 페이지로 이동: ${clan.id}');
              context.push('/clans/${clan.id}');
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildClanEmblem(clan),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clan.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '멤버: ${clan.memberCount}/${clan.maxMembers}명',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOwner ? Colors.amber.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isOwner ? '클랜장' : '클랜원',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOwner ? Colors.amber[800] : Colors.blue[800],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '멤버 ${clan.memberCount}/${clan.maxMembers}명',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildClanEmblem(ClanModel clan) {
    if (clan.emblem is String && (clan.emblem as String).startsWith('http')) {
      // 이미지 URL인 경우
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: NetworkImage(clan.emblem as String),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else if (clan.emblem is Map) {
      // 기본 엠블럼인 경우
      final emblem = clan.emblem as Map;
      final Color backgroundColor = emblem['backgroundColor'] as Color? ?? AppColors.primary;
      final String symbol = emblem['symbol'] as String? ?? 'sports_soccer';
      
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            _getIconData(symbol),
            color: Colors.white,
            size: 30,
          ),
        ),
      );
    } else {
      // 기본 아이콘
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.groups,
            color: Colors.white,
            size: 30,
          ),
        ),
      );
    }
  }
  
  Widget _buildRecruitingClansSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              '멤버 모집중',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            child: StreamBuilder<List<ClanModel>>(
              stream: _clanService.getClans(onlyRecruiting: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('오류가 발생했습니다: ${snapshot.error}'),
                  );
                }
                
                final clans = snapshot.data ?? [];
                
                if (clans.isEmpty) {
                  return Center(
                    child: Text(
                      '현재 모집중인 클랜이 없습니다',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  );
                }
                
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: clans.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    return _buildClanCard(clans[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClanCard(ClanModel clan) {
    final authProvider = Provider.of<CustomAuth.AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    final isMember = currentUser != null && clan.members.contains(currentUser.uid);

    return GestureDetector(
      onTap: () {
        if (isMember) {
          context.push('/clans/${clan.id}');
        } else {
          context.push('/clans/public/${clan.id}');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            _buildClanEmblem(clan),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                clan.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '멤버: ${clan.memberCount}/${clan.maxMembers}명',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFocusBadge(clan.focus),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${clan.memberCount}/${clan.maxMembers}명',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '클랜 가입',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFocusBadge(ClanFocus focus) {
    Color color;
    String label;
    
    switch (focus) {
      case ClanFocus.casual:
        color = Colors.green;
        label = '친목';
        break;
      case ClanFocus.competitive:
        color = Colors.red;
        label = '실력';
        break;
      case ClanFocus.balanced:
        color = Colors.blue;
        label = '균형';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildClanTournamentsSection() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '팀 활동',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildActivityCard('클랜 토너먼트', Icons.emoji_events, Colors.green)),
              const SizedBox(width: 16),
              Expanded(child: _buildActivityCard('게스트 모집', Icons.person_add, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildActivityCard('클랜가입', Icons.group_add, Colors.purple)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        if (title == '클랜가입') {
          context.push('/clans/recruitment-list');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title 기능은 준비 중입니다')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationHistorySection() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '클랜신청 내역',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
        onPressed: () {
                  context.push('/applications');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<ClanApplicationModel>>(
            stream: _clanService.getUserApplications(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Text('오류가 발생했습니다: ${snapshot.error}'),
                );
              }
              
              final applications = snapshot.data ?? [];
              
              if (applications.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '아직 가입 신청 내역이 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '클랜에 가입 신청을 하면 여기에 표시됩니다',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              // 최근 3개의 신청 내역만 표시
              final recentApplications = applications.length > 3 
                  ? applications.sublist(0, 3) 
                  : applications;
              
              return Column(
                children: recentApplications.map((application) {
                  return _buildApplicationItem(application);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildApplicationItem(ClanApplicationModel application) {
    Color statusColor;
    String statusText;
    
    switch (application.status) {
      case ClanApplicationStatus.pending:
        statusColor = Colors.amber;
        statusText = '검토중';
        break;
      case ClanApplicationStatus.accepted:
        statusColor = Colors.green;
        statusText = '승인됨';
        break;
      case ClanApplicationStatus.rejected:
        statusColor = Colors.red;
        statusText = '거절됨';
        break;
      case ClanApplicationStatus.cancelled:
        statusColor = Colors.grey;
        statusText = '취소됨';
        break;
    }
    
    return FutureBuilder<ClanModel?>(
      future: _clanService.getClan(application.clanId),
      builder: (context, snapshot) {
        final clan = snapshot.data;
        
        return InkWell(
          onTap: () {
            if (application.status == ClanApplicationStatus.pending) {
              _showCancelApplicationDialog(application);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                if (clan != null)
                  _buildClanEmblem(clan)
                else
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.sports_soccer,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clan?.name ?? '불러오는 중...',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (application.status == ClanApplicationStatus.pending)
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.touch_app, color: Colors.grey, size: 20),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  void _showCancelApplicationDialog(ClanApplicationModel application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('신청 취소'),
        content: Text('[${application.userName}] 클랜에 보낸 가입 신청을 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _clanService.cancelClanApplication(application.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('클랜 가입 신청이 취소되었습니다.')),
                );
              } catch (e) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('신청 취소 중 오류가 발생했습니다: $e')),
                );
              }
            },
            child: const Text('신청 취소', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year}/${date.month}/${date.day}';
  }
  
  IconData _getIconData(String symbol) {
    final Map<String, IconData> iconMap = {
      'shield': Icons.shield,
      'star': Icons.star,
      'sports_soccer': Icons.sports_soccer,
      'sports_basketball': Icons.sports_basketball,
      'sports_baseball': Icons.sports_baseball,
      'sports_football': Icons.sports_football,
      'sports_volleyball': Icons.sports_volleyball,
      'sports_tennis': Icons.sports_tennis,
      'whatshot': Icons.whatshot,
      'bolt': Icons.bolt,
      'pets': Icons.pets,
      'favorite': Icons.favorite,
      'stars': Icons.stars,
      'military_tech': Icons.military_tech,
      'emoji_events': Icons.emoji_events,
      'local_fire_department': Icons.local_fire_department,
      'public': Icons.public,
      'cruelty_free': Icons.cruelty_free,
      'emoji_nature': Icons.emoji_nature,
      'rocket_launch': Icons.rocket_launch,
    };
    
    return iconMap[symbol] ?? Icons.star;
  }
}