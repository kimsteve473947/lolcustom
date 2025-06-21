# 스크림져드 프로젝트 개발 규칙

## 📋 목차
1. [프로젝트 개요](#프로젝트-개요)
2. [아키텍처 규칙](#아키텍처-규칙)
3. [UI/UX 디자인 규칙](#uiux-디자인-규칙)
4. [코딩 컨벤션](#코딩-컨벤션)
5. [Firebase 및 백엔드 규칙](#firebase-및-백엔드-규칙)
6. [상태 관리 규칙](#상태-관리-규칙)
7. [파일 구조 규칙](#파일-구조-규칙)
8. [테스트 및 배포 규칙](#테스트-및-배포-규칙)
9. [보안 규칙](#보안-규칙)
10. [성능 최적화 규칙](#성능-최적화-규칙)

---

## 🎯 프로젝트 개요

**스크림져드**는 League of Legends 내전(Custom Game) 매니저 앱으로, Flutter와 Firebase를 기반으로 구축된 크로스플랫폼 애플리케이션입니다.

### 핵심 기능
- 내전 생성 및 관리
- 용병 시스템 및 평가
- 실시간 채팅 시스템
- Discord 자동 채널 생성
- 신뢰도 점수 시스템
- FCM 푸시 알림

---

## 🏗️ 아키텍처 규칙

### 1. 전체 아키텍처 패턴
```
UI Layer (Screens/Widgets)
    ↓
Provider Layer (State Management)
    ↓
Service Layer (Business Logic)
    ↓
Firebase Layer (Backend)
```

### 2. 레이어별 책임
- **UI Layer**: 사용자 인터페이스만 담당, 비즈니스 로직 금지
- **Provider Layer**: 상태 관리 및 UI-Service 간 중재
- **Service Layer**: 비즈니스 로직 및 외부 API 통신
- **Firebase Layer**: 데이터 저장소 및 백엔드 서비스

### 3. 의존성 주입 원칙
```dart
// ✅ 올바른 방법
class AppStateProvider {
  final AuthService _authService;
  final FirebaseService _firebaseService;
  
  AppStateProvider({
    AuthService? authService,
    FirebaseService? firebaseService,
  }) : _authService = authService ?? AuthService(),
       _firebaseService = firebaseService ?? FirebaseService();
}

// ❌ 잘못된 방법
class AppStateProvider {
  final _authService = AuthService(); // 하드코딩된 의존성
}
```

---

## 🎨 UI/UX 디자인 규칙

### 1. 디자인 시스템 - 토스 스타일 적용

#### 메인 컬러 팔레트
```dart
// 메인 컬러 (jud.gg 오렌지 유지)
static const Color primary = Color(0xFFFF6B35);
static const Color primaryLight = Color(0xFFFF9068);
static const Color primaryDark = Color(0xFFE85A2C);

// 배경 색상 (토스 스타일)
static const Color background = Color(0xFFFAFAFA);
static const Color backgroundCard = Color(0xFFFFFFFF);
```

#### 텍스트 색상 계층
```dart
static const Color textPrimary = Color(0xFF191919);   // 주요 텍스트
static const Color textSecondary = Color(0xFF8B8B8B); // 보조 텍스트
static const Color textTertiary = Color(0xFFB8B8B8);  // 3차 텍스트
static const Color textDisabled = Color(0xFFD4D4D4);  // 비활성 텍스트
```

### 2. 컴포넌트 디자인 규칙

#### 버튼 스타일
```dart
// 주요 버튼 (Primary)
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.white,
    elevation: 0, // 토스 스타일: 그림자 최소화
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12), // 부드러운 모서리
    ),
  ),
)

// 보조 버튼 (Secondary)
OutlinedButton(
  style: OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    side: BorderSide(color: AppColors.border),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
)
```

#### 카드 디자인
```dart
Card(
  elevation: 0, // 토스 스타일: 그림자 대신 테두리 사용
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(color: AppColors.border, width: 1),
  ),
)
```

### 3. 토스 스타일 UI 원칙
- **미니멀 디자인**: 불필요한 요소 제거, 깔끔한 인터페이스
- **그림자 최소화**: elevation: 0 사용, 테두리로 구분
- **부드러운 모서리**: BorderRadius.circular(12-16) 사용
- **충분한 여백**: 16px 기본 패딩, 24px 큰 여백
- **계층적 텍스트**: Primary/Secondary/Tertiary 색상 구분

### 4. 반응형 디자인
```dart
// 화면 크기별 대응
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isTablet = screenWidth > 600;
  
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: isTablet ? 24 : 16,
      vertical: 16,
    ),
  );
}
```

---

## 💻 코딩 컨벤션

### 1. 파일 명명 규칙
```
lib/
├── screens/
│   └── feature_name_screen.dart     // 화면: snake_case + _screen
├── widgets/
│   └── component_name_widget.dart   // 위젯: snake_case + _widget
├── models/
│   └── entity_name_model.dart       // 모델: snake_case + _model
├── services/
│   └── service_name_service.dart    // 서비스: snake_case + _service
└── providers/
    └── state_name_provider.dart     // 프로바이더: snake_case + _provider
```

### 2. 클래스 명명 규칙
```dart
// ✅ 올바른 방법
class TournamentDetailScreen extends StatefulWidget { }
class UserProfileWidget extends StatelessWidget { }
class TournamentModel { }
class FirebaseService { }
class AppStateProvider extends ChangeNotifier { }

// ❌ 잘못된 방법
class tournamentScreen { } // 소문자 시작
class UserProfile { }      // 타입 명시 없음
```

### 3. 변수 및 함수 명명 규칙
```dart
// ✅ 올바른 방법
final String tournamentId;
final List<UserModel> participants;
bool get isHost => hostId == currentUser?.uid;
Future<void> joinTournament() async { }

// ❌ 잘못된 방법
final String tournament_id; // snake_case 금지
final List participants;    // 타입 명시 없음
bool isHost() { }          // getter를 함수로 구현
```

### 4. 주석 및 문서화 규칙
```dart
/// 토너먼트 참가 처리
/// 
/// [tournamentId] 참가할 토너먼트 ID
/// [role] 참가할 역할 (top, jungle, mid, adc, support)
/// 
/// Returns [true] if successful, [false] otherwise
/// 
/// Throws [Exception] if user already joined
Future<bool> joinTournament(String tournamentId, String role) async {
  // 중요한 비즈니스 로직에 대한 설명
  if (await _isAlreadyJoined(tournamentId)) {
    throw Exception('이미 참가한 토너먼트입니다.');
  }
  
  // TODO: 크레딧 차감 로직 추가 필요
  return await _processJoin(tournamentId, role);
}
```

---

## 🔥 Firebase 및 백엔드 규칙

### 1. Firestore 컬렉션 구조
```
/users/{userId}                    // 사용자 정보
/tournaments/{tournamentId}        // 토너먼트 정보
/applications/{applicationId}      // 참가 신청
/messages/{messageId}              // 채팅 메시지
/chatRooms/{chatRoomId}           // 채팅방 정보
/clans/{clanId}                   // 클랜 정보
/evaluations/{evaluationId}       // 평가 정보
```

### 2. 데이터 모델 규칙
```dart
// ✅ 모든 모델은 Equatable 상속
class TournamentModel extends Equatable {
  final String id;
  final String title;
  final String hostId;
  final DateTime startsAt;
  final TournamentStatus status;
  
  const TournamentModel({
    required this.id,
    required this.title,
    required this.hostId,
    required this.startsAt,
    required this.status,
  });
  
  // fromFirestore, toFirestore 메서드 필수
  factory TournamentModel.fromFirestore(DocumentSnapshot doc) { }
  Map<String, dynamic> toFirestore() { }
  
  @override
  List<Object?> get props => [id, title, hostId, startsAt, status];
}
```

### 3. Firebase Service 패턴
```dart
class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ✅ 트랜잭션 사용 (데이터 일관성 보장)
  Future<void> joinTournament(String tournamentId, String userId, String role) async {
    await _firestore.runTransaction((transaction) async {
      // 1. 토너먼트 문서 읽기
      final tournamentRef = _firestore.collection('tournaments').doc(tournamentId);
      final tournamentSnap = await transaction.get(tournamentRef);
      
      // 2. 데이터 검증
      if (!tournamentSnap.exists) {
        throw Exception('토너먼트를 찾을 수 없습니다.');
      }
      
      // 3. 원자적 업데이트
      transaction.update(tournamentRef, {
        'participants': FieldValue.arrayUnion([userId]),
        'participantsByRole.$role': FieldValue.arrayUnion([userId]),
        'filledSlots': FieldValue.increment(1),
        'filledSlotsByRole.$role': FieldValue.increment(1),
      });
    });
  }
  
  // ✅ 에러 처리 포함
  Future<List<TournamentModel>> getTournaments() async {
    try {
      final querySnapshot = await _firestore
          .collection('tournaments')
          .where('status', isEqualTo: TournamentStatus.open.index)
          .orderBy('startsAt')
          .get();
      
      return querySnapshot.docs
          .map((doc) => TournamentModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      debugPrint('Firebase Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected Error: $e');
      rethrow;
    }
  }
}
```

### 4. Firebase Functions 규칙
```typescript
// functions/src/index.ts
// ✅ 모든 함수는 에러 처리 포함
export const onTournamentParticipantChange = functions.firestore
  .document('tournaments/{tournamentId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      
      // Discord 채널 생성 로직
      if (before.participants.length < 10 && after.participants.length === 10) {
        await createDiscordChannels(context.params.tournamentId, after);
      }
    } catch (error) {
      console.error('Error in onTournamentParticipantChange:', error);
      // 에러를 다시 던지지 않음 (Firebase Functions 재시도 방지)
    }
  });
```

---

## 🔄 상태 관리 규칙

### 1. Provider 패턴 사용
```dart
// ✅ ChangeNotifier 상속
class AppStateProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getter 제공
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // 상태 변경 시 notifyListeners() 호출
  Future<void> updateUser(UserModel user) async {
    _currentUser = user;
    notifyListeners();
  }
  
  // 에러 처리 포함
  Future<void> loadUserData() async {
    try {
      _setLoading(true);
      _currentUser = await _authService.getCurrentUser();
      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }
  
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
```

### 2. Consumer 패턴 사용
```dart
// ✅ Consumer로 필요한 부분만 리빌드
Widget build(BuildContext context) {
  return Scaffold(
    body: Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        if (appState.isLoading) {
          return const LoadingIndicator();
        }
        
        if (appState.errorMessage != null) {
          return ErrorView(errorMessage: appState.errorMessage!);
        }
        
        return TournamentList(tournaments: appState.tournaments);
      },
    ),
  );
}
```

---

## 📁 파일 구조 규칙

### 1. 디렉토리 구조
```
lib/
├── main.dart                    // 앱 진입점
├── firebase_options.dart        // Firebase 설정
├── config/                      // 앱 설정
│   └── env_config.dart         // 환경 변수
├── constants/                   // 상수 정의
│   ├── app_theme.dart          // 테마 및 색상
│   ├── app_constants.dart      // 앱 상수
│   └── lol_constants.dart      // 게임 관련 상수
├── models/                      // 데이터 모델
│   ├── user_model.dart
│   ├── tournament_model.dart
│   └── models.dart             // 모델 내보내기
├── providers/                   // 상태 관리
│   ├── app_state_provider.dart
│   └── auth_provider.dart
├── services/                    // 비즈니스 로직
│   ├── firebase_service.dart
│   ├── auth_service.dart
│   └── tournament_service.dart
├── screens/                     // UI 화면
│   ├── auth/
│   ├── tournaments/
│   ├── chat/
│   └── main_screen.dart
├── widgets/                     // 재사용 위젯
│   ├── loading_indicator.dart
│   ├── error_view.dart
│   └── tournament_card.dart
├── utils/                       // 유틸리티
│   ├── date_utils.dart
│   └── theme_utils.dart
└── navigation/                  // 라우팅
    └── app_router.dart
```

### 2. 파일 내 구조 규칙
```dart
// 1. 임포트 (Flutter → 외부 패키지 → 내부 패키지 순)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';

// 2. 클래스 정의
class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;
  
  const TournamentDetailScreen({
    Key? key,
    required this.tournamentId,
  }) : super(key: key);
  
  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

// 3. State 클래스
class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  // 3-1. 변수 선언
  late Future<TournamentModel> _tournamentFuture;
  bool _isLoading = false;
  
  // 3-2. 라이프사이클 메서드
  @override
  void initState() {
    super.initState();
    _loadTournament();
  }
  
  // 3-3. 비즈니스 로직 메서드
  Future<void> _loadTournament() async { }
  
  // 3-4. UI 빌드 메서드
  @override
  Widget build(BuildContext context) { }
  
  // 3-5. 헬퍼 메서드
  Widget _buildTournamentInfo() { }
  Widget _buildActionButtons() { }
}
```

---

## 🧪 테스트 및 배포 규칙

### 1. 코드 수정 후 필수 검증 절차
```bash
# 1. 코드 수정 완료 후 반드시 실행
flutter run

# 2. 오류 발생 시 즉시 수정
# - null 체크 누락
# - import 누락  
# - 삭제된 파일 참조
# - Firebase Functions 변경 시 배포 필요

# 3. Firebase Functions 변경 시
cd functions
firebase deploy --only functions
```

### 2. 빌드 및 배포 절차
```bash
# 개발 환경 테스트
flutter run --debug

# 릴리스 빌드 테스트
flutter build apk --release
flutter build ios --release

# Firebase 배포
firebase deploy --only hosting,functions,firestore:rules
```

### 3. 오류 해결 우선순위
1. **컴파일 오류**: 즉시 수정 (빌드 실패)
2. **런타임 오류**: 우선 수정 (앱 크래시)
3. **Firebase 오류**: 권한 및 규칙 확인
4. **UI 오류**: 사용자 경험 영향 최소화

---

## 🔒 보안 규칙

### 1. Firestore Security Rules
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 인증 함수
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    // 사용자 컬렉션
    match /users/{userId} {
      allow read: if true; // 공개 정보
      allow write: if isAuthenticated() && isOwner(userId);
    }
    
    // 토너먼트 컬렉션
    match /tournaments/{tournamentId} {
      allow read: if true;
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() && (
        // 호스트는 모든 필드 수정 가능
        resource.data.hostUid == request.auth.uid ||
        // 참가자는 특정 필드만 수정 가능
        request.resource.data.diff(resource.data).affectedKeys()
          .hasOnly(['participants', 'participantsByRole', 'filledSlots'])
      );
    }
  }
}
```

### 2. 민감정보 관리
```dart
// ✅ 환경 변수 사용
class EnvConfig {
  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );
  
  // ❌ 하드코딩 금지
  // static const String apiKey = 'sk_live_...'; // 절대 금지!
}
```

### 3. 사용자 입력 검증
```dart
// ✅ 클라이언트 및 서버 모두에서 검증
bool _validateTournamentTitle(String title) {
  if (title.trim().isEmpty) return false;
  if (title.length > 50) return false;
  if (title.contains(RegExp(r'[<>]'))) return false; // XSS 방지
  return true;
}
```

---

## ⚡ 성능 최적화 규칙

### 1. Widget 최적화
```dart
// ✅ const 생성자 사용
const Text('고정 텍스트');
const SizedBox(height: 16);

// ✅ ListView.builder 사용 (대용량 리스트)
ListView.builder(
  itemCount: tournaments.length,
  itemBuilder: (context, index) {
    return TournamentCard(tournament: tournaments[index]);
  },
);

// ❌ 일반 ListView 금지 (대용량 데이터)
ListView(
  children: tournaments.map((t) => TournamentCard(tournament: t)).toList(),
);
```

### 2. 이미지 최적화
```dart
// ✅ 캐시된 네트워크 이미지
CachedNetworkImage(
  imageUrl: user.profileImageUrl,
  placeholder: (context, url) => const CircularProgressIndicator(),
  errorWidget: (context, url, error) => Image.asset(AppImages.defaultProfile),
  fit: BoxFit.cover,
);

// ✅ 이미지 크기 제한
Image.network(
  imageUrl,
  width: 100,
  height: 100,
  fit: BoxFit.cover,
);
```

### 3. Firebase 쿼리 최적화
```dart
// ✅ 인덱스 활용한 복합 쿼리
Query query = _firestore
    .collection('tournaments')
    .where('status', isEqualTo: TournamentStatus.open.index)
    .where('startsAt', isGreaterThan: DateTime.now())
    .orderBy('startsAt')
    .limit(20); // 페이지네이션

// ✅ 필요한 필드만 선택 (가능한 경우)
// 현재 Firestore는 필드 선택을 지원하지 않지만, 
// 클라이언트에서 필요한 데이터만 사용
```

---

## 📱 플랫폼별 고려사항

### 1. iOS 특화 설정
```dart
// iOS 안전 영역 고려
SafeArea(
  child: Scaffold(
    body: content,
  ),
);

// iOS 스타일 네비게이션
CupertinoPageRoute(
  builder: (context) => NextScreen(),
);
```

### 2. Android 특화 설정
```dart
// Android 백 버튼 처리
WillPopScope(
  onWillPop: () async {
    // 뒤로가기 로직
    return true;
  },
  child: Scaffold(),
);
```

---

## 🔄 업데이트 및 유지보수 규칙

### 1. 버전 관리
```yaml
# pubspec.yaml
version: 1.0.0+1 # 형식: major.minor.patch+build

# 버전 업데이트 기준
# major: 호환되지 않는 변경사항
# minor: 하위 호환되는 기능 추가
# patch: 하위 호환되는 버그 수정
```

### 2. 의존성 관리
```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^2.24.2      # 특정 버전 명시
  cloud_firestore: ^4.13.6    # 메이저 버전 고정
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0       # 린트 규칙 적용
```

### 3. 코드 리뷰 체크리스트
- [ ] 메모리에 따른 flutter run 실행 확인
- [ ] 토스 스타일 디자인 적용 확인
- [ ] 메인 컬러 사용 확인
- [ ] 에러 처리 포함 확인
- [ ] 주석 및 문서화 확인
- [ ] 보안 규칙 준수 확인
- [ ] 성능 최적화 적용 확인

---

## 🚨 중요 알림 및 주의사항

### 1. 절대 규칙 (반드시 준수)
1. **코드 수정 후 반드시 `flutter run` 실행하여 오류 확인**
2. **모든 UI는 토스 스타일 + 메인 컬러 적용**
3. **Firebase Functions 변경 시 즉시 배포**
4. **민감정보 하드코딩 절대 금지**
5. **트랜잭션 사용으로 데이터 일관성 보장**

### 2. 개발 효율성을 위한 도구 활용
- **등록된 MCP 도구 최대한 활용**
- **Firebase MCP로 데이터베이스 관리**
- **GitHub MCP로 코드 관리**
- **Context7 MCP로 라이브러리 문서 참조**

### 3. 문제 발생 시 대응 절차
1. 오류 로그 확인
2. Firebase Console 확인
3. 보안 규칙 검토
4. 네트워크 연결 확인
5. 캐시 클리어 (`flutter clean`)

---

## 📚 참고 문서

- [Flutter 공식 문서](https://flutter.dev/docs)
- [Firebase 공식 문서](https://firebase.google.com/docs)
- [토스 디자인 시스템](https://toss.tech/slash-21/sessions/3-3)
- [프로젝트 README](README.md)
- [Firebase 설정 가이드](FIREBASE_SETUP.md)
- [보안 가이드](FIREBASE_SECURITY_GUIDE.md)

---

**이 문서는 프로젝트의 일관성과 품질을 보장하기 위한 필수 가이드라인입니다. 모든 개발자는 이 규칙을 숙지하고 준수해야 합니다.**