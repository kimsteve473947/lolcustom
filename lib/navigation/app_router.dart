import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/screens/auth/login_screen.dart';
import 'package:lol_custom_game_manager/screens/auth/signup_screen.dart';
import 'package:lol_custom_game_manager/screens/chat/chat_list_screen.dart';
import 'package:lol_custom_game_manager/screens/chat/chat_room_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_detail_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_list_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/create_clan_screen.dart';
import 'package:lol_custom_game_manager/screens/main_screen.dart';
import 'package:lol_custom_game_manager/screens/mercenaries/mercenary_detail_screen.dart';
import 'package:lol_custom_game_manager/screens/mercenaries/mercenary_edit_screen.dart';
import 'package:lol_custom_game_manager/screens/my_page/my_page_screen.dart';
import 'package:lol_custom_game_manager/screens/rankings/rankings_screen.dart';
import 'package:lol_custom_game_manager/screens/settings/fcm_test_screen.dart';
import 'package:lol_custom_game_manager/screens/splash_screen.dart';
import 'package:lol_custom_game_manager/screens/tournaments/tournament_detail_screen.dart';
import 'package:lol_custom_game_manager/screens/tournaments/tournament_main_screen.dart';
import 'package:lol_custom_game_manager/screens/tournaments/create_tournament_screen.dart';
import 'package:lol_custom_game_manager/services/auth_service.dart';
import 'package:lol_custom_game_manager/widgets/admin_tools.dart';

class AppRouter {
  final AuthService authService;
  
  AppRouter({required this.authService});
  
  late final router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges()),
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = authService.isLoggedIn;
      final isInitializing = state.uri.path == '/';
      final isLoggingIn = state.uri.path == '/login';
      final isSigningUp = state.uri.path == '/signup';
      final isPasswordReset = state.uri.path == '/password-reset';
      
      // 인증이 필요하지 않은 경로 목록
      final publicPaths = [
        '/',
        '/login',
        '/signup',
        '/password-reset',
      ];
      
      // 초기화 중일 때는 리다이렉트하지 않음
      if (isInitializing) {
        return null;
      }
      
      // 로그인한 사용자가 로그인/회원가입 페이지에 접근하면 메인으로 리다이렉트
      if (isLoggedIn && (isLoggingIn || isSigningUp || isPasswordReset)) {
        return '/main';
      }
      
      // 로그인하지 않은 사용자가 보호된 경로에 접근하면 로그인 페이지로 리다이렉트
      if (!isLoggedIn && !publicPaths.contains(state.uri.path)) {
        return '/login?redirect=${state.uri.path}';
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
          redirectUrl: state.uri.queryParameters['redirect'],
        ),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: '/main',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: '/tournaments',
        builder: (context, state) => const MainScreen(
          initialTabIndex: 0,
        ),
      ),
      GoRoute(
        path: '/tournaments/create',
        builder: (context, state) => const CreateTournamentScreen(),
      ),
      GoRoute(
        path: '/tournaments/:id',
        builder: (context, state) {
          final tournamentId = state.pathParameters['id']!;
          return TournamentDetailScreen(
            tournamentId: tournamentId,
          );
        },
      ),
      GoRoute(
        path: '/mercenaries/:id',
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return MainScreen(
            child: MercenaryDetailScreen(mercenaryId: userId),
          );
        },
      ),
      GoRoute(
        path: '/mercenaries/edit',
        builder: (context, state) => MainScreen(
          child: const MercenaryEditScreen(),
        ),
      ),
      GoRoute(
        path: '/clans',
        builder: (context, state) => const MainScreen(
          initialTabIndex: 1,
        ),
      ),
      GoRoute(
        path: '/clans/create',
        builder: (context, state) => MainScreen(
          child: const CreateClanScreen(),
        ),
      ),
      GoRoute(
        path: '/clans/:id',
        builder: (context, state) {
          final clanId = state.pathParameters['id']!;
          return MainScreen(
            child: ClanDetailScreen(clanId: clanId),
          );
        },
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const MainScreen(
          initialTabIndex: 2,
        ),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final chatId = state.pathParameters['id']!;
          return MainScreen(
            child: ChatRoomScreen(chatRoomId: chatId),
          );
        },
      ),
      GoRoute(
        path: '/rankings',
        builder: (context, state) => const MainScreen(
          initialTabIndex: 3,
        ),
      ),
      GoRoute(
        path: '/mypage',
        builder: (context, state) => const MainScreen(
          initialTabIndex: 4,
        ),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => MainScreen(
          child: const AdminToolsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/fcm-test',
        builder: (context, state) => const FCMTestScreen(),
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
  final StreamSubscription<dynamic> _subscription;
  
  GoRouterRefreshStream(Stream<dynamic> stream) 
      : _subscription = stream.asBroadcastStream().listen((dynamic _) {
          // 최신 버전의 go_router에서는 ChangeNotifier를 사용하지 않으므로 여기서 notifyListeners()를 직접 호출하지 않음
        });
  
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
} 