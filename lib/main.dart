import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lol_custom_game_manager/config/env_config.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/auth_service.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/services/cloud_functions_service.dart';
import 'package:lol_custom_game_manager/navigation/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await EnvConfig.init();
  
  // Web platform is not supported in this version
  if (kIsWeb) {
    runApp(const UnsupportedPlatformApp());
    return;
  }
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Firebase messaging only on non-web platforms
  // Web messaging requires service worker setup
  
  runApp(const MyApp());
}

class UnsupportedPlatformApp extends StatelessWidget {
  const UnsupportedPlatformApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoL 내전 매니저',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.web_asset_off, size: 64, color: Colors.red),
              SizedBox(height: 24),
              Text(
                '웹 버전은 아직 지원되지 않습니다',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                '모바일 앱을 다운로드하여 이용해주세요.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Services
  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();
  late final CloudFunctionsService _cloudFunctionsService;
  
  // Router
  late final AppRouter _appRouter;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize services with web compatibility
    _cloudFunctionsService = CloudFunctionsService();
    _appRouter = AppRouter(authService: _authService);
  }
  
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppStateProvider(
            authService: _authService,
            firebaseService: _firebaseService,
            cloudFunctionsService: _cloudFunctionsService,
          ),
        ),
      ],
      child: MaterialApp.router(
        title: EnvConfig.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: _appRouter.router,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ko', 'KR'),
          Locale('en', 'US'),
        ],
      ),
    );
  }
}

class SimpleHomeScreen extends StatelessWidget {
  const SimpleHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LoL 내전 매니저'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 24),
            const Text(
              '환영합니다!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '앱이 성공적으로 초기화되었습니다.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                // Add navigation logic later
              },
              child: const Text('시작하기'),
            ),
          ],
        ),
      ),
    );
  }
} 