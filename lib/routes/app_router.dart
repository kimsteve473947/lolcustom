import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/screens/auth/login_screen.dart';
import 'package:lol_custom_game_manager/screens/home/home_screen.dart';
import 'package:lol_custom_game_manager/screens/auth/signup_screen.dart';
import 'package:lol_custom_game_manager/screens/auth/splash_screen.dart';
import 'package:lol_custom_game_manager/screens/profile/profile_screen.dart';
import 'package:lol_custom_game_manager/screens/chat/chat_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_basic_info_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_emblem_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_activity_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_preferences_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_focus_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_list_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_detail_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_join_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_manage_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_search_screen.dart';
import 'package:lol_custom_game_manager/screens/main_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_management_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/clan_member_management_screen.dart';
import 'package:lol_custom_game_manager/screens/clans/create_clan_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/chat/:chatId',
      builder: (context, state) => ChatScreen(
        chatId: state.pathParameters['chatId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/clans',
      builder: (context, state) => const ClanListScreen(),
      routes: [
        GoRoute(
          path: 'create',
          builder: (context, state) => const CreateClanScreen(),
        ),
        GoRoute(
          path: 'basic',
          builder: (context, state) => const ClanBasicInfoScreen(),
        ),
        GoRoute(
          path: 'emblem',
          builder: (context, state) => const ClanEmblemScreen(),
        ),
        GoRoute(
          path: 'activity',
          builder: (context, state) => const ClanActivityScreen(),
        ),
        GoRoute(
          path: 'preferences',
          builder: (context, state) => const ClanPreferencesScreen(),
        ),
        GoRoute(
          path: 'focus',
          builder: (context, state) => const ClanFocusScreen(),
        ),
        GoRoute(
          path: 'detail/:clanId',
          builder: (context, state) {
            final clanId = state.pathParameters['clanId']!;
            debugPrint('앱 라우터: 클랜 상세 화면으로 이동 - 클랜 ID: $clanId');
            return ClanDetailScreen(clanId: clanId);
          },
          routes: [
            GoRoute(
              path: 'manage',
              builder: (context, state) {
                final clanId = state.pathParameters['clanId']!;
                return ClanManagementScreen(clanId: clanId);
              },
            ),
          ],
        ),
        GoRoute(
          path: 'search',
          builder: (context, state) => const ClanSearchScreen(),
        ),
        GoRoute(
          path: 'join/:clanId',
          builder: (context, state) {
            final clanId = state.pathParameters['clanId']!;
            return ClanJoinScreen(clanId: clanId);
          },
        ),
        GoRoute(
          path: 'members/:clanId',
          builder: (context, state) {
            final clanId = state.pathParameters['clanId']!;
            return ClanMemberManagementScreen(clanId: clanId);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/applications',
      builder: (context, state) => const ClanListScreen(), // TODO: 신청 내역 화면 구현
    ),
  ],
); 