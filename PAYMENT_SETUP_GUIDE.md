# 🚀 토스페이먼츠 연동 설정 가이드

## 📋 개요
이 가이드는 LOL 커스텀 게임 매니저 앱에 토스페이먼츠 결제 시스템을 연동하는 방법을 설명합니다.

## 🔧 문제 해결 내역

### ✅ 해결된 문제들
1. **PaymentModel 파싱 오류** - enum 안전성 확보
2. **토스페이먼츠 웹뷰 URL 스킴** - 실제 앱 동작 가능하도록 수정
3. **크레딧 내역 탭 UI** - 상태별 아이콘, 색상, 에러 표시 개선
4. **Firebase Functions 오류 처리** - 환경 변수 검증 및 트랜잭션 안전성 강화

## 🔑 Firebase 환경 설정

### 1. 토스페이먼츠 시크릿 키 설정
```bash
# 개발/테스트용
firebase functions:config:set toss.secret_key="test_sk_zXLkKEypNArWmo50nX3lmeaxYG5R"

# 실제 운영용 (토스페이먼츠에서 발급받은 실제 키 사용)
firebase functions:config:set toss.secret_key="YOUR_ACTUAL_SECRET_KEY"
```

### 2. 설정 확인
```bash
firebase functions:config:get
```

### 3. Functions 배포
```bash
firebase deploy --only functions
```

## 📱 클라이언트 키 설정

### CreditChargeScreen에서 사용되는 클라이언트 키
```dart
// lib/screens/my_page/credit_charge_screen.dart
final String _tossClientKey = 'test_ck_Poxy1XQL8RJo12Y4P0eN87nO5Wml'; // 테스트용
// 실제 운영시에는 토스페이먼츠에서 발급받은 실제 클라이언트 키로 변경
```

## 🔄 결제 플로우

### 1. 결제 요청 과정
```
사용자 크레딧 선택 → createPayment 함수 호출 → orderId 생성 → 웹뷰 결제 화면
```

### 2. 결제 승인 과정
```
토스 결제 완료 → 앱으로 리다이렉트 → approvePayment 함수 호출 → 크레딧 지급
```

### 3. 웹훅 처리 (선택사항)
```
토스페이먼츠 서버 → handleTossWebhook → 자동 크레딧 지급
```

## 🛠️ 커스텀 URL 스킴 설정

### Android (android/app/src/main/AndroidManifest.xml)
```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme">
    
    <!-- 기존 intent-filter -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
    
    <!-- 결제 리다이렉트용 intent-filter 추가 -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="lolcustomgame" />
    </intent-filter>
</activity>
```

### iOS (ios/Runner/Info.plist)
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>lolcustomgame</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>lolcustomgame</string>
        </array>
    </dict>
</array>
```

## 🧪 테스트 방법

### 1. 개발 환경 테스트
```bash
# Functions 로컬 실행
firebase emulators:start --only functions

# 앱에서 테스트 결제 진행
# 테스트 카드: 4242-4242-4242-4242
```

### 2. 결제 상태 확인
```dart
// Firestore에서 payments 컬렉션 확인
// 상태값: 0(시도), 1(완료), 2(실패), 3(취소)
```

## 📊 모니터링

### Firebase Console에서 확인할 사항
1. **Functions 로그** - 결제 처리 과정 추적
2. **Firestore payments 컬렉션** - 결제 내역 확인
3. **Firestore users 컬렉션** - 크레딧 변동 확인

### 주요 로그 메시지
- `✅ Payment created` - 결제 생성 성공
- `🔄 Approving payment` - 결제 승인 시작
- `✅ Payment approved` - 결제 승인 완료
- `❌ Payment failed` - 결제 실패

## 🚨 트러블슈팅

### 1. "Payment system is not properly configured" 오류
```bash
# 환경 변수 재설정
firebase functions:config:set toss.secret_key="YOUR_SECRET_KEY"
firebase deploy --only functions
```

### 2. "크레딧 내역을 불러오는 중 오류가 발생했습니다"
- PaymentModel 개선으로 해결됨
- 기존 잘못된 데이터가 있다면 Firestore에서 수동 정리 필요

### 3. 웹뷰에서 결제 완료 후 앱으로 돌아오지 않음
- 커스텀 URL 스킴 설정 확인
- 앱 재설치 후 테스트

### 4. Functions 실행 오류
```bash
# 로그 확인
firebase functions:log

# 재배포
firebase deploy --only functions --force
```

## 💡 추가 개선사항

### 1. 보안 강화
- 웹훅 서명 검증 구현
- IP 화이트리스트 설정

### 2. 사용자 경험 개선
- 결제 진행 상태 표시
- 오프라인 시 재시도 로직

### 3. 모니터링 강화
- 결제 실패율 추적
- 알림 시스템 구축

---

## 📞 지원

문제가 발생하면 다음을 확인해주세요:
1. Firebase Functions 로그
2. 앱 디버그 로그
3. 토스페이먼츠 개발자 문서: https://docs.tosspayments.com/

**설정 완료 후 앱을 재시작하여 변경사항을 적용하세요!** 🎉 