import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/firebase_options.dart';
import 'package:lol_custom_game_manager/navigation/app_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart' as CustomAuth;
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/auth_service.dart';
import 'package:lol_custom_game_manager/services/cloud_functions_service.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/services/firebase_messaging_service.dart';
import 'package:lol_custom_game_manager/services/tournament_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/services/background_service.dart';
import 'package:lol_custom_game_manager/providers/chat_provider.dart';
import 'package:lol_custom_game_manager/providers/clan_creation_provider.dart';

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
  
  // 날짜 형식 로케일 데이터 초기화
  await initializeDateFormatting();
  
  try {
    debugPrint('Initializing Firebase with options: ${DefaultFirebaseOptions.currentPlatform}');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // 인증 서비스 초기화 확인
    final auth = FirebaseAuth.instance;
    await auth.authStateChanges().first;
    debugPrint('Firebase Auth initialized successfully');
    
    // 로그인 사용자 상태 확인 및 필요시 데이터 수정
    await _checkAndFixUserData();
    
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // iOS 권한 먼저 요청
    if (Platform.isIOS) {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('iOS notification permission: ${settings.authorizationStatus}');
    }
    
    // Initialize Firebase Messaging Service
    final messagingService = FirebaseMessagingService();
    try {
      await messagingService.initialize();
    } catch (e) {
      debugPrint('Warning: Firebase Messaging initialization error: $e');
      // Messaging 초기화 실패해도 앱은 계속 실행
    }
    
    // 백그라운드 서비스 시작
    BackgroundService().startCleanupService();
    
    debugPrint('Firebase initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('Failed to initialize Firebase: $e');
    debugPrint('Stack trace: $stackTrace');
    // 오류 로깅을 추가하거나 사용자에게 알림을 표시할 수 있습니다.
  }
  
  runApp(const MyApp());
}

// 사용자 로그인 데이터 검증 및 수정
Future<void> _checkAndFixUserData() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('No user logged in, skipping user data check');
      return;
    }
    
    // 사용자 정보 강제 새로고침
    await user.reload();
    debugPrint('Reloaded user: ${user.email} (${user.uid})');
    
    // Firestore 문서 확인
    final firestore = FirebaseFirestore.instance;
    final doc = await firestore.collection('users').doc(user.uid).get();
    
    if (!doc.exists) {
      debugPrint('User document does not exist for uid: ${user.uid}, creating new document');
      // 문서가 없는 경우 새로 생성
      await firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? '',
        'nickname': user.displayName ?? 'User${user.uid.substring(0, 4)}',
        'joinedAt': Timestamp.now(),
        'lastActiveAt': Timestamp.now(),
        'credits': 0,
        'isPremium': false,
        'isVerified': user.emailVerified,
        'signInProviders': ['password'],
      });
    } else {
      final data = doc.data() as Map<String, dynamic>;
      final nickname = data['nickname'] as String?;
      debugPrint('User document exists with nickname: $nickname');
      
      // 닉네임이 비어있거나 문제가 있는 경우 업데이트
      if (nickname == null || nickname.isEmpty) {
        debugPrint('User nickname is missing, updating...');
        await firestore.collection('users').doc(user.uid).update({
          'nickname': user.displayName ?? 'User${user.uid.substring(0, 4)}',
          'lastActiveAt': Timestamp.now(),
        });
      } else {
        // 마지막 활동 시간 업데이트
        await firestore.collection('users').doc(user.uid).update({
          'lastActiveAt': Timestamp.now(),
          'email': user.email ?? '', // 이메일 동기화
        });
      }
    }
    
    // Firebase Auth와 Firestore 데이터 동기화 확인
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final firestoreNickname = userData['nickname'] as String?;
        
        // Firebase Auth와 Firestore의 닉네임이 다른 경우 동기화
        if (firestoreNickname != user.displayName) {
          debugPrint('Nickname mismatch between Auth (${user.displayName}) and Firestore ($firestoreNickname). Synchronizing...');
          await firestore.collection('users').doc(user.uid).update({
            'nickname': user.displayName,
          });
        }
      }
    }
  } catch (e) {
    debugPrint('Error checking/fixing user data: $e');
  }
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
        ChangeNotifierProvider<CustomAuth.AuthProvider>(
          create: (_) => CustomAuth.AuthProvider(authService: authService),
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
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(
          create: (_) => ClanCreationProvider(),
        ),
      ],
      child: Builder(
        builder: (context) {
          // 두 프로바이더 간의 상태 동기화 설정
          _setupProviderSynchronization(context);
          
          return MaterialApp.router(
            title: '스크림져드',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            debugShowCheckedModeBanner: false,
            routerConfig: appRouter.router,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', 'US'),
              Locale('ko', 'KR'),
            ],
          );
        },
      ),
    );
  }

  void _setupProviderSynchronization(BuildContext context) {
    // AuthProvider와 AppStateProvider 참조
    final authProvider = Provider.of<CustomAuth.AuthProvider>(context, listen: false);
    final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
    
    // AuthProvider 변경 감지 후 AppStateProvider 동기화
    authProvider.addListener(() async {
      debugPrint('MyApp - AuthProvider 상태 변경 감지. 로그인 상태: ${authProvider.isLoggedIn}');
      
      // 현재 사용자가 변경되었거나 로그아웃 상태가 변경된 경우
      final authUser = authProvider.user;
      final appUser = appStateProvider.currentUser;
      
      // 사용자 ID가 다르거나 로그인/로그아웃 상태가 변경된 경우 동기화
      if (authUser?.uid != appUser?.uid) {
        debugPrint('MyApp - 사용자 ID 불일치 감지: AuthProvider(${authUser?.uid}) vs AppStateProvider(${appUser?.uid})');
        
        if (authProvider.isLoggedIn) {
          // 로그인 상태면 AppStateProvider 사용자 정보 갱신
          debugPrint('MyApp - AppStateProvider 사용자 정보 동기화 시작');
          await appStateProvider.syncCurrentUser();
        } else if (appUser != null) {
          // 로그아웃 상태인데 AppStateProvider에 사용자 정보가 남아있으면 명시적으로 초기화
          debugPrint('MyApp - 로그아웃 상태에서 AppStateProvider 초기화 시작');
          await appStateProvider.signOut();
        }
      }
    });
  }
}
