import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/screens/auth/login_screen.dart';
import 'package:lol_custom_game_manager/screens/auth/signup_screen.dart';
import 'package:lol_custom_game_manager/screens/chat/chat_list_screen.dart';
import 'package:lol_custom_game_manager/screens/chat/chat_room_screen.dart';
import 'package:lol_custom_game_manager/screens/main_screen.dart';
import 'package:lol_custom_game_manager/screens/mercenaries/mercenary_detail_screen.dart';
import 'package:lol_custom_game_manager/screens/mercenaries/mercenary_edit_screen.dart';
import 'package:lol_custom_game_manager/screens/my_page/my_page_screen.dart';
import 'package:lol_custom_game_manager/screens/rankings/rankings_screen.dart';
import 'package:lol_custom_game_manager/screens/splash_screen.dart';
import 'package:lol_custom_game_manager/screens/tournaments/tournament_create_screen.dart';
import 'package:lol_custom_game_manager/screens/tournaments/tournament_detail_screen.dart';
import 'package:lol_custom_game_manager/screens/tournaments/tournament_list_screen.dart';
import 'package:lol_custom_game_manager/services/auth_service.dart';

class AppRouter {
  final AuthService authService;
  
  AppRouter({required this.authService});
  
  late final router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges()),
    redirect: (context, state) {
      final isLoggedIn = authService.currentUser != null;
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
      
      // 인증이 필요한 페이지 목록
      final requiresAuth = !state.matchedLocation.startsWith('/login') && 
                          !state.matchedLocation.startsWith('/signup') &&
                          state.matchedLocation != '/';
                          
      // 로그인이 필요한 페이지에 접근했는데 로그인 안 되어 있으면 로그인 페이지로
      if (requiresAuth && !isLoggedIn) {
        return '/login?redirect=${state.location}';
      }
      
      // 이미 로그인되어 있는데 로그인/회원가입 페이지로 가려고 하면 메인 페이지로
      if (loggingIn && isLoggedIn) {
        return '/main';
      }
      
      // 그 외의 경우 정상 진행
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          redirectUrl: state.queryParameters['redirect'],
        ),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/main',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: '/tournaments',
        builder: (context, state) => const TournamentListScreen(),
      ),
      GoRoute(
        path: '/tournaments/create',
        builder: (context, state) => const TournamentCreateScreen(),
      ),
      GoRoute(
        path: '/tournaments/:id',
        builder: (context, state) {
          final tournamentId = state.pathParameters['id']!;
          return TournamentDetailScreen(tournamentId: tournamentId);
        },
      ),
      GoRoute(
        path: '/mercenaries/:id',
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return MercenaryDetailScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/mercenaries/edit',
        builder: (context, state) => const MercenaryEditScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final chatId = state.pathParameters['id']!;
          return ChatRoomScreen(chatId: chatId);
        },
      ),
      GoRoute(
        path: '/rankings',
        builder: (context, state) => const RankingsScreen(),
      ),
      GoRoute(
        path: '/mypage',
        builder: (context, state) => const MyPageScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('페이지를 찾을 수 없습니다'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('요청한 페이지를 찾을 수 없습니다.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/main'),
              child: const Text('메인으로 돌아가기'),
            ),
          ],
        ),
      ),
    ),
  );
}

// AuthService의 상태 변경을 감지하기 위한 리스너
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  
  late final StreamSubscription<dynamic> _subscription;
  
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
} 