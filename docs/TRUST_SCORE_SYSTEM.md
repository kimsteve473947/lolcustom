# 신뢰 점수 시스템 설정 가이드

## 개요
LOL 커스텀 게임 매니저의 신뢰 점수 시스템은 커뮤니티의 품질을 유지하기 위한 핵심 기능입니다.

## 시스템 구성 요소

### 1. Flutter UI 컴포넌트
- **평가 화면** (`lib/screens/evaluation/evaluation_screen.dart`)
  - 다중 체크박스 방식의 평가 UI
  - 긍정/부정 평가 항목 분리
  - 실시간 평가 결과 미리보기

- **신뢰 점수 위젯** (`lib/widgets/trust_score_widget.dart`)
  - 점수별 색상 표시 (90+: 녹색, 70-89: 파란색, 50-69: 주황색, 0-49: 빨간색)
  - 문구 뱃지 표시 (우수/양호/주의/위험)

- **홈 화면 배너** (`lib/screens/tournaments/tournament_main_screen.dart`)
  - 평가 대기 중인 토너먼트 표시
  - 평가 참여 유도 UI

### 2. 백엔드 서비스

#### EvaluationService (`lib/services/evaluation_service.dart`)
- 평가 제출 및 검증
- 신뢰 점수 계산 로직
- 이상치 감지 및 보정
- 악의적 패턴 탐지

#### TrustScoreManager (`lib/services/trust_score_manager.dart`)
- 통합 신뢰 점수 관리
- 평가 알림 예약
- 24시간 자동 처리
- 통계 생성

### 3. Firebase Functions

#### FCM 푸시 알림 (`functions/src/fcm.ts`)
```typescript
// FCM 메시지 전송
export const sendFCMMessage = functions.firestore
  .document('fcm_messages/{messageId}')
  .onCreate(async (snap, context) => {
    // FCM 메시지 전송 로직
  });

// 예약된 평가 알림 (매시간 실행)
export const sendScheduledEvaluationNotifications = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    // 2시간 후 알림 전송
  });

// 24시간 미평가 처리 (매일 자정)
export const processExpiredEvaluations = functions.pubsub
  .schedule('every day 00:00')
  .timeZone('Asia/Seoul')
  .onRun(async (context) => {
    // 미평가 사용자 평가율 감소
  });
```

## 설정 방법

### 1. Firebase 프로젝트 설정

1. Firebase Console에서 Cloud Messaging 활성화
2. iOS/Android 앱에 FCM 설정 추가
3. Functions 배포:
```bash
cd functions
npm install
firebase deploy --only functions
```

### 2. Firestore 인덱스 생성

```bash
firebase deploy --only firestore:indexes
```

필요한 인덱스:
- `users` 컬렉션: hostScore, playerScore, maliciousPatternDetected, role
- `tournaments` 컬렉션: status + completedAt + evaluationProcessed
- `scheduled_notifications` 컬렉션: sent + scheduledAt
- `evaluations` 컬렉션 그룹: fromUserId + createdAt, targetUserId + isHost + createdAt

### 3. 앱 초기화

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // TrustScoreManager 초기화
  TrustScoreManager().initialize();
  
  // FCM 토큰 업데이트
  final fcmToken = await FirebaseMessaging.instance.getToken();
  if (fcmToken != null) {
    await FirebaseFunctions.instance
        .httpsCallable('updateFCMToken')
        .call({'token': fcmToken});
  }
  
  runApp(MyApp());
}
```

## 점수 계산 로직

### 기본 점수
- 초기 점수: 80점
- 최소 점수: 0점
- 최대 점수: 100점

### 가중치
- 높은 신뢰도 사용자: 1.2
- 일반 사용자: 1.0
- 낮은 신뢰도 사용자: 0.7
- 악의적 패턴 감지: 0.0

### 점수 변화 공식
```
새로운 점수 = (기존 점수 × 감쇠율) + (평가 점수 × 가중치 × (1 - 감쇠율))
```

### 이상치 보정
- 상위/하위 10% 평가 제외
- 최근 10개 게임 기준 계산
- 평가율 30% 미만 시 점수 반영 50% 감소

### 악의적 패턴 감지
- 연속 5회 이상 극단적 평가
- 모든 평가가 동일한 패턴
- 평가 시간 간격이 비정상적으로 짧음

## 관리자 도구

### 신뢰 점수 관리 화면 (`lib/screens/admin/trust_score_admin_screen.dart`)

1. **통계 탭**
   - 평균 주최자/참가자 점수
   - 평가 참여율
   - 점수 분포 차트

2. **낮은 점수 탭**
   - 50점 미만 사용자 목록
   - 점수 재계산
   - 경고 발송

3. **악의적 사용자 탭**
   - 패턴 감지된 사용자
   - 가중치 복원
   - 계정 정지

4. **설정 탭**
   - 전체 점수 재계산
   - 평가 미참여 처리
   - 알림 전송

## 모니터링

### Firebase Console
- Functions 로그 확인
- Firestore 사용량 모니터링
- FCM 전송 통계

### 주요 지표
- 일일 평가 참여율
- 평균 신뢰 점수 추이
- 악의적 패턴 감지 빈도
- FCM 전송 성공률

## 문제 해결

### 평가가 반영되지 않을 때
1. Firestore 인덱스 확인
2. Functions 로그 확인
3. 사용자 권한 확인

### FCM 알림이 오지 않을 때
1. 사용자 FCM 토큰 확인
2. 앱 알림 권한 확인
3. Functions 로그 확인

### 점수 계산 오류
1. EvaluationService 로그 확인
2. 이상치 보정 로직 검토
3. 가중치 설정 확인

## 보안 고려사항

1. **평가 검증**
   - 자기 자신 평가 방지
   - 중복 평가 방지
   - 토너먼트 참가자만 평가 가능

2. **점수 조작 방지**
   - 서버 사이드 계산
   - 트랜잭션 사용
   - 감사 로그 기록

3. **개인정보 보호**
   - 평가 내용 익명화
   - 최소한의 정보만 저장
   - GDPR 준수 