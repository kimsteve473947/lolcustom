import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart' as CustomAuth;
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/widgets/calendar/user_calendar_widget.dart';
import 'package:lol_custom_game_manager/screens/my_page/tournaments_by_date_screen.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({Key? key}) : super(key: key);

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  @override
  void initState() {
    super.initState();
    // 화면이 처음 로드될 때 사용자 정보 동기화
    _syncUserData();
  }
  
  // 사용자 데이터 동기화 메서드
  Future<void> _syncUserData() async {
    final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
    try {
      await appStateProvider.syncCurrentUser();
      debugPrint('MyPageScreen - 사용자 데이터 동기화 완료');
    } catch (e) {
      debugPrint('MyPageScreen - 사용자 데이터 동기화 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<CustomAuth.AuthProvider>(context);
    final appStateProvider = Provider.of<AppStateProvider>(context);
    final isLoggedIn = authProvider.isLoggedIn;
    final user = authProvider.user;
    final currentUser = appStateProvider.currentUser;
    
    // 디버깅 정보 출력
    debugPrint('MyPageScreen - authProvider.user: ${user?.nickname} (${user?.uid})');
    debugPrint('MyPageScreen - appStateProvider.currentUser: ${currentUser?.nickname} (${currentUser?.uid})');
    
    String displayName = 'Unknown User';
    String userId = 'No ID';
    
    // 사용자 정보 소스 결정 (우선순위: authProvider > appStateProvider > 기본값)
    if (user != null) {
      displayName = '${user.nickname} (Auth)';
      userId = user.uid;
    } else if (currentUser != null) {
      displayName = '${currentUser.nickname} (State)';
      userId = currentUser.uid;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 정보'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('설정 페이지로 이동합니다')),
              );
            },
          ),
        ],
      ),
      body: isLoggedIn
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 사용자 프로필 정보
                _buildProfileSection(displayName, userId),
                
                const SizedBox(height: 24),
                const Divider(),
                
                // 캘린더 위젯 추가
                const SizedBox(height: 16),
                const Text(
                  '내 내전 일정',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                UserCalendarWidget(
                  onDateSelected: (selectedDate) {
                    // 선택한 날짜의 토너먼트 목록 페이지로 이동
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TournamentsByDateScreen(
                          selectedDate: selectedDate,
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                const Divider(),
                
                // 내 활동 섹션
                _buildActivitySection(),
                
                // 관리자 도구 섹션
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  '개발자 도구',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('관리자 도구'),
                  subtitle: const Text('개발자용 특수 기능'),
                  onTap: () {
                    context.push('/admin');
                  },
                  tileColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.sync_problem, color: Colors.orange),
                  title: const Text('사용자 데이터 초기화'),
                  subtitle: const Text('로그인 문제 해결을 위한 도구'),
                  onTap: () async {
                    // 데이터 초기화 확인 다이얼로그
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('사용자 데이터 초기화'),
                        content: const Text(
                          '현재 로그인 정보를 초기화합니다. 로그인이 제대로 되지 않는 경우에만 사용하세요. 계속하시겠습니까?'
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('초기화'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      final success = await appStateProvider.resetUserData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success 
                              ? '사용자 데이터가 초기화되었습니다. 다시 로그인해주세요.'
                              : '초기화 중 오류가 발생했습니다: ${appStateProvider.errorMessage}'),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                        
                        if (success) {
                          // 로그아웃 후 로그인 화면으로 이동
                          await authProvider.signOut();
                          if (context.mounted) {
                            context.go('/login');
                          }
                        }
                      }
                    }
                  },
                  tileColor: Colors.orange.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                
                // 로그아웃 버튼
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () async {
                    // 로그아웃 확인 다이얼로그
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('로그아웃'),
                        content: const Text('정말 로그아웃 하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('로그아웃'),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      await authProvider.signOut();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    }
                  },
                  icon: const Icon(Icons.exit_to_app, color: Colors.red),
                  label: const Text('로그아웃', style: TextStyle(color: Colors.red)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('로그인이 필요합니다'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('로그인하기'),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildProfileSection(String username, String userId) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundImage: AssetImage('assets/images/profile_placeholder.png'),
            ),
            const SizedBox(height: 16),
            Text(
              username,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              userId,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // 프로필 편집
              },
              child: const Text('프로필 편집'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          '내 활동',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('참여한 내전'),
          onTap: () {
            // 참여한 내전 목록으로 이동
          },
          tileColor: Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.event),
          title: const Text('내가 생성한 내전'),
          onTap: () {
            // 내가 생성한 내전 목록으로 이동
          },
          tileColor: Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }
} 