#!/bin/bash

# FirebaseStorage Swift 파일 직접 수정 스크립트

PROJECT_ROOT="$1"
STORAGE_SWIFT="${PROJECT_ROOT}/ios/Pods/FirebaseStorage/FirebaseStorage/Sources/Storage.swift"

if [ -f "$STORAGE_SWIFT" ]; then
  echo "FirebaseStorage Swift 파일 직접 수정 중..."
  
  # 임시 파일 생성
  TMP_FILE=$(mktemp)
  
  # Storage.swift 파일 내용 수정
  sed -i.bak '
    # provider.storage 수정 -> provider?.storage
    s/provider\.storage/provider?.storage/g
    
    # return provider.storage 수정 -> return provider!.storage
    s/return provider\.storage/return provider!.storage/g
    
    # let provider = Component 수정 -> let provider: StorageProvider?
    s/let provider = ComponentType<StorageProvider>/let provider: StorageProvider? = ComponentType<StorageProvider>/g
    
    # auth 옵셔널 처리
    s/auth: app.options.auth/auth: app.options.auth as? AuthInterop/g
    
    # appCheck 옵셔널 처리
    s/appCheck: app.options.appCheck/appCheck: app.options.appCheck as? AppCheckInterop/g
  ' "$STORAGE_SWIFT"
  
  echo "FirebaseStorage Swift 파일 수정 완료"
  
  # 권한 문제 해결 (필요 시)
  chmod 644 "$STORAGE_SWIFT"
else
  echo "FirebaseStorage Swift 파일을 찾을 수 없습니다: $STORAGE_SWIFT"
fi 