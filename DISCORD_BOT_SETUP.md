# 🤖 Discord Bot 설정 가이드

LOL Custom Game Manager의 토너먼트 디스코드 봇 설정 방법입니다.

## 📋 기능 개요

- **자동 채널 생성**: 토너먼트 참가자가 10명이 되면 자동으로 디스코드 채널 생성
- **팀별 음성 채팅**: 팀 A, 팀 B 전용 음성 채널 제공
- **앱 연동**: 생성된 채널 초대 링크를 앱 내 메시지로 전송
- **자동 정리**: 토너먼트 종료 시 채널 자동 삭제

## 🛠️ 1. Discord 개발자 설정

### 1.1 Discord Application 생성
1. [Discord Developer Portal](https://discord.com/developers/applications)에 접속
2. **New Application** 클릭
3. 앱 이름 입력 (예: "LOL Tournament Bot")
4. **Create** 클릭

### 1.2 Bot 생성
1. 왼쪽 메뉴에서 **Bot** 클릭
2. **Add Bot** 클릭
3. **Reset Token** 클릭하여 봇 토큰 생성 및 복사 (나중에 사용)

### 1.3 Bot 권한 설정
**Bot** 페이지에서 다음 권한들을 활성화:
- `Send Messages`
- `Manage Channels`  
- `Create Invite`
- `View Channels`
- `Connect` (음성 채널용)
- `Speak` (음성 채널용)

### 1.4 OAuth2 URL 생성
1. 왼쪽 메뉴에서 **OAuth2 > URL Generator** 클릭
2. **Scopes**에서 `bot` 선택
3. **Bot Permissions**에서 위에서 설정한 권한들 선택
4. 생성된 URL을 복사하여 디스코드 서버에 봇 초대

## 🏠 2. Discord 서버 설정

### 2.1 서버 정보 수집
다음 정보들을 수집해주세요:

1. **서버 ID (Guild ID)**:
   ```
   서버 설정 > 고급 > 개발자 모드 활성화
   서버 이름 우클릭 > ID 복사
   ```

2. **카테고리 ID (선택사항)**:
   ```
   토너먼트 채널들을 정리할 카테고리 생성
   카테고리 우클릭 > ID 복사
   ```

## 🔧 3. Firebase Functions 환경변수 설정

다음 명령어들을 터미널에서 실행하여 환경변수를 설정합니다:

```bash
# Firebase 프로젝트 선택
firebase use lolcustom-3d471

# Discord 봇 토큰 설정
firebase functions:config:set discord.bot_token="YOUR_BOT_TOKEN_HERE"

# Discord 서버 ID 설정  
firebase functions:config:set discord.guild_id="YOUR_GUILD_ID_HERE"

# Discord 카테고리 ID 설정 (선택사항)
firebase functions:config:set discord.category_id="YOUR_CATEGORY_ID_HERE"

# 설정 확인
firebase functions:config:get
```

### 로컬 개발용 환경변수
로컬에서 테스트할 경우 `functions/.env` 파일을 생성:

```env
DISCORD_BOT_TOKEN=your_bot_token_here
DISCORD_GUILD_ID=your_guild_id_here
DISCORD_CATEGORY_ID=your_category_id_here
```

## 🚀 4. Firebase Functions 배포

```bash
# 패키지 설치
cd functions
npm install

# 빌드
npm run build

# 배포
firebase deploy --only functions
```

## 📱 5. 앱 연동 확인사항

### 5.1 토너먼트 모델 업데이트
토너먼트 모델에 다음 필드들이 포함되어야 합니다:

```dart
class TournamentModel {
  // ... 기존 필드들
  
  // Discord 채널 정보
  final Map<String, dynamic>? discordChannels;
  
  TournamentModel({
    // ... 기존 파라미터들
    this.discordChannels,
  });
}
```

### 5.2 UI 컴포넌트
디스코드 채널 링크를 표시할 UI가 필요합니다:

```dart
// 토너먼트 상세 화면에서
if (tournament.discordChannels != null) {
  _buildDiscordChannelsSection(tournament.discordChannels!);
}

Widget _buildDiscordChannelsSection(Map<String, dynamic> channels) {
  return Column(
    children: [
      _buildChannelLink('💬 텍스트 채팅', channels['textChannelInvite']),
      _buildChannelLink('🎤 팀 A 음성', channels['voiceChannel1Invite']),
      _buildChannelLink('🎤 팀 B 음성', channels['voiceChannel2Invite']),
    ],
  );
}
```

## 🧪 6. 테스트 방법

### 6.1 수동 테스트 함수
개발 중에는 수동으로 디스코드 채널을 생성할 수 있습니다:

```dart
// Flutter 앱에서
final result = await FirebaseFunctions.instance
    .httpsCallable('createDiscordChannelsManually')
    .call({'tournamentId': 'test_tournament_id'});
```

### 6.2 실제 테스트 시나리오
1. 토너먼트 생성
2. 참가자 9명까지 추가 (채널 생성되지 않음)
3. 10번째 참가자 추가 (채널 자동 생성)
4. 앱에서 시스템 메시지 확인
5. 디스코드 링크 클릭하여 접속 확인

## 🔍 7. 로그 모니터링

```bash
# Firebase Functions 로그 확인
firebase functions:log

# 특정 함수 로그만 확인
firebase functions:log --only onTournamentParticipantChange
```

## 🚨 8. 문제 해결

### 8.1 봇이 서버에 접속하지 않는 경우
- 봇 토큰이 올바른지 확인
- 봇이 서버에 초대되었는지 확인
- 봇 권한이 충분한지 확인

### 8.2 채널 생성이 안 되는 경우
- 서버 ID가 올바른지 확인
- 봇이 채널 생성 권한을 가지고 있는지 확인
- Firebase Functions 로그 확인

### 8.3 초대 링크가 작동하지 않는 경우
- 링크 만료 시간 확인 (기본 7일)
- 사용 횟수 제한 확인
- 봇이 초대 생성 권한을 가지고 있는지 확인

## 📊 9. 모니터링 대시보드

Firebase Console에서 다음 지표들을 모니터링할 수 있습니다:

- 함수 호출 횟수
- 에러 발생률
- 실행 시간
- 메모리 사용량

## 🔒 10. 보안 고려사항

- 봇 토큰을 절대 코드에 하드코딩하지 마세요
- 환경변수로만 관리하세요
- 정기적으로 토큰을 재생성하세요
- 최소 권한 원칙을 적용하세요

---

## 📞 지원

문제가 발생하면 다음을 확인해주세요:

1. Firebase Functions 로그
2. Discord 개발자 포털 설정
3. 환경변수 설정
4. 봇 권한 설정

추가 도움이 필요하면 개발팀에 문의해주세요! 🚀 