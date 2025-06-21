# Firebase 보안 가이드

## 🚨 현재 보안 상태

현재 `lib/firebase_options.dart`에 실제 Firebase API 키들이 하드코딩되어 있습니다. 이는 개발 단계에서는 일반적이지만, 프로덕션 환경에서는 추가적인 보안 조치가 필요합니다.

## 🔐 Firebase API 키의 특성

### 상대적으로 안전한 이유:
- **Public Key**: Firebase Web API 키는 공개되어도 상대적으로 안전
- **Security Rules**: 실제 데이터 보안은 Firestore/Storage Rules에서 관리
- **App 번들 제한**: 모바일 앱은 번들 ID/패키지명으로 제한됨

### 여전히 위험한 이유:
- **API 할당량 남용**: 악의적 사용자가 API 호출로 비용 발생
- **프로젝트 정보 노출**: 프로젝트 구조 정보 노출
- **무분별한 접근**: 제한되지 않은 클라이언트 접근

## 🛡️ 보안 강화 방법

### 1. Firebase App Check 활성화 (권장)
Firebase Console에서 App Check를 활성화하여 검증된 앱만 Firebase 서비스에 접근하도록 제한

### 2. API 키 제한 설정
Firebase Console → 프로젝트 설정 → 일반 → 웹 API 키에서:
- **HTTP 리퍼러**: 허용된 도메인만 설정
- **IP 주소**: 필요시 특정 IP만 허용
- **Android 앱**: 패키지명과 SHA-1 지문 확인
- **iOS 앱**: 번들 ID 확인

### 3. Firestore Security Rules 강화
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 인증된 사용자만 접근
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // 사용자별 데이터 제한
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## ⚡ 즉시 적용 가능한 보안 조치

### 1. Firebase Console 설정:
1. Firebase Console → 프로젝트 설정
2. 일반 탭 → 웹 API 키 제한 설정
3. App Check 탭 → App Check 활성화
4. 사용량 탭 → 할당량 및 알림 설정

### 2. 권장사항:
- ✅ API 키 제한 설정
- ✅ Firestore Security Rules 강화
- ✅ Firebase Storage Rules 강화
- ✅ 사용량 모니터링 설정
- 🔄 Firebase App Check 활성화
- 📋 정기적인 보안 감사

## 🔗 참고 자료
- [Firebase Security Rules 가이드](https://firebase.google.com/docs/rules)
- [Firebase App Check 문서](https://firebase.google.com/docs/app-check)
- [Firebase API 키 보안](https://firebase.google.com/docs/projects/api-keys)
