# LoL 내전 매니저 (LoL Custom Game Manager)

League of Legends 내전(Custom Game) 매니저 앱으로 용병 모집과 참가를 쉽게 관리할 수 있습니다.

## 주요 기능

- **내전 관리**: 내전 생성, 참가자 관리, 역할별 인원 배정
- **용병 시스템**: 선수 등록, 역할별 능력치, 평가 시스템
- **채팅**: 내전 주최자와 참가자 간 1:1 채팅
- **랭킹**: 참가자 평가 기반 랭킹 시스템
- **프로필**: 내전 참가 이력, 받은 평가, 라이엇 계정 연동
- **푸시 알림**: 내전 생성, 용병 신청, 채팅 메시지 수신 시 알림

## 기술 스택

- **Frontend**: Flutter 3.x
- **Backend**: Firebase (Auth, Firestore, Storage, Cloud Functions, Messaging)
- **상태 관리**: Provider
- **라우팅**: go_router (Navigator 2.0)

## 프로젝트 설정

### 사전 요구사항

- Flutter SDK 3.0.0 이상
- Dart SDK 2.17.0 이상
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
```

5. 에셋 디렉토리 생성

```bash
mkdir -p assets/images assets/icons
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
├── config/              # 환경 설정
├── constants/           # 앱 전체에서 사용되는 상수
├── firebase_options.dart # Firebase 설정
├── main.dart            # 앱 진입점
├── models/              # 데이터 모델
├── navigation/          # 라우팅 설정
├── providers/           # 상태 관리
├── screens/             # UI 화면
│   ├── auth/            # 인증 관련 화면
│   ├── chat/            # 채팅 관련 화면
│   ├── main/            # 메인 화면
│   ├── mercenaries/     # 용병 관련 화면
│   ├── my_page/         # 마이페이지 화면
│   ├── rankings/        # 랭킹 화면
│   └── tournaments/     # 내전 관련 화면
├── services/            # 비즈니스 로직 및 외부 서비스 연동
└── widgets/             # 재사용 가능한 위젯

assets/
├── images/              # 이미지 파일
└── icons/               # 아이콘 파일
```

## 웹 지원 이슈

현재 이 앱은 iOS 및 Android 플랫폼에서만 정상 작동합니다. 웹 버전은 Firebase JS 패키지의 호환성 문제로 인해 지원되지 않습니다. 향후 릴리스에서 웹 지원을 추가할 예정입니다.

## 주의사항

- 개발 환경에서는 `.env` 파일의 `ENV` 값을 `development`로 설정하여 테스트 용이성을 높입니다.
- 운영 환경에서는 `ENV` 값을 `production`으로 변경하여 로그 출력 및 디버그 기능을 비활성화합니다.
- Firebase 인증은 이메일/비밀번호 방식을 기본으로 하며, 소셜 로그인(구글, 애플)도 지원합니다.
- 웹 환경은 현재 지원되지 않으므로 iOS 또는 Android 에뮬레이터/시뮬레이터에서 테스트하세요.

## 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 연락처

문의사항이 있으시면 [이메일 주소]로 연락주세요. 