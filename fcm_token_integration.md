# FCM 토큰 서비스 통합 가이드

## 1. 서비스 등록
`main.dart` 파일에 새로운 FCM 토큰 서비스를 등록해야 합니다:

```dart
// main.dart에 import 추가
import 'package:lol_custom_game_manager/services/fcm_token_service.dart';

// MyApp 클래스 내부에 서비스 인스턴스 생성
final fcmTokenService = FcmTokenService();

// MultiProvider에 서비스 추가
return MultiProvider(
  providers: [
    // 기존 프로바이더들...
    
    // FCM 토큰 서비스 추가
    Provider<FcmTokenService>(create: (_) => fcmTokenService),
  ],
  child: Builder(
    // ...
  ),
);
```

## 2. 초기화 코드 추가
`main()` 함수 내에서 Firebase 초기화 후 FCM 토큰 서비스를 초기화합니다:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 날짜 형식 로케일 데이터 초기화
  await initializeDateFormatting();
  
  try {
    // Firebase 초기화...
    
    // FCM 토큰 서비스 초기화
    final fcmTokenService = FcmTokenService();
    await fcmTokenService.saveToken();
    fcmTokenService.setupTokenRefreshListener();
    
    debugPrint('Firebase initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('Failed to initialize Firebase: $e');
    debugPrint('Stack trace: $stackTrace');
  }
  
  runApp(const MyApp());
}
```

## 3. 로그인/로그아웃 처리
사용자 로그인 성공 시 토큰을 저장하고, 로그아웃 시 토큰을 삭제하도록 AuthService를 수정합니다:

```dart
// auth_service.dart 파일 수정

// import 추가
import 'package:lol_custom_game_manager/services/fcm_token_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FcmTokenService _fcmTokenService = FcmTokenService();
  
  // 로그인 메서드 수정
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // 로그인 성공 시 FCM 토큰 저장
      await _fcmTokenService.saveToken();
      
      return result.user;
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
  }
  
  // 로그아웃 메서드 수정
  Future<void> signOut() async {
    try {
      // 로그아웃 전 FCM 토큰 삭제
      await _fcmTokenService.deleteAllTokens();
      
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }
}
```

## 4. 토픽 구독 활용
특정 토너먼트에 참가할 때 해당 토너먼트의 토픽을 구독하도록 구현할 수 있습니다:

```dart
// tournament_service.dart 파일 예시

// 토너먼트 참가 시 토픽 구독
Future<void> joinTournament(String tournamentId, String role) async {
  try {
    await _firebaseService.joinTournamentByRole(tournamentId, role);
    
    // 토너먼트 토픽 구독
    await _fcmTokenService.subscribeToTopic('tournament_$tournamentId');
  } catch (e) {
    debugPrint('Error joining tournament: $e');
    rethrow;
  }
}

// 토너먼트 탈퇴 시 토픽 구독 해제
Future<void> leaveTournament(String tournamentId, String role) async {
  try {
    await _firebaseService.leaveTournamentByRole(tournamentId, role);
    
    // 토너먼트 토픽 구독 해제
    await _fcmTokenService.unsubscribeFromTopic('tournament_$tournamentId');
  } catch (e) {
    debugPrint('Error leaving tournament: $e');
    rethrow;
  }
}
```

## 구현 시 주의사항
1. 사용자가 로그인하지 않은 상태에서 토큰을 저장하지 않도록 주의합니다.
2. 토큰 갱신 시 자동으로 Firestore에 업데이트되도록 합니다.
3. 로그아웃 시 반드시 토큰을 삭제하여 불필요한 알림이 전송되지 않도록 합니다. 