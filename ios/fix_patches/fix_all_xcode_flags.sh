#!/bin/bash

# 프로젝트 루트 디렉토리
PROJECT_ROOT="$1"
PODS_DIR="${PROJECT_ROOT}/ios/Pods"

# Xcode 빌드 설정 수정
echo "Updating Xcode build settings to fix compiler issues..."

# 1. BoringSSL 및 gRPC 소스 파일 수정
find "${PODS_DIR}" -name "*.c" -o -name "*.cc" -o -name "*.h" | xargs sed -i '' 's/-G/-GG/g'

# 2. Xcode project.pbxproj 파일 수정
PROJECT_FILE="${PROJECT_ROOT}/ios/Runner.xcodeproj/project.pbxproj"
if [ -f "$PROJECT_FILE" ]; then
  echo "Updating Runner.xcodeproj/project.pbxproj..."
  
  # OTHER_CFLAGS에 OPENSSL_NO_ASM=1 추가
  sed -i '' 's/OTHER_CFLAGS = "-fembed-bitcode"/OTHER_CFLAGS = "-fembed-bitcode -DOPENSSL_NO_ASM=1"/g' "$PROJECT_FILE"
  
  # -G 플래그 제거
  sed -i '' 's/-G[^ ]*//g' "$PROJECT_FILE"
  
  echo "Runner.xcodeproj updated."
fi

# 3. Pods.xcodeproj project.pbxproj 파일 수정
PODS_PROJECT_FILE="${PODS_DIR}/Pods.xcodeproj/project.pbxproj"
if [ -f "$PODS_PROJECT_FILE" ]; then
  echo "Updating Pods.xcodeproj/project.pbxproj..."
  
  # OTHER_CFLAGS와 OTHER_CPLUSPLUSFLAGS에 OPENSSL_NO_ASM=1 추가
  sed -i '' 's/OTHER_CFLAGS = (/OTHER_CFLAGS = ("-DOPENSSL_NO_ASM=1", /g' "$PODS_PROJECT_FILE"
  sed -i '' 's/OTHER_CPLUSPLUSFLAGS = (/OTHER_CPLUSPLUSFLAGS = ("-DOPENSSL_NO_ASM=1", /g' "$PODS_PROJECT_FILE"
  
  # -G 플래그 제거
  sed -i '' 's/-G[^ ,)]*//g' "$PODS_PROJECT_FILE"
  
  echo "Pods.xcodeproj updated."
fi

# 4. Firebase Storage Swift 파일 수정
STORAGE_SWIFT="${PODS_DIR}/FirebaseStorage/FirebaseStorage/Sources/Storage.swift"
if [ -f "$STORAGE_SWIFT" ]; then
  echo "Patching FirebaseStorage Swift file..."
  
  # Provider?.storage로 수정
  sed -i '' 's/provider.storage/provider?.storage/g' "$STORAGE_SWIFT"
  sed -i '' 's/let provider = ComponentType<StorageProvider>/let provider: StorageProvider? = ComponentType<StorageProvider>/g' "$STORAGE_SWIFT"
  sed -i '' 's/return provider.storage/return provider!.storage/g' "$STORAGE_SWIFT"
  
  # 옵셔널 처리
  sed -i '' 's/auth: app.options.auth/auth: app.options.auth as? AuthInterop/g' "$STORAGE_SWIFT"
  sed -i '' 's/appCheck: app.options.appCheck/appCheck: app.options.appCheck as? AppCheckInterop/g' "$STORAGE_SWIFT"
  
  # StorageImpl 클래스 수정
  sed -i '' 's/var auth: AuthInterop/var auth: AuthInterop?/g' "$STORAGE_SWIFT"
  sed -i '' 's/var appCheck: AppCheckInterop/var appCheck: AppCheckInterop?/g' "$STORAGE_SWIFT"
  
  echo "FirebaseStorage Swift file patched."
fi

echo "All Xcode build settings have been updated successfully." 