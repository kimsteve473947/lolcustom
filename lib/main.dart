import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lol_custom_game_manager/config/env_config.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/firebase_options.dart';
import 'package:lol_custom_game_manager/navigation/app_router.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/auth_service.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/services/cloud_functions_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

// Handle background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize environment variables
  try {
    await EnvConfig.init();
  } catch (e) {
    print('Warning: .env file not found or could not be loaded. Using default values.');
  }
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize FCM
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    
    // Request permission for iOS
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    print('Warning: Firebase initialization failed: $e');
    print('Make sure to follow the Firebase setup instructions in the README.md file.');
  }
  
  // Initialize Korean date formatting
  await initializeDateFormatting('ko_KR', null);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Create services
    final authService = AuthService();
    final firebaseService = FirebaseService();
    final cloudFunctionsService = CloudFunctionsService();
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppStateProvider(
            authService: authService,
            firebaseService: firebaseService,
            cloudFunctionsService: cloudFunctionsService,
          ),
        ),
      ],
      child: Consumer<AppStateProvider>(
        builder: (context, appState, _) {
          final router = AppRouter(authService: authService).router;
          
          return MaterialApp.router(
            title: EnvConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: router,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ko', 'KR'),
              Locale('en', 'US'),
            ],
            locale: const Locale('ko', 'KR'),
          );
        },
      ),
    );
  }
} 