// Firestore 규칙
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 사용자 인증 확인 함수
    function isAuthenticated() {
      return request.auth != null;
    }

    // 로그인 사용자의 uid 확인 함수
    function isUser(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    // 관리자 확인 함수 (관리자 uid 목록을 기반으로)
    function isAdmin() {
      return isAuthenticated() && 
        exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }

    // 유효한 사용자 필드 확인
    function hasValidUserFields() {
      let requiredFields = ['email', 'nickname', 'uid', 'joinedAt'];
      return requiredFields.hasAll(request.resource.data.keys);
    }

    // users 컬렉션 규칙
    match /users/{userId} {
      // 누구나 읽기 가능, 본인만 쓰기/업데이트 가능, 관리자도 가능
      allow read: if true;
      allow create: if isUser(userId) && hasValidUserFields();
      allow update: if isUser(userId) || isAdmin();
      allow delete: if isAdmin();
    }

    // tournaments 컬렉션 규칙
    match /tournaments/{tournamentId} {
      // 누구나 읽기 가능, 인증된 사용자만 생성 가능, 생성자/관리자만 업데이트/삭제 가능
      allow read: if true;
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() &&
        (resource.data.hostId == request.auth.uid || isAdmin());
      allow delete: if isAuthenticated() &&
        (resource.data.hostId == request.auth.uid || isAdmin());
    }

    // applications 컬렉션 규칙
    match /applications/{applicationId} {
      // 누구나 읽기 가능, 인증된 사용자만 생성 가능, 참가 신청자/호스트/관리자만 업데이트 가능
      allow read: if true;
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() &&
        (resource.data.userUid == request.auth.uid ||
         get(/databases/$(database)/documents/tournaments/$(resource.data.tournamentId)).data.hostId == request.auth.uid ||
         isAdmin());
      allow delete: if isAuthenticated() &&
        (resource.data.userUid == request.auth.uid ||
         get(/databases/$(database)/documents/tournaments/$(resource.data.tournamentId)).data.hostId == request.auth.uid ||
         isAdmin());
    }

    // chatRooms 컬렉션 규칙
    match /chatRooms/{chatRoomId} {
      // 참가자만 읽기 가능, 인증된 사용자만 생성 가능, 참가자만 업데이트 가능
      allow read: if isAuthenticated() &&
        (resource.data.participantIds.hasAny([request.auth.uid]) || isAdmin());
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() &&
        (resource.data.participantIds.hasAny([request.auth.uid]) || isAdmin());
      allow delete: if isAdmin();
    }

    // messages 컬렉션 규칙
    match /messages/{messageId} {
      // 관련 채팅방 참가자만 읽기 가능, 인증된 사용자만 생성 가능, 작성자만 업데이트/삭제 가능
      allow read: if isAuthenticated() &&
        (get(/databases/$(database)/documents/chatRooms/$(resource.data.chatRoomId)).data.participantIds.hasAny([request.auth.uid]) || isAdmin());
      allow create: if isAuthenticated() &&
        get(/databases/$(database)/documents/chatRooms/$(resource.data.chatRoomId)).data.participantIds.hasAny([request.auth.uid]);
      allow update, delete: if isAuthenticated() &&
        resource.data.senderId == request.auth.uid;
    }

    // ratings 컬렉션 규칙
    match /ratings/{ratingId} {
      // 누구나 읽기 가능, 인증된 사용자만 생성 가능, 작성자만 업데이트/삭제 가능
      allow read: if true;
      allow create: if isAuthenticated() && request.resource.data.raterId == request.auth.uid;
      allow update, delete: if isAuthenticated() && resource.data.raterId == request.auth.uid;
    }

    // 기본 규칙 - 모든 다른 컬렉션에 대해 관리자만 접근 가능
    match /{document=**} {
      allow read, write: if isAdmin();
    }
  }
}

// Storage 규칙
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // 사용자 프로필 이미지 규칙
    match /users/{userId}/profile.jpg {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // 토너먼트 이미지 규칙
    match /tournaments/{tournamentId}/{fileName} {
      allow read: if true;
      allow write: if request.auth != null &&
        exists(/databases/$(database)/documents/tournaments/$(tournamentId)) &&
        get(/databases/$(database)/documents/tournaments/$(tournamentId)).data.hostId == request.auth.uid;
    }

    // 일반 이미지 규칙
    match /images/{imageId} {
      allow read: if true;
      allow write: if request.auth != null;
    }

    // 기본 규칙 - 모든 다른 스토리지 경로에 대해 관리자만 접근 가능
    match /{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null && 
        exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }
  }
} 