#!/bin/bash

# Script to upgrade Firebase in Flutter project

echo "=== 시작: Firebase와 Flutter 패키지 업그레이드 스크립트 ==="
echo "이 스크립트는 다음 작업을 수행합니다:"
echo "1. Flutter SDK와 Dart SDK 버전 확인"
echo "2. Firebase 패키지 및 웹 패키지 업그레이드"
echo "3. 새로운 Firebase 설정 파일 생성"
echo "4. 코드 API 변경 이슈 해결 도우미"
echo ""

# 1. 버전 확인
echo "=== Flutter 및 Dart 버전 확인 ==="
flutter --version
echo ""

# 2. pub upgrade 실행
echo "=== 패키지 업데이트 실행 ==="
flutter pub upgrade
echo ""

# 3. 새 Firebase 구성 생성
echo "=== Firebase 설정 업데이트 ==="
echo "Firebase CLI가 설치되어 있습니까? (y/n)"
read -r has_firebase_cli

if [ "$has_firebase_cli" = "y" ]; then
  echo "Firebase 프로젝트 설정 파일을 생성합니다..."
  flutter pub global activate flutterfire_cli
  flutterfire configure
else
  echo "나중에 Firebase CLI를 설치하고 'flutterfire configure'를 실행하세요."
fi

echo ""

# 4. 웹 빌드 테스트
echo "=== 웹 빌드 테스트 ==="
echo "웹 빌드를 테스트하시겠습니까? (y/n)"
read -r test_web_build

if [ "$test_web_build" = "y" ]; then
  echo "웹 빌드를 테스트합니다..."
  flutter build web --web-renderer html
else
  echo "나중에 'flutter build web --web-renderer html'을 실행하세요."
fi

echo ""

# 5. Firestore 모델 변환 가이드
echo "=== Firestore 모델 변환 가이드 ==="
echo "Firestore 모델을 업데이트하기 위한 체크리스트:"
echo "1. fromFirestore() -> fromMap() 메서드로 변경"
echo "2. toFirestore() -> toMap() 메서드로 변경"
echo "3. DocumentSnapshot 타입을 명시적으로 지정: DocumentSnapshot<Map<String, dynamic>>"
echo "4. Timestamp -> DateTime 변환: timestamp.toDate()"
echo "5. Null 안전성 확인: averageRating?.toStringAsFixed(1) 또는 (averageRating ?? 0.0).toStringAsFixed(1)"
echo "6. CardTheme -> CardThemeData로 변경"
echo "7. fold() 연산 시 타입 캐스팅: values.cast<int>().fold(0, (p, c) => p + c)"
echo ""

echo "=== 완료: Firebase와 Flutter 패키지 업그레이드 스크립트 ==="
echo "추가 문제가 발생하면 에러 메시지를 확인하고 필요한 코드 업데이트를 수행하세요." 