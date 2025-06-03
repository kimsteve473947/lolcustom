# Firebase 설정 가이드

이 문서는 LoL 내전 매니저 앱의 Firebase 설정 및 권한 문제 해결 방법을 설명합니다.

## 권한 오류 해결하기

애플리케이션에서 다음과 같은 오류가 발생하는 경우:

```
토너먼트 참가 중 오류가 발생했습니다: [cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.
```

이는 Firebase 보안 규칙이 해당 작업을 허용하지 않기 때문입니다. 다음 단계를 따라 이 문제를 해결하세요.

### 1. Firebase 콘솔 접속

1. [Firebase 콘솔](https://console.firebase.google.com/)에 접속합니다.
2. 해당 프로젝트를 선택합니다.

### 2. Firestore 보안 규칙 수정

1. 왼쪽 메뉴에서 "Firestore Database"를 선택합니다.
2. 상단 탭에서 "Rules" 탭을 클릭합니다.
3. 기존 규칙을 삭제하고 아래의 새로운 규칙으로 교체합니다:

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

4. "Publish" 버튼을 클릭하여 변경사항을 저장합니다.

### 3. 변경 사항 설명

이 보안 규칙은 다음과 같은 변경 사항을 포함합니다:

1. **토너먼트 업데이트 권한 개선**:
   - 토너먼트 호스트는 모든 필드를 업데이트할 수 있습니다.
   - 일반 사용자는 참가 관련 필드(`participants`, `participantsByRole`, `filledSlots`, `filledSlotsByRole`, `status`, `updatedAt`)만 업데이트할 수 있습니다.

2. **신청서 관리 권한 추가**:
   - 신청서 생성은 로그인한 사용자만 가능하며, 자신의 신청서만 생성할 수 있습니다.
   - 신청서 업데이트 및 삭제는 신청자 본인 또는 토너먼트 호스트만 가능합니다.

3. **헬퍼 함수 추가**:
   - `isSignedIn()`: 로그인 여부 확인
   - `isOwner()`: 사용자 소유 여부 확인
   - `isTournamentHost()`: 토너먼트 호스트 여부 확인

## 문제 해결

보안 규칙을 업데이트한 후에도 문제가 계속 발생하는 경우 다음 사항을 확인하세요:

### 1. Firebase 콘솔에서 오류 확인

1. Firebase 콘솔의 "Firestore Database" 섹션으로 이동합니다.
2. "Monitoring" 탭을 선택합니다.
3. "Denied" 요청을 검토하여 실패한 요청에 대한 자세한 정보를 확인합니다.

### 2. 앱 코드 확인

1. `lib/services/firebase_service.dart` 파일을 확인하세요.
2. `joinTournamentByRole` 메서드에서 트랜잭션이 올바르게 구현되어 있는지 확인하세요.
3. 사용자가 로그인되어 있는지 확인하세요.

### 3. 데이터 구조 확인

1. Firebase 콘솔에서 데이터 구조를 확인하세요.
2. 특히 다음 필드가 올바르게 구성되어 있는지 확인하세요:
   - `tournaments` 컬렉션의 문서에 `hostUid` 필드가 있는지
   - `participantsByRole` 맵 구조가 올바른지
   - `filledSlotsByRole` 맵 구조가 올바른지

## Firebase 인덱스 설정

복잡한 쿼리가 있는 경우 인덱스를 설정해야 할 수 있습니다. 일반적으로 필요한 인덱스는 다음과 같습니다:

1. **토너먼트 쿼리용 인덱스**:
   - 컬렉션: `tournaments`
   - 필드: `status`, `startsAt` (Ascending)

2. **용병 쿼리용 인덱스**:
   - 컬렉션: `mercenaries`
   - 필드: `isAvailable` (Ascending), `lastActiveAt` (Descending)

인덱스는 Firebase 콘솔의 "Firestore Database" > "Indexes" 탭에서 추가할 수 있습니다.

## 추가 보안 고려 사항

1. **데이터 검증**: 클라이언트 측 검증 외에도 서버 측 검증을 추가하는 것이 좋습니다. Firebase Cloud Functions를 사용하여 중요한 작업에 대한 추가 검증을 구현하세요.

2. **속도 제한**: 남용을 방지하기 위해 특정 작업에 대한 속도 제한을 설정하세요.

3. **보안 테스트**: Firebase의 보안 규칙 시뮬레이터를 사용하여 다양한 시나리오에서 규칙을 테스트하세요.

## 참조 문서

- [Firebase 보안 규칙 문서](https://firebase.google.com/docs/firestore/security/get-started)
- [보안 규칙 테스트 방법](https://firebase.google.com/docs/firestore/security/test-rules)
- [트랜잭션 및 일괄 쓰기](https://firebase.google.com/docs/firestore/manage-data/transactions) 