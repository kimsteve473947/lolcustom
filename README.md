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

```bash
# FlutterFire CLI 설치
dart pub global activate flutterfire_cli

# Firebase 프로젝트 연결
flutterfire configure --project=your-firebase-project
```

4. 앱 실행

```bash
flutter run
```

## Firebase 설정 가이드

### 1. Firebase 프로젝트 생성

1. [Firebase Console](https://console.firebase.google.com/)에서 새 프로젝트 생성
2. Flutter 앱 등록 (안드로이드 및 iOS)
3. `google-services.json` 및 `GoogleService-Info.plist` 파일 다운로드
4. 앱의 Android 및 iOS 디렉토리에 각각 배치

### 2. Authentication 설정

1. Firebase Console에서 Authentication 섹션 열기
2. 이메일/비밀번호 로그인 활성화
3. Google 로그인 활성화 (선택사항)

### 3. Firestore 설정

1. Firebase Console에서 Firestore 데이터베이스 생성
2. 테스트 모드에서 시작 (나중에 보안 규칙 설정)
3. 다음 컬렉션 생성:
   - users
   - tournaments
   - applications
   - ratings
   - chatRooms
   - messages
   - mercenaries

### 4. Cloud Functions 설정

1. Firebase CLI 설치

```bash
npm install -g firebase-tools
```

2. 로그인 및 초기화

```bash
firebase login
firebase init functions
```

3. 아래 Cloud Functions 구현

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// 내전 참가자에게 알림 보내기
exports.notifyTournamentParticipants = functions.https.onCall(async (data, context) => {
  const { tournamentId, message } = data;
  
  // 인증 확인
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '인증이 필요합니다.');
  }
  
  try {
    // 내전 데이터 가져오기
    const tournamentDoc = await admin.firestore().collection('tournaments').doc(tournamentId).get();
    if (!tournamentDoc.exists) {
      throw new functions.https.HttpsError('not-found', '내전을 찾을 수 없습니다.');
    }
    
    // 알림 전송 로직 구현
    // ...
    
    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// 사용자 평가 업데이트
exports.updateUserRatings = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  try {
    // 모든 평가 가져오기
    const ratingsSnapshot = await admin.firestore().collection('ratings')
      .where('targetUid', '==', userId)
      .get();
    
    // 평점 계산
    let totalStars = 0;
    let count = 0;
    
    ratingsSnapshot.forEach(doc => {
      const rating = doc.data();
      totalStars += rating.stars;
      count++;
    });
    
    const averageRating = count > 0 ? totalStars / count : 0;
    
    // 사용자 평점 업데이트
    await admin.firestore().collection('users').doc(userId).update({
      averageRating: averageRating
    });
    
    // 용병 프로필이 있다면 업데이트
    const mercenarySnapshot = await admin.firestore().collection('mercenaries')
      .where('userUid', '==', userId)
      .get();
      
    if (!mercenarySnapshot.empty) {
      mercenarySnapshot.forEach(async doc => {
        await doc.ref.update({ averageRating: averageRating });
      });
    }
    
    return { success: true, averageRating };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// 내전 신청 처리
exports.processTournamentApplication = functions.https.onCall(async (data, context) => {
  const { tournamentId, userId, role } = data;
  
  // 인증 확인
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '인증이 필요합니다.');
  }
  
  try {
    // 내전 호스트에게 알림 전송
    // ...
    
    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// 만료된 내전 정리
exports.cleanupExpiredTournaments = functions.https.onCall(async (data, context) => {
  try {
    const now = admin.firestore.Timestamp.now();
    
    // 지난 내전 찾기
    const expiredTournamentsSnapshot = await admin.firestore().collection('tournaments')
      .where('startsAt', '<', now)
      .where('status', '==', 0) // open status
      .get();
    
    // 상태 업데이트
    const batch = admin.firestore().batch();
    expiredTournamentsSnapshot.forEach(doc => {
      batch.update(doc.ref, { status: 2 }); // inProgress status
    });
    
    await batch.commit();
    
    return { success: true, count: expiredTournamentsSnapshot.size };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// 채팅방 생성 및 알림 전송
exports.createChatRoomWithNotification = functions.https.onCall(async (data, context) => {
  const { participantIds, title, type, initialMessage } = data;
  
  // 인증 확인
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '인증이 필요합니다.');
  }
  
  try {
    // 채팅방 생성
    const chatRoomRef = admin.firestore().collection('chatRooms').doc();
    
    // 참가자 맵 생성
    const participants = {};
    participantIds.forEach(id => {
      participants[id] = true;
    });
    
    // 안읽은 메시지 맵 초기화
    const unreadCount = {};
    participantIds.forEach(id => {
      if (id !== context.auth.uid) {
        unreadCount[id] = 1; // 초기 메시지가 있으면 1, 없으면 0
      } else {
        unreadCount[id] = 0;
      }
    });
    
    await chatRoomRef.set({
      id: chatRoomRef.id,
      title,
      type,
      participantIds,
      participants, // 맵 형태로 저장
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageTime: initialMessage ? admin.firestore.FieldValue.serverTimestamp() : null,
      lastMessageText: initialMessage || null,
      unreadCount,
    });
    
    // 초기 메시지가 있으면 추가
    if (initialMessage) {
      const messageRef = admin.firestore().collection('messages').doc();
      await messageRef.set({
        id: messageRef.id,
        chatRoomId: chatRoomRef.id,
        senderId: context.auth.uid,
        senderName: (await admin.firestore().collection('users').doc(context.auth.uid).get()).data().nickname,
        text: initialMessage,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        readStatus: {
          [context.auth.uid]: true,
        },
      });
      
      // 다른 참가자들에게는 읽지 않음으로 표시
      participantIds.forEach(id => {
        if (id !== context.auth.uid) {
          messageRef.update({
            [`readStatus.${id}`]: false,
          });
        }
      });
    }
    
    // 알림 전송
    // ...
    
    return { success: true, chatRoomId: chatRoomRef.id };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// 주기적으로 만료된 내전 정리 (매일 자정에 실행)
exports.scheduledCleanupExpiredTournaments = functions.pubsub.schedule('0 0 * * *')
  .timeZone('Asia/Seoul')
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();
      
      // 지난 내전 찾기
      const expiredTournamentsSnapshot = await admin.firestore().collection('tournaments')
        .where('startsAt', '<', now)
        .where('status', '==', 0) // open status
        .get();
      
      // 상태 업데이트
      const batch = admin.firestore().batch();
      expiredTournamentsSnapshot.forEach(doc => {
        batch.update(doc.ref, { status: 2 }); // inProgress status
      });
      
      await batch.commit();
      
      console.log(`Updated ${expiredTournamentsSnapshot.size} expired tournaments`);
      return null;
    } catch (error) {
      console.error('Error cleaning up tournaments:', error);
      return null;
    }
  });
```

4. 함수 배포

```bash
firebase deploy --only functions
```

### 5. Cloud Messaging 설정

1. Firebase Console에서 Cloud Messaging 활성화
2. Android 및 iOS 앱에 대한 설정 완료
3. 알림 설정 추가

## Firestore 보안 규칙

아래 보안 규칙을 Cloud Firestore에 적용하세요:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 인증된 사용자만 접근 가능
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // 사용자 문서 접근 제한
    match /users/{userId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && request.auth.uid == userId;
    }
    
    // 내전 접근 제한
    match /tournaments/{tournamentId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
        (resource.data.hostUid == request.auth.uid);
    }
    
    // 채팅방 및 메시지 접근 제한
    match /chatRooms/{roomId} {
      allow read: if request.auth != null && 
        (resource.data.participants[request.auth.uid] == true);
      allow create: if request.auth != null;
      
      match /messages/{messageId} {
        allow read: if request.auth != null && 
          get(/databases/$(database)/documents/chatRooms/$(roomId)).data.participants[request.auth.uid] == true;
        allow create: if request.auth != null && 
          get(/databases/$(database)/documents/chatRooms/$(roomId)).data.participants[request.auth.uid] == true;
      }
    }
  }
}
```

## 문제 해결

### 종속성 오류

만약 `firebase_functions` 패키지와 관련된 오류가 발생하면, 올바른 패키지 이름이 `cloud_functions`이므로 아래와 같이 변경해주세요:

```yaml
dependencies:
  # Firebase
  firebase_core: ^2.24.2
  firebase_auth: ^4.16.0
  cloud_firestore: ^4.14.0
  firebase_storage: ^11.6.0
  firebase_messaging: ^14.7.10
  cloud_functions: ^4.6.0  # 올바른 패키지 이름
  firebase_analytics: ^10.8.0
```

### intl 패키지 충돌

Flutter의 `flutter_localizations` 패키지는 특정 버전의 `intl` 패키지를 요구합니다. 충돌이 발생하면 아래와 같이 업데이트하세요:

```yaml
dependencies:
  intl: ^0.20.2  # flutter_localizations와 호환되는 버전
```

## 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 연락처

질문이나 피드백이 있으시면 이메일로 연락해주세요: your.email@example.com 