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
import 'package:lol_custom_game_manager/screens/clans/clan_creation_flow_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_public_profile_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_management_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_recruitment_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_recruitment_list_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_search_screen.dart';
import 'package:lol_custom_game_manager/providers/clan_recruitment_provider.dart';
import 'package:lol_custom_game_manager/screens/main_screen.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/screens/mercenaries/mercenary_detail_screen.dart';
import 'package:lol_custom_game_manager/screens/mercenaries/mercenary_edit_screen.dart';
import 'package:lol_custom_game_manager/screens/mercenaries/mercenary_list_screen.dart';
import 'package:lol_custom_game_manager/screens/my_page/my_page_screen.dart';
import 'package:lol_custom_game_manager/screens/my_page/edit_profile_screen.dart';
import 'package:lol_custom_game_manager/screens/rankings/rankings_screen.dart';
import 'package:lol_custom_game_manager/screens/settings/fcm_test_screen.dart';
import 'package:lol_custom_game_manager/screens/splash_screen.dart';
import 'package:lol_custom_game_manager/screens/my_page/credit_charge_screen.dart';
import 'package:lol_custom_game_manager/screens/tournaments/tournament_detail_screen.dart';
import 'package:lol_custom_game_manager/screens/tournaments/tournament_main_screen.dart';
import 'package:lol_custom_game_manager/screens/tournaments/create_tournament_screen.dart';
import 'package:lol_custom_game_manager/services/auth_service.dart';
import 'package:lol_custom_game_manager/widgets/admin_tools.dart';
import 'package:lol_custom_game_manager/screens/profile/user_profile_screen.dart';
import 'package:lol_custom_game_manager/screens/evaluation/evaluation_screen.dart';
import 'package:lol_custom_game_manager/screens/my_page/participant_trust_detail_screen.dart';

class AppRouter {
  final AuthService authService;
  
  AppRouter({required this.authService});
  
  final _rootNavigatorKey = GlobalKey<NavigatorState>();
  
  late final router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    navigatorKey: _rootNavigatorKey,
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges()),
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = authService.isLoggedIn;
      final loggingIn = state.uri.path == '/login' || state.uri.path == '/signup';

      // 사용자가 로그인하지 않았고, 로그인/회원가입 페이지가 아니며, 스플래시 페이지도 아니라면 로그인 페이지로 리디렉션합니다.
      if (!isLoggedIn && !loggingIn && state.uri.path != '/') {
        return '/login?redirect=${state.uri.path}';
      }

      // 사용자가 로그인했고, 로그인/회원가입 페이지에 있다면 메인 페이지로 리디렉션합니다.
      if (isLoggedIn && loggingIn) {
        return '/main';
      }

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
        path: '/main',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: '/tournaments/create',
        builder: (context, state) => const CreateTournamentScreen(),
      ),
      GoRoute(
        path: '/tournaments/:id',
        builder: (context, state) {
          final tournamentId = state.pathParameters['id']!;
          return TournamentDetailScreen(tournamentId: tournamentId);
        },
      ),
      GoRoute(
        path: '/mercenaries/register',
        builder: (context, state) {
          return const MercenaryEditScreen();
        },
      ),
      GoRoute(
        path: '/mercenaries/edit/:id',
        builder: (context, state) {
          final mercenaryId = state.pathParameters['id']!;
          return MercenaryEditScreen(mercenaryId: mercenaryId);
        },
      ),
      GoRoute(
        path: '/mercenaries/:id',
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return MainScreen(child: MercenaryDetailScreen(mercenaryId: userId));
        },
      ),
      GoRoute(
        path: '/clans',
        builder: (context, state) => const MainScreen(initialTabIndex: 1),
      ),
      GoRoute(
        path: '/clans/create',
        builder: (context, state) => const ClanCreationFlowScreen(),
      ),
      GoRoute(
        path: '/clans/recruit',
        builder: (context, state) {
          return ChangeNotifierProvider(
            create: (_) => ClanRecruitmentProvider(),
            child: const ClanRecruitmentScreen(),
          );
        },
      ),
      GoRoute(
        path: '/clans/recruitment-list',
        builder: (context, state) => const ClanRecruitmentListScreen(),
      ),
      GoRoute(
        path: '/clans/search',
        builder: (context, state) => const ClanSearchScreen(),
      ),
      GoRoute(
        path: '/clans/:id',
        builder: (context, state) {
          final clanId = state.pathParameters['id']!;
          return ClanDetailScreen(clanId: clanId);
        },
      ),
      GoRoute(
        path: '/clans/public/:id',
        builder: (context, state) {
          final clanId = state.pathParameters['id']!;
          return ClanPublicProfileScreen(clanId: clanId);
        },
      ),
      GoRoute(
        path: '/clans/:id/manage',
        builder: (context, state) {
          final clanId = state.pathParameters['id']!;
          return ClanManagementScreen(clanId: clanId);
        },
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const MainScreen(initialTabIndex: 2),
      ),
      GoRoute(
        path: '/chat/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final chatId = state.pathParameters['id']!;
          return NoTransitionPage(child: ChatRoomScreen(chatRoomId: chatId));
        },
      ),
      GoRoute(
        path: '/rankings',
        builder: (context, state) => const MainScreen(initialTabIndex: 3),
      ),
      GoRoute(
        path: '/mypage',
        builder: (context, state) => const MainScreen(initialTabIndex: 4),
        routes: [
          GoRoute(
            path: 'edit-profile',
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: 'credit-charge',
            builder: (context, state) => const CreditChargeScreen(),
          ),
          GoRoute(
            path: 'participant-trust',
            builder: (context, state) => const ParticipantTrustDetailScreen(),
          ),
        ]
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => MainScreen(child: const AdminToolsScreen()),
      ),
      GoRoute(
        path: '/settings/fcm-test',
        builder: (context, state) => const FCMTestScreen(),
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return UserProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/evaluation/:tournamentId',
        builder: (context, state) {
          final tournamentId = state.pathParameters['tournamentId']!;
          final isHost = state.uri.queryParameters['isHost'] == 'true';
          return EvaluationScreen(
            tournamentId: tournamentId,
            isHost: isHost,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('페이지를 찾을 수 없습니다')),
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

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;
  
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}