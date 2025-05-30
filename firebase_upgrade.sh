#!/bin/bash

# Firebase 패키지 업그레이드 스크립트

echo "=== Firebase 패키지 업그레이드 스크립트 ==="
echo "이 스크립트는 Firebase 패키지 버전을 조정하고 코드 호환성 문제를 해결합니다."
echo ""

# 1. Flutter 및 Dart 버전 확인
echo "=== Flutter 및 Dart 버전 확인 ==="
flutter --version
echo ""

# 2. pubspec.yaml 업데이트
echo "=== pubspec.yaml 업데이트 ==="
echo "Firebase 패키지 버전을 호환 가능한 버전으로 조정합니다."
echo "다음 내용을 pubspec.yaml에 추가하세요:"
echo ""
echo "dependencies:"
echo "  firebase_core: ^2.13.1"
echo "  firebase_auth: ^4.6.2"
echo "  cloud_firestore: ^4.8.0"
echo "  firebase_storage: ^11.2.2"
echo "  firebase_messaging: ^14.6.2"
echo "  js: ^0.6.3"
echo ""

# 3. 패키지 업데이트
echo "=== 패키지 업데이트 실행 ==="
read -p "pubspec.yaml을 업데이트하셨나요? (y/n): " updated_pubspec
if [ "$updated_pubspec" = "y" ]; then
  echo "패키지를 업데이트합니다..."
  flutter pub get
else
  echo "pubspec.yaml을 먼저 업데이트한 후 다시 실행해주세요."
  exit 1
fi
echo ""

# 4. 모델 클래스 업데이트 안내
echo "=== 모델 클래스 업데이트 안내 ==="
echo "1. Timestamp를 DateTime으로 변환하는 유틸리티 메서드 추가"
echo "   예: DateTime safeTimestampToDateTime(dynamic timestamp) {"
echo "         if (timestamp == null) return DateTime.now();"
echo "         return timestamp is Timestamp ? timestamp.toDate() : DateTime.parse(timestamp.toString());"
echo "       }"
echo ""
echo "2. RatingModel에 stars 필드 추가"
echo "   예: final int stars;"
echo "       RatingModel(..., {int? stars}) : stars = stars ?? score.round();"
echo ""
echo "3. nullable 필드에 대한 안전한 처리 추가"
echo "   예: (model.averageRating ?? 0.0).toStringAsFixed(1)"
echo ""

# 5. UI 관련 변경 안내
echo "=== UI 관련 변경 안내 ==="
echo "1. CardTheme을 CardThemeData로 변경"
echo "   예: cardTheme: const CardThemeData(...)"
echo ""
echo "2. fold 연산자 문제 해결"
echo "   예: '총 \${_slotsByRole.values.cast<int>().fold(0, (p, c) => p + c)}명'"
echo ""

# 6. 테스트 실행
echo "=== 테스트 실행 ==="
read -p "모든 변경을 완료하셨나요? 앱을 실행해보시겠습니까? (y/n): " run_app
if [ "$run_app" = "y" ]; then
  echo "앱을 실행합니다..."
  flutter run
else
  echo "변경 사항을 모두 적용한 후 'flutter run' 명령어로 앱을 실행해보세요."
fi

echo ""
echo "Firebase 패키지 업그레이드 스크립트를 완료했습니다." 