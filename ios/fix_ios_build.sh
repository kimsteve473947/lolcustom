#!/bin/bash

# 디렉토리 확인 및 생성
mkdir -p ios/fix_patches

# 현재 디렉토리 저장
PROJECT_ROOT=$(pwd)

echo "===== iOS 빌드 오류 수정 스크립트 시작 ====="

# 1. Flutter 패키지 가져오기
echo "Flutter 패키지 다시 가져오기..."
flutter pub get

# 2. 기존 Pods 디렉토리 삭제 (선택적)
echo "이전 Pod 설치 정리 중..."
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/Runner.xcworkspace

# 3. Pod 설치 준비 - 폴더 생성
echo "gRPC-Core 폴더 구조 준비 중..."
mkdir -p ios/Pods/gRPC-Core/include/grpc

# 4. gRPC 모듈맵 파일 미리 생성
echo "gRPC-Core module.modulemap 미리 생성 중..."
ruby ios/fix_patches/fix_grpc_modulemap.rb "$PROJECT_ROOT"

# 5. Pod 설치 수행
echo "Pod 새로 설치 중..."
cd ios
pod install
cd ..

# 6. 패치 스크립트 실행 권한 설정
echo "패치 스크립트 실행 권한 설정 중..."
chmod +x ios/fix_patches/*.rb
chmod +x ios/fix_patches/*.sh
chmod +x ios/Flutter/fix_firebase_dependencies.sh

# 7. Flutter Local Notifications 패키지 문제 수정
echo "Flutter Local Notifications 패키지 문제 수정 중..."
ruby ios/fix_patches/fix_flutter_notifications.rb "$PROJECT_ROOT"

# 8. gRPC 템플릿 문제 수정 (Ruby 스크립트)
echo "gRPC 템플릿 문제 수정 중..."
ruby ios/fix_patches/fix_grpc_template.rb "$PROJECT_ROOT"

# 9. basic_seq.h 직접 수정 (더 정확한 수정)
echo "basic_seq.h 직접 수정 중..."
bash ios/fix_patches/direct_fix_basic_seq.sh "$PROJECT_ROOT"

# 10. gRPC-Core module.modulemap 생성 확인
echo "gRPC-Core module.modulemap 확인 및 재생성..."
ruby ios/fix_patches/fix_grpc_modulemap.rb "$PROJECT_ROOT"

# 11. Firebase Storage Swift 파일 수정
if [ -f "$PROJECT_ROOT/ios/fix_patches/fix_firebase_storage.rb" ]; then
  echo "Firebase Storage Swift 문제 수정 중..."
  ruby ios/fix_patches/fix_firebase_storage.rb "$PROJECT_ROOT"
fi

# 12. 컴파일러 플래그 수정
if [ -f "$PROJECT_ROOT/ios/Flutter/fix_firebase_dependencies.sh" ]; then
  echo "Firebase 및 gRPC 컴파일러 플래그 수정 중..."
  bash ios/Flutter/fix_firebase_dependencies.sh "$PROJECT_ROOT"
fi

# 13. 모든 Xcode 플래그 수정
if [ -f "$PROJECT_ROOT/ios/fix_patches/fix_all_xcode_flags.sh" ]; then
  echo "Xcode 모든 플래그 수정 중..."
  bash ios/fix_patches/fix_all_xcode_flags.sh "$PROJECT_ROOT"
fi

# 14. Flutter 패키지 다시 가져오기
echo "Flutter 패키지 다시 가져오기..."
flutter pub get

# 15. 수정 후 다시 Pod 설치
echo "수정 후 Pod 재설치 중..."
cd ios
pod install
cd ..

# 16. 완료 메시지
echo "===== iOS 빌드 오류 수정 완료 ====="
echo "이제 'flutter run -d ios' 또는 Xcode에서 앱을 실행해보세요." 