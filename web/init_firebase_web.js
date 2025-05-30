// Firebase 웹 초기화 스크립트
document.addEventListener('DOMContentLoaded', function() {
  // Firebase 구성 - firebase_options.dart의 값과 일치해야 함
  const firebaseConfig = {
    apiKey: "YOUR-WEB-API-KEY",
    authDomain: "YOUR-AUTH-DOMAIN",
    projectId: "YOUR-PROJECT-ID",
    storageBucket: "YOUR-STORAGE-BUCKET",
    messagingSenderId: "YOUR-SENDER-ID",
    appId: "YOUR-WEB-APP-ID"
  };

  // Firebase 초기화
  if (typeof firebase !== 'undefined') {
    firebase.initializeApp(firebaseConfig);
    console.log('Firebase Web initialized successfully');
  } else {
    console.error('Firebase SDK not loaded');
  }
}); 