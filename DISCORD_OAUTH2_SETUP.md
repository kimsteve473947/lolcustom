# 🎮 Discord OAuth2 인증 및 비공개 채널 설정 가이드

## 📋 개요
이 가이드는 스크림져드 앱에 Discord OAuth2 인증을 연동하고, 토너먼트 참가자들만 접근할 수 있는 비공개 Discord 채널을 자동 생성하는 방법을 설명합니다.

## 🎯 주요 기능
- **Discord OAuth2 로그인**: 회원가입/로그인 시 Discord 계정 연동
- **권한 기반 비공개 채널**: 토너먼트 참가자들만 접근 가능한 채널
- **자동 권한 관리**: Discord ID 기반 권한 자동 부여
- **폴백 시스템**: Discord 미연결 사용자를 위한 공개 채널 생성

---

## 🔧 1단계: Discord Developer Portal 설정

### 1.1 Discord 애플리케이션 생성
1. [Discord Developer Portal](https://discord.com/developers/applications)에 접속
2. "New Application" 클릭
3. 애플리케이션 이름 입력: "스크림져드"
4. "Create" 클릭

### 1.2 OAuth2 설정
1. 왼쪽 메뉴에서 "OAuth2" → "General" 클릭
2. **Client ID**와 **Client Secret** 복사 (나중에 필요)
3. "Redirects" 섹션에서 다음 URL들 추가:
   ```
   https://your-project-id.firebaseapp.com/__/auth/handler
   http://localhost:3000/__/auth/handler
   ```
   (your-project-id를 실제 Firebase 프로젝트 ID로 변경)

### 1.3 Bot 설정 (선택사항)
1. 왼쪽 메뉴에서 "Bot" 클릭
2. "Reset Token" 클릭하여 Bot Token 생성
3. Bot Token 복사 (Discord 채널 생성용)

---

## 🔥 2단계: Firebase Console 설정

### 2.1 Authentication 설정
1. [Firebase Console](https://console.firebase.google.com/) 접속
2. 프로젝트 선택 → "Authentication" → "Sign-in method"
3. "Add new provider" 클릭
4. "Discord" 선택 (또는 "Custom OAuth provider")
5. 설정 정보 입력:
   ```
   Provider name: Discord
   Provider ID: discord.com
   Client ID: [Discord에서 복사한 Client ID]
   Client Secret: [Discord에서 복사한 Client Secret]
   
   Authorization endpoint: https://discord.com/api/oauth2/authorize
   Token endpoint: https://discord.com/api/oauth2/token
   User info endpoint: https://discord.com/api/users/@me
   
   Scopes: identify,email
   ```
6. "Save" 클릭

### 2.2 Firebase Functions 환경 변수 설정
```bash
# Discord Bot 설정
firebase functions:config:set discord.bot_token="YOUR_DISCORD_BOT_TOKEN"
firebase functions:config:set discord.guild_id="YOUR_DISCORD_SERVER_ID" 
firebase functions:config:set discord.category_id="YOUR_CATEGORY_ID"

# 설정 확인
firebase functions:config:get

# Functions 배포
firebase deploy --only functions
```

---

## 📱 3단계: 앱 설정 확인

### 3.1 패키지 의존성 확인
`pubspec.yaml`에 다음 패키지가 포함되어 있는지 확인:
```yaml
dependencies:
  firebase_auth_oauth: ^1.2.3
  # 다른 의존성들...
```

### 3.2 UserModel 필드 확인
Discord 관련 필드들이 추가되었는지 확인:
- `discordId`: Discord 고유 ID
- `discordUsername`: Discord 사용자명
- `discordAvatar`: Discord 프로필 이미지
- `discordConnectedAt`: Discord 연결 시간

---

## 🎮 4단계: Discord 서버 설정

### 4.1 Discord 서버 준비
1. Discord에서 새 서버 생성 또는 기존 서버 사용
2. 서버 ID 복사: `서버 설정` → `위젯` → `서버 ID`
3. 카테고리 생성 (선택사항): "스크림져드 내전방"

### 4.2 Bot 권한 설정
봇을 서버에 초대할 때 다음 권한 필요:
- `Manage Channels` (채널 생성/삭제)
- `Manage Roles` (권한 관리)
- `Send Messages` (메시지 전송)
- `View Channel` (채널 보기)
- `Connect` (음성 채널 연결)

Bot 초대 URL 생성:
```
https://discord.com/api/oauth2/authorize?client_id=YOUR_CLIENT_ID&permissions=268445776&scope=bot
```

---

## 🔄 5단계: 동작 흐름

### 5.1 사용자 로그인 흐름
```
1. 사용자가 "Discord로 로그인" 버튼 클릭
2. Discord OAuth2 창 열림
3. 사용자가 Discord 계정으로 인증
4. Firebase Auth에 사용자 정보 저장
5. Firestore에 Discord ID, 사용자명 등 저장
```

### 5.2 비공개 채널 생성 흐름
```
1. 토너먼트 참가자 10명 달성
2. 참가자들의 Discord ID 수집
3. Discord ID가 있는 사용자들에게만 권한 부여
4. 비공개 채널 3개 생성 (텍스트, A팀 음성, B팀 음성)
5. @everyone 역할은 채널 보기 권한 거부
6. 참가자들만 채널 접근 가능
```

---

## 🧪 6단계: 테스트 방법

### 6.1 Discord 로그인 테스트
1. 앱 실행 → 로그인 화면
2. "Discord로 로그인" 버튼 클릭
3. Discord 인증 완료 후 메인 화면 이동 확인
4. 마이페이지에서 Discord 연결 상태 확인

### 6.2 비공개 채널 테스트
1. Discord 계정을 연결한 사용자 10명으로 토너먼트 참가
2. 10명 달성 시 Discord 채널 자동 생성 확인
3. 참가자들만 채널 접근 가능한지 확인
4. 다른 서버 멤버들은 채널을 볼 수 없는지 확인

---

## ⚠️ 7단계: 트러블슈팅

### 7.1 Discord 로그인 실패
```bash
# Firebase Functions 로그 확인
firebase functions:log

# 일반적인 해결 방법:
# 1. Discord OAuth2 Redirect URL 확인
# 2. Firebase Auth Provider 설정 재확인
# 3. 앱 재시작
```

### 7.2 채널 생성 실패
```bash
# 봇 권한 확인
# 1. Manage Channels 권한 있는지 확인
# 2. 서버 ID, 봇 토큰 정확한지 확인
# 3. Functions 환경 변수 재설정
```

### 7.3 권한 설정 문제
```javascript
// Discord 권한 값 참고
VIEW_CHANNEL = 1024
SEND_MESSAGES = 2048
CONNECT = 1048576
```

---

## 🔒 8단계: 보안 고려사항

### 8.1 Discord Bot Token 보안
- Bot Token은 절대 클라이언트 코드에 포함하지 말 것
- Firebase Functions 환경 변수로만 관리
- 정기적으로 토큰 재생성 권장

### 8.2 사용자 데이터 보호
- Discord ID는 필요한 경우에만 수집
- 사용자가 연결 해제 가능하도록 구현
- GDPR 및 개인정보보호법 준수

---

## 📊 9단계: 모니터링

### 9.1 Firebase Console 확인 사항
- Authentication 사용자 수 증가
- Firestore `users` 컬렉션의 Discord 필드 채워짐
- Functions 로그에서 채널 생성 성공 메시지

### 9.2 Discord 서버 확인 사항
- 토너먼트별 채널 정상 생성
- 권한 설정 올바른지 확인
- 사용하지 않는 채널 정리

---

## 🎉 완료!

Discord OAuth2 인증과 비공개 채널 생성 시스템이 정상적으로 구축되었습니다!

### ✅ 달성한 기능들
- Discord 계정으로 회원가입/로그인
- 사용자별 Discord 정보 저장
- 권한 기반 비공개 Discord 채널 자동 생성
- 토너먼트 참가자들만 접근 가능한 보안 채널
- 앱 내 채팅과 Discord 채널의 이중 시스템

### 🚀 추가 개선 가능사항
- Discord 서버 부스트 상태에 따른 음성 품질 향상
- 토너먼트 결과에 따른 채널 자동 아카이브
- Discord Rich Presence 연동
- 토너먼트 일정 Discord 이벤트 자동 생성

---

📞 **지원이 필요하시면 개발팀에 문의해주세요!** 