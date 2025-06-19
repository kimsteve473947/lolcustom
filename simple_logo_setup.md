# 🎨 간단한 로고 설정 방법 (효율적)

## 1️⃣ 로고 파일 하나만 준비
```
assets/images/app_logo.png  (하나의 파일로 끝!)
```

## 2️⃣ 코드에서 직접 참조
```dart
// 어디서든 이렇게 사용
CircleAvatar(
  backgroundImage: AssetImage('assets/images/app_logo.png'),
)

// 또는 상수로 관리
class AppImages {
  static const logo = 'assets/images/app_logo.png';
}
```

## 3️⃣ 기존 코드 수정 (3곳만!)
1. `lib/screens/chat/direct_message_screen.dart` (2곳)
2. `lib/screens/mercenaries/mercenary_search_screen.dart` (1곳) 
3. `lib/screens/mercenaries/mercenary_registration_screen.dart` (1곳)

## 4️⃣ 앱 아이콘만 별도 처리
앱 아이콘은 플랫폼 요구사항상 여러 크기 필요:
- iOS: 아이콘 파일들 직접 교체
- Android: 아이콘 파일들 직접 교체

## ✅ 장점
- 💾 **저장공간 절약**: 하나의 파일만 사용
- 🚀 **빠른 로딩**: 캐시 효율성 최대화  
- 🔧 **관리 용이**: 파일 하나만 교체하면 끝
- 💰 **비용 절약**: 서버 저장공간 최소화 