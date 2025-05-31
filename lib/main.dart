import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/firebase_options.dart';
import 'package:lol_custom_game_manager/navigation/app_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/auth_service.dart';
import 'package:lol_custom_game_manager/services/cloud_functions_service.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/services/firebase_messaging_service.dart';
import 'package:lol_custom_game_manager/services/tournament_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Firebase background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Handling a background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Initialize Firebase Messaging Service
    final messagingService = FirebaseMessagingService();
    await messagingService.initialize();
    
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize Firebase: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Services
    final authService = AuthService();
    final firebaseService = FirebaseService();
    final cloudFunctionsService = CloudFunctionsService();
    final tournamentService = TournamentService();
    final messagingService = FirebaseMessagingService();
    
    // Create router
    final appRouter = AppRouter(authService: authService);
    
    return MultiProvider(
      providers: [
        // Auth provider
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authService: authService),
        ),
        
        // App state provider
        ChangeNotifierProvider<AppStateProvider>(
          create: (_) => AppStateProvider(
            authService: authService,
            firebaseService: firebaseService,
            cloudFunctionsService: cloudFunctionsService,
          ),
        ),
        
        // Service providers
        Provider<AuthService>(create: (_) => authService),
        Provider<FirebaseService>(create: (_) => firebaseService),
        Provider<CloudFunctionsService>(create: (_) => cloudFunctionsService),
        Provider<TournamentService>(create: (_) => tournamentService),
        Provider<FirebaseMessagingService>(create: (_) => messagingService),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp.router(
            title: 'LoL 내전 매니저',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            debugShowCheckedModeBanner: false,
            routerConfig: appRouter.router,
          );
        },
      ),
    );
  }
} 