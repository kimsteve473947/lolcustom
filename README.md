# 스크림져드

League of Legends 내전(Custom Game) 매니저 앱으로 용병 모집과 참가를 쉽게 관리할 수 있습니다.

## 주요 기능

- **내전 관리**: 내전 생성, 참가자 관리, 역할별 인원 배정
- **용병 시스템**: 선수 등록, 역할별 능력치, 평가 시스템
- **채팅**: 내전 주최자와 참가자 간 1:1 채팅
- **랭킹**: 참가자 평가 기반 랭킹 시스템
- **프로필**: 내전 참가 이력, 받은 평가, 라이엇 계정 연동
- **결제 시스템**: 유료 내전 참가비 결제
- **푸시 알림**: 내전 생성, 용병 신청, 채팅 메시지 수신 시 알림

## 기술 스택

- **Frontend**: Flutter 3.x
- **Backend**: Firebase (Auth, Firestore, Storage, Cloud Functions, Messaging)
- **상태 관리**: Provider
- **라우팅**: go_router (Navigator 2.0)
- **결제**: Flutter Stripe

## 프로젝트 설정

### 사전 요구사항

- Flutter SDK 3.0.0 이상
- Dart SDK 2.19.0 이상
- Firebase 계정
- Android Studio 또는 VS Code

### 설치 방법

1. 저장소 복제

```bash
git clone https://github.com/yourusername/lol_custom_game_manager.git
cd lol_custom_game_manager
```

2. 패키지 설치

```bash
flutter pub get
```

3. Firebase 설정

Firebase 콘솔(https://console.firebase.google.com/)에서 새 프로젝트를 생성하고 Flutter 앱을 추가합니다.
FlutterFire CLI를 사용하여 Firebase 설정 파일을 생성합니다:

```bash
flutter pub global activate flutterfire_cli
flutterfire configure
```

4. 환경 변수 설정

프로젝트 루트에 `.env` 파일을 생성하고 필요한 환경 변수를 설정합니다:

```
APP_NAME=LoL 내전 매니저
APP_VERSION=1.0.0
ENV=development
STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key
```

5. 에셋 디렉토리 생성

```bash
mkdir -p assets/images assets/icons assets/fonts
```

### 실행 방법

```bash
# 디버그 모드로 실행
flutter run

# 릴리스 모드로 빌드
flutter build apk --release  # Android
flutter build ios --release  # iOS
flutter build web --release  # Web
```

## 프로젝트 구조 및 아키텍처

```
lib/
├── constants/              # 앱 전체에서 사용되는 상수
│   ├── app_theme.dart      # 테마 설정
│   └── lol_constants.dart  # 게임 관련 상수
├── config/                 # 앱 설정 및 환경 변수
├── firebase_options.dart   # Firebase 설정
├── main.dart               # 앱 진입점
├── models/                 # 데이터 모델
│   ├── user_model.dart     # 사용자 모델
│   ├── tournament_model.dart # 토너먼트 모델
│   ├── mercenary_model.dart # 용병 모델
│   ├── application_model.dart # 신청 모델
│   ├── rating_model.dart   # 평가 모델
│   ├── chat_model.dart     # 채팅 모델
│   └── models.dart         # 모델 내보내기
├── navigation/             # 라우팅 설정
│   └── app_router.dart     # go_router 설정
├── providers/              # 상태 관리
│   ├── auth_provider.dart  # 인증 상태 관리
│   └── app_state_provider.dart # 앱 상태 관리
├── screens/                # UI 화면
│   ├── auth/               # 인증 관련 화면
│   ├── chat/               # 채팅 관련 화면
│   ├── clans/              # 클랜 관련 화면
│   ├── main/               # 메인 화면 컴포넌트
│   ├── main_screen.dart    # 메인 화면 (탭 네비게이션)
│   ├── mercenaries/        # 용병 관련 화면
│   ├── my_page/            # 마이페이지 화면
│   ├── rankings/           # 랭킹 화면
│   ├── splash_screen.dart  # 스플래시 화면
│   └── tournaments/        # 내전 관련 화면
│       ├── tournament_main_screen.dart # 토너먼트 메인 화면
│       ├── tournament_detail_screen.dart # 토너먼트 상세 화면
│       ├── create_tournament_screen.dart # 토너먼트 생성 화면
│       ├── match_list_tab.dart # 매치 목록 탭
│       └── mercenary_search_tab.dart # 용병 검색 탭
├── services/               # 비즈니스 로직 및 외부 서비스 연동
│   ├── auth_service.dart   # 인증 서비스
│   ├── firebase_service.dart # Firebase 데이터 서비스
│   ├── tournament_service.dart # 토너먼트 서비스
│   ├── cloud_functions_service.dart # 클라우드 함수 서비스
│   └── firebase_messaging_service.dart # 푸시 알림 서비스
├── utils/                  # 유틸리티 함수
└── widgets/                # 재사용 가능한 위젯
    ├── tournament_card.dart # 토너먼트 카드 위젯
    ├── loading_indicator.dart # 로딩 인디케이터
    └── error_view.dart     # 에러 표시 위젯

assets/
├── images/                 # 이미지 파일
├── icons/                  # 아이콘 파일
└── fonts/                  # 폰트 파일
```

### 아키텍처 및 데이터 흐름

이 프로젝트는 다음과 같은 아키텍처 패턴을 따릅니다:

1. **서비스 레이어**: Firebase와 같은 외부 서비스와의 통신을 담당합니다.
2. **프로바이더 레이어**: 상태 관리 및 서비스 레이어 호출을 담당합니다.
3. **UI 레이어**: 사용자 인터페이스를 구성하고 프로바이더를 통해 데이터를 가져옵니다.

데이터 흐름:
```
UI (Widget) → Provider → Service → Firebase → Service → Provider → UI (Widget)
```

## Firebase 설정

### Firestore 컬렉션 구조

- **users**: 사용자 정보
  - `uid`, `riotId`, `nickname`, `tier`, `profileImageUrl`, `credits`, `averageRating`, `ratingCount`, `isVerified`, `joinedAt`, `lastActiveAt`, `isPremium`, `stats`

- **tournaments**: 내전 정보
  - `id`, `hostUid`, `hostNickname`, `hostProfileImageUrl`, `title`, `description`, `startsAt`, `location`, `tournamentType`, `slotsByRole`, `filledSlotsByRole`, `participants`, `participantsByRole`, `status`, `createdAt`, `updatedAt`, `rules`

- **applications**: 내전 신청 정보
  - `id`, `tournamentId`, `userUid`, `userName`, `userProfileImageUrl`, `role`, `userOvr`, `status`, `appliedAt`, `message`

- **mercenaries**: 용병 정보
  - `id`, `userUid`, `nickname`, `profileImageUrl`, `tier`, `roleStats`, `skillStats`, `preferredPositions`, `description`, `averageRating`, `ratingCount`, `isAvailable`, `createdAt`, `lastActiveAt`

- **ratings**: 평가 정보
  - `id`, `ratedUserId`, `raterId`, `raterName`, `raterProfileImageUrl`, `score`, `role`, `comment`, `createdAt`, `stars`

- **chatRooms**: 채팅방 정보
  - `id`, `participantUids`, `lastMessage`, `lastMessageTimestamp`, `createdAt`

- **messages**: 메시지 정보
  - `id`, `chatRoomId`, `senderId`, `senderName`, `content`, `timestamp`, `isRead`

### Firebase 보안 규칙 (업데이트됨)

Firestore 보안 규칙은 다음과 같이 설정합니다. 이 규칙은 토너먼트 참가와 관련된 권한 문제를 해결합니다:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 사용자 기본 함수
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    function isTournamentHost(tournamentId) {
      let tournament = get(/databases/$(database)/documents/tournaments/$(tournamentId));
      return request.auth.uid == tournament.data.hostUid;
    }
    
    // 사용자 컬렉션
    match /users/{userId} {
      allow read: if true; // 모든 사용자 정보는 공개
      allow create: if isSignedIn();
      allow update, delete: if isOwner(userId);
    }
    
    // 토너먼트 컬렉션
    match /tournaments/{tournamentId} {
      // 읽기는 모두 허용
      allow read: if true;
      
      // 생성은 로그인한 사용자만 가능
      allow create: if isSignedIn();
      
      // 토너먼트 업데이트 권한
      // 1. 호스트는 모든 필드 업데이트 가능
      // 2. 일반 사용자는 참가 관련 필드만 업데이트 가능
      allow update: if isSignedIn() && (
        isTournamentHost(tournamentId) || 
        (
          // 참가자가 변경할 수 있는 필드 목록
          request.resource.data.diff(resource.data).affectedKeys()
            .hasOnly(['participants', 'participantsByRole', 'filledSlots', 'filledSlotsByRole', 'status', 'updatedAt'])
        )
      );
      
      // 삭제는 호스트만 가능
      allow delete: if isSignedIn() && isTournamentHost(tournamentId);
    }
    
    // 신청 컬렉션
    match /applications/{applicationId} {
      // 읽기는 모두 허용
      allow read: if true;
      
      // 생성은 로그인한 사용자만 가능하며, 자신의 신청서만 생성 가능
      allow create: if isSignedIn() && 
                    request.resource.data.userUid == request.auth.uid;
      
      // 업데이트는 신청자 본인 또는 토너먼트 호스트만 가능
      allow update: if isSignedIn() && (
        request.resource.data.userUid == request.auth.uid || 
        isTournamentHost(resource.data.tournamentId)
      );
      
      // 삭제는 신청자 본인 또는 토너먼트 호스트만 가능
      allow delete: if isSignedIn() && (
        resource.data.userUid == request.auth.uid || 
        isTournamentHost(resource.data.tournamentId)
      );
    }
    
    // 용병 컬렉션
    match /mercenaries/{mercenaryId} {
      allow read: if true;
      allow create: if isSignedIn();
      allow update, delete: if isSignedIn() && 
                            resource.data.userUid == request.auth.uid;
    }
    
    // 평가 컬렉션
    match /ratings/{ratingId} {
      allow read: if true;
      allow create: if isSignedIn();
      allow update, delete: if isSignedIn() && 
                           resource.data.raterId == request.auth.uid;
    }
    
    // 채팅방 컬렉션
    match /chatRooms/{chatRoomId} {
      allow read: if isSignedIn() && 
                 request.auth.uid in resource.data.participantUids;
      allow create: if isSignedIn();
      allow update: if isSignedIn() && 
                   request.auth.uid in resource.data.participantUids;
    }
    
    // 메시지 컬렉션
    match /messages/{messageId} {
      allow read: if isSignedIn() && exists(/databases/$(database)/documents/chatRooms/$(resource.data.chatRoomId)) &&
                 request.auth.uid in get(/databases/$(database)/documents/chatRooms/$(resource.data.chatRoomId)).data.participantUids;
      allow create: if isSignedIn() && 
                   request.resource.data.senderId == request.auth.uid;
    }
  }
}
```

## 주요 컴포넌트 구조

### Provider 패턴

앱은 Provider 패턴을 사용해 상태를 관리합니다:

1. **AppStateProvider**: 앱의 주요 상태를 관리하는 프로바이더
   - 사용자 정보 관리
   - 토너먼트 참가/취소 처리
   - 크레딧 충전/사용 처리

2. **AuthProvider**: 인증 관련 상태를 관리하는 프로바이더
   - 로그인/로그아웃 상태 관리
   - 사용자 인증 정보 관리

### 서비스 레이어

서비스 레이어는 외부 서비스와의 통신을 담당합니다:

1. **FirebaseService**: Firestore 데이터베이스 접근을 담당
   - CRUD 작업 수행
   - 트랜잭션 처리

2. **AuthService**: Firebase Auth 서비스 접근을 담당
   - 사용자 인증 처리
   - 토큰 관리

3. **TournamentService**: 토너먼트 관련 비즈니스 로직을 담당
   - 토너먼트 필터링 및 정렬
   - 토너먼트 상태 변경

4. **CloudFunctionsService**: Firebase Cloud Functions 호출을 담당
   - 서버 사이드 로직 호출
   - 결제 처리

5. **FirebaseMessagingService**: Firebase Cloud Messaging 서비스 접근을 담당
   - 푸시 알림 구독/해제
   - 알림 처리

## 알려진 이슈 및 해결 방법

### 1. Firebase 권한 오류

**이슈**: `[cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.`

**원인**: Firebase 보안 규칙이 특정 작업을 허용하지 않음

**해결 방법**:
1. Firebase 콘솔에서 보안 규칙 업데이트
2. 위에 제시된 보안 규칙 적용
3. 특히 토너먼트 업데이트 규칙을 확인하여 참가자가 필요한 필드를 업데이트할 수 있는지 확인

### 2. 토너먼트 참가 시 오류

**이슈**: 토너먼트 참가 시 Firebase 권한 오류 발생

**원인**: 참가자가 토너먼트 문서를 업데이트할 권한이 없음

**해결 방법**:
1. Firebase 보안 규칙에서 참가 관련 필드에 대한 업데이트 권한을 명시적으로 부여
2. 트랜잭션을 사용하여 참가 처리를 수행하도록 코드 수정
3. 필요한 경우 Cloud Functions를 사용하여 서버 측에서 참가 처리 수행

### 3. Firebase 패키지 호환성 문제

**이슈**: Firebase 패키지와 Flutter 버전 간의 호환성 문제

**해결 방법**:
1. 패키지 버전을 명시적으로 지정하여 호환성 문제 해결
2. Flutter 및 Dart SDK 버전을 호환 가능한 버전으로 조정
3. 필요한 경우 `flutter clean` 후 다시 빌드

## 개선 사항 및 향후 계획

1. **성능 최적화**
   - 대용량 데이터 페이지네이션 개선
   - 이미지 캐싱 최적화

2. **기능 확장**
   - 팀 기능 강화
   - 토너먼트 결과 기록 및 통계 시스템

3. **유지 보수성 향상**
   - 테스트 코드 작성
   - 문서화 개선

## 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 연락처

문의사항이 있으시면 [이메일 주소]로 연락주세요.

## 앱 에셋 관리

### 롤 라인 로고

각 라인(포지션)별 로고 이미지는 `assets/images/lanes/` 경로에 저장되어 있습니다:
- 탑: `lane_top.png`
- 정글: `lane_jungle.png`
- 미드: `lane_mid.png`
- 원딜: `lane_adc.png`
- 서포터: `lane_support.png`

이 이미지들은 `lib/constants/lol_constants.dart` 파일의 `LolLaneIcons` 클래스에서 참조됩니다.
`TournamentUIUtils.getRoleIconImage()` 함수를 사용하여 각 역할에 맞는 이미지를 가져올 수 있습니다. 
