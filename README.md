# LoL 내전 매니저 (LoL Custom Game Manager)

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

## 프로젝트 구조

```
lib/
├── constants/           # 앱 전체에서 사용되는 상수
│   └── app_theme.dart   # 테마 설정
├── firebase_options.dart # Firebase 설정
├── main.dart            # 앱 진입점
├── models/              # 데이터 모델
│   ├── user_model.dart
│   ├── tournament_model.dart
│   ├── mercenary_model.dart
│   └── rating_model.dart
├── navigation/          # 라우팅 설정
│   └── app_router.dart  # go_router 설정
├── providers/           # 상태 관리
│   └── auth_provider.dart # 인증 상태 관리
├── screens/             # UI 화면
│   ├── auth/            # 인증 관련 화면
│   ├── chat/            # 채팅 관련 화면
│   ├── main_screen.dart # 메인 화면 (탭 네비게이션)
│   ├── mercenaries/     # 용병 관련 화면
│   ├── my_page/         # 마이페이지 화면
│   ├── rankings/        # 랭킹 화면
│   └── tournaments/     # 내전 관련 화면
├── services/            # 비즈니스 로직 및 외부 서비스 연동
│   ├── auth_service.dart # 인증 서비스
│   └── tournament_service.dart # 토너먼트 서비스
└── widgets/             # 재사용 가능한 위젯
    └── tournament_card_simplified.dart # 토너먼트 카드 위젯

assets/
├── images/              # 이미지 파일
├── icons/               # 아이콘 파일
└── fonts/               # 폰트 파일
```

## Firebase 설정

### Firestore 컬렉션 구조

- **users**: 사용자 정보
  - `uid`, `riotId`, `nickname`, `tier`, `profileImageUrl`, `credits`, `averageRating`, `ratingCount`, `isVerified`, `joinedAt`, `lastActiveAt`, `isPremium`, `stats`

- **tournaments**: 내전 정보
  - `id`, `hostUid`, `hostNickname`, `hostProfileImageUrl`, `startsAt`, `location`, `locationCoordinates`, `ovrLimit`, `isPaid`, `price`, `premiumBadge`, `slotsByRole`, `filledSlotsByRole`, `status`, `createdAt`, `description`, `participantUids`

- **mercenaries**: 용병 정보
  - `id`, `userUid`, `nickname`, `profileImageUrl`, `tier`, `roleStats`, `skillStats`, `preferredPositions`, `description`, `averageRating`, `ratingCount`, `isAvailable`, `createdAt`, `lastActiveAt`

- **ratings**: 평가 정보
  - `id`, `ratedUserId`, `raterId`, `raterName`, `raterProfileImageUrl`, `score`, `role`, `comment`, `createdAt`, `stars`

- **chatRooms**: 채팅방 정보
  - `id`, `participantUids`, `lastMessage`, `lastMessageTimestamp`, `createdAt`

- **messages**: 메시지 정보
  - `id`, `chatRoomId`, `senderId`, `senderName`, `content`, `timestamp`, `isRead`

### Firebase 보안 규칙

Firestore 보안 규칙은 다음과 같이 설정합니다:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == userId;
    }
    
    match /tournaments/{tournamentId} {
      allow read;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.hostUid;
    }
    
    match /mercenaries/{mercenaryId} {
      allow read;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.userUid;
    }
    
    match /ratings/{ratingId} {
      allow read;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.raterId;
    }
    
    match /chatRooms/{chatRoomId} {
      allow read: if request.auth != null && request.auth.uid in resource.data.participantUids;
      allow create: if request.auth != null;
      allow update: if request.auth != null && request.auth.uid in resource.data.participantUids;
    }
    
    match /messages/{messageId} {
      allow read: if request.auth != null && get(resource.data.chatRoomId).data.participantUids[request.auth.uid] != null;
      allow create: if request.auth != null && request.resource.data.senderId == request.auth.uid;
    }
  }
}
```

## Cloud Functions

주요 Cloud Functions:

1. **onCreateTournament**: 새 토너먼트 생성 시 푸시 알림 전송
2. **onJoinTournament**: 용병 참가 신청 시 호스트에게 알림 전송
3. **onMessageCreate**: 새 메시지 수신 시 상대방에게 알림 전송
4. **onRatingCreate**: 새 평가 작성 시 평균 평점 업데이트
5. **stripeWebhook**: Stripe 결제 완료 시 참가 상태 업데이트

## 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 연락처

문의사항이 있으시면 [이메일 주소]로 연락주세요.

## Firebase 통합 문제 분석 및 해결책

### 발생한 문제
Firebase 패키지와 최신 Flutter/Dart SDK 간의 호환성 문제가 발생했습니다. 주로 다음과 같은 에러가 발생했습니다:

1. **JS interop 관련 에러**
   - `PromiseJsImpl`, `handleThenable`, `dartify`, `jsify` 등의 메서드를 찾을 수 없음
   - 원인: firebase_auth_web, firebase_messaging_web 등의 웹 패키지가 dart:js_util의 API를 직접 사용하도록 변경되었으나, 구 버전 패키지는 여전히 이전 방식을 참조함

2. **API 변경 관련 에러**
   - Firestore 인터페이스 변경
   - Timestamp → DateTime 변환 필요
   - nullable 타입 처리 필요
   - CardTheme → CardThemeData 변경
   - RatingModel에 stars 필드 추가 필요
   - fold 연산자 오버로드 문제

### 해결 방법 (종합)

1. **Firebase 패키지 버전 조정**
   ```yaml
   dependencies:
     firebase_core: ^2.13.1  # 더 낮은 버전으로 다운그레이드
     firebase_auth: ^4.6.2
     cloud_firestore: ^4.8.0
     firebase_storage: ^11.2.2
     firebase_messaging: ^14.6.2
     # 기타 패키지들도 호환 가능한 버전으로 조정
   ```

2. **JS 패키지 버전 조정**
   ```yaml
   dependencies:
     js: ^0.6.3  # 특정 버전 사용
   ```

3. **모델 클래스 업데이트**
   - Timestamp를 DateTime으로 변환하는 유틸리티 메서드 추가
   - RatingModel에 stars 필드 추가
   - nullable 필드에 대한 안전한 처리 추가

4. **UI 관련 변경**
   - CardTheme을 CardThemeData로 변경

5. **fold 연산자 문제 해결**
   ```dart
   // 기존 (Object? 에 + 를 사용해 에러 발생)
   '총 ${_slotsByRole.values.fold(0, (prev, curr) => prev + curr)}명'
   
   // 수정
   '총 ${_slotsByRole.values.cast<int>().fold(0, (p, c) => p + c)}명'
   ```

### 대안적 접근 방법

Firebase 통합이 계속 문제를 일으킨다면 다음과 같은 대안을 고려할 수 있습니다:

1. **Dart/Flutter 버전 다운그레이드**
   - Flutter 2.x와 Dart 2.18 이하 버전으로 다운그레이드

2. **Firebase 없이 앱 구현**
   - 로컬 데이터 저장소(Hive, SQLite 등) 사용
   - 대체 백엔드 서비스 사용(Supabase, Appwrite 등)

3. **웹 빌드 대신 네이티브 빌드만 지원**
   - 웹 JS interop 문제가 해결될 때까지 네이티브 앱만 지원

## 현재 구현된 앱
Firebase 통합 문제로 인해 현재 버전에서는 Firebase를 제거하고 UI 기능만 구현했습니다. 기본적인 내전 목록 및 카드 UI를 보여주는 앱으로 구성되어 있습니다.

## 실행 방법
```
flutter pub get
flutter run
``` 