import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/screens/auth/login_screen.dart';
import 'package:lol_custom_game_manager/screens/auth/register_screen.dart';
import 'package:lol_custom_game_manager/screens/chat/chat_list_screen.dart';
import 'package:lol_custom_game_manager/screens/chat/chat_room_screen.dart';
import 'package:lol_custom_game_manager/screens/main/main_screen.dart';
import 'package:lol_custom_game_manager/screens/mercenaries/mercenary_detail_screen.dart';
import 'package:lol_custom_game_manager/screens/my_page/my_page_screen.dart';
import 'package:lol_custom_game_manager/screens/rankings/rankings_screen.dart';
import 'package:lol_custom_game_manager/screens/splash_screen.dart';
import 'package:lol_custom_game_manager/screens/tournaments/create_tournament_screen.dart';
import 'package:lol_custom_game_manager/screens/tournaments/tournament_detail_screen.dart';
import 'package:lol_custom_game_manager/services/auth_service.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

class AppRouter {
  final AuthService authService;

  AppRouter({AuthService? authService}) : authService = authService ?? AuthService();

  late final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      // Splash screen
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      
      // Main shell route with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainScreen(child: child),
        routes: [
          // Tournament list (Tab 1)
          GoRoute(
            path: '/tournaments',
            builder: (context, state) => const MainScreen(initialIndex: 0),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreateTournamentScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => TournamentDetailScreen(
                  tournamentId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          
          // Mercenaries (Tab 2)
          GoRoute(
            path: '/mercenaries',
            builder: (context, state) => const MainScreen(initialIndex: 1),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => MercenaryDetailScreen(
                  mercenaryId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          
          // Chat (Tab 3)
          GoRoute(
            path: '/chat',
            builder: (context, state) => const MainScreen(initialIndex: 2),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => ChatRoomScreen(
                  chatRoomId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          
          // Rankings (Tab 4)
          GoRoute(
            path: '/rankings',
            builder: (context, state) => const MainScreen(initialIndex: 3),
          ),
          
          // My Page (Tab 5)
          GoRoute(
            path: '/mypage',
            builder: (context, state) => const MainScreen(initialIndex: 4),
          ),
        ],
      ),
    ],
    
    // Redirect logic
    redirect: (context, state) {
      final isLoggedIn = authService.isLoggedIn;
      final isOnLoginPage = state.matchedLocation == '/login';
      final isOnRegisterPage = state.matchedLocation == '/register';
      final isOnSplashPage = state.matchedLocation == '/';
      
      // If not logged in and not on auth pages, go to login
      if (!isLoggedIn && !isOnLoginPage && !isOnRegisterPage && !isOnSplashPage) {
        return '/login';
      }
      
      // If logged in and on auth pages, go to home
      if (isLoggedIn && (isOnLoginPage || isOnRegisterPage)) {
        return '/tournaments';
      }
      
      // No redirect needed
      return null;
    },
    
    // Error handling
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '404',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Page not found'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/tournaments'),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    ),
  );
} 