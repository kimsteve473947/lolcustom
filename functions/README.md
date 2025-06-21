# Firebase Functions 환경설정 가이드

## Discord Bot 설정

이 프로젝트는 토너먼트 시작 시 자동으로 Discord 채널을 생성하는 기능을 제공합니다.

### 1. 환경변수 설정

개발 환경에서는 `.env` 파일을 사용할 수 있습니다:

```bash
# .env.example을 복사하여 .env 파일 생성
cp .env.example .env
```

`.env` 파일에 실제 값들을 입력하세요:

```
DISCORD_BOT_TOKEN=your_actual_discord_bot_token
DISCORD_GUILD_ID=your_discord_server_id
DISCORD_CATEGORY_ID=your_discord_category_id
```

### 2. Firebase Functions Config 설정 (프로덕션)

프로덕션 환경에서는 Firebase Functions config를 사용합니다:

```bash
firebase functions:config:set \
  discord.bot_token="YOUR_DISCORD_BOT_TOKEN" \
  discord.guild_id="YOUR_DISCORD_GUILD_ID" \
  discord.category_id="YOUR_DISCORD_CATEGORY_ID"
```

### 3. 설정 확인

```bash
# 현재 설정된 config 확인
firebase functions:config:get

# 특정 config만 확인
firebase functions:config:get discord
```

### 4. 배포

환경변수 변경 후에는 반드시 함수를 다시 배포해야 합니다:

```bash
firebase deploy --only functions
```

## Discord Bot Token 발급 방법

1. [Discord Developer Portal](https://discord.com/developers/applications) 접속
2. "New Application" 클릭하여 새 애플리케이션 생성
3. 왼쪽 메뉴에서 "Bot" 선택
4. "Add Bot" 클릭
5. "Token" 섹션에서 "Copy" 클릭하여 토큰 복사
6. Bot에 필요한 권한 설정:
   - Manage Channels
   - Create Instant Invite
   - Send Messages
   - View Channels

## Discord Server 설정

1. Discord 서버 ID 가져오기:
   - Discord에서 개발자 모드 활성화
   - 서버 우클릭 → "ID 복사"

2. 카테고리 ID 가져오기:
   - 원하는 카테고리 우클릭 → "ID 복사"

## 보안 주의사항

- `.env` 파일은 절대 Git에 커밋하지 마세요
- Discord Bot Token은 민감한 정보이므로 안전하게 관리하세요
- 프로덕션에서는 반드시 Firebase Functions config를 사용하세요

## 문제 해결

### 환경변수가 인식되지 않는 경우

1. Firebase Functions config 확인:
   ```bash
   firebase functions:config:get
   ```

2. 함수 재배포:
   ```bash
   firebase deploy --only functions
   ```

3. 로그 확인:
   ```bash
   firebase functions:log
   ```
