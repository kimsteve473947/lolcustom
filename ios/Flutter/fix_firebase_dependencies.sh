#!/bin/bash

# Firebase 및 gRPC 관련 컴파일 문제 수정 스크립트

# 프로젝트 루트 디렉토리 설정
PROJECT_DIR="$1"
PODS_DIR="${PROJECT_DIR}/ios/Pods"

# BoringSSL 컴파일 플래그 수정
if [ -d "${PODS_DIR}/BoringSSL-GRPC" ]; then
  echo "Patching BoringSSL-GRPC to work on arm64 simulator..."
  
  # .podspec 파일 수정
  BORING_SSL_PODSPEC="${PODS_DIR}/BoringSSL-GRPC/BoringSSL-GRPC.podspec"
  if [ -f "${BORING_SSL_PODSPEC}" ]; then
    sed -i '' 's/-fembed-bitcode//' "${BORING_SSL_PODSPEC}"
    sed -i '' 's/-Werror//' "${BORING_SSL_PODSPEC}"
  fi
  
  # 헤더 파일 수정
  find "${PODS_DIR}/BoringSSL-GRPC" -name "*.h" -type f -exec sed -i '' 's/-G/-GG/g' {} \;
  
  # 소스 파일 수정
  find "${PODS_DIR}/BoringSSL-GRPC" -name "*.c" -type f -exec sed -i '' 's/-G/-GG/g' {} \;
  find "${PODS_DIR}/BoringSSL-GRPC" -name "*.cc" -type f -exec sed -i '' 's/-G/-GG/g' {} \;
  
  echo "BoringSSL-GRPC patching completed."
fi

# gRPC-Core 수정
if [ -d "${PODS_DIR}/gRPC-Core" ]; then
  echo "Patching gRPC-Core to work on arm64 simulator..."
  
  # 헤더 파일 수정
  find "${PODS_DIR}/gRPC-Core" -name "*.h" -type f -exec sed -i '' 's/-G/-GG/g' {} \;
  
  # 소스 파일 수정
  find "${PODS_DIR}/gRPC-Core" -name "*.c" -type f -exec sed -i '' 's/-G/-GG/g' {} \;
  find "${PODS_DIR}/gRPC-Core" -name "*.cc" -type f -exec sed -i '' 's/-G/-GG/g' {} \;
  
  echo "gRPC-Core patching completed."
fi

# Firebase Storage의 Swift 옵셔널 문제 해결
if [ -d "${PODS_DIR}/FirebaseStorage" ]; then
  echo "Patching FirebaseStorage Swift optional unwrapping issues..."
  
  # Storage.swift 파일 수정
  STORAGE_SWIFT="${PODS_DIR}/FirebaseStorage/FirebaseStorage/Sources/Storage.swift"
  if [ -f "${STORAGE_SWIFT}" ]; then
    sed -i '' 's/provider.storage/provider?.storage/g' "${STORAGE_SWIFT}"
    sed -i '' 's/auth: app.options.auth/auth: app.options.auth as? AuthInterop/g' "${STORAGE_SWIFT}"
    sed -i '' 's/appCheck: app.options.appCheck/appCheck: app.options.appCheck as? AppCheckInterop/g' "${STORAGE_SWIFT}"
  fi
  
  echo "FirebaseStorage patching completed."
fi

echo "All Firebase dependencies patched successfully." 