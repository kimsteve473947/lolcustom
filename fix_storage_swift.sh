#!/bin/bash

# FirebaseStorage의 Storage.swift 파일 수정 스크립트
echo "===== FirebaseStorage Storage.swift 파일 수정 스크립트 시작 ====="

STORAGE_SWIFT="ios/Pods/FirebaseStorage/FirebaseStorage/Sources/Storage.swift"

if [ -f "$STORAGE_SWIFT" ]; then
  echo "Storage.swift 파일 수정 중..."
  
  # 백업 생성
  cp "$STORAGE_SWIFT" "${STORAGE_SWIFT}.bak"
  
  # Storage.swift 파일 직접 수정
  sed -i.bak '
    # provider.storage -> provider?.storage
    s/provider\.storage/provider?.storage/g
    
    # return provider.storage -> return provider!.storage
    s/return provider\.storage/return provider!.storage/g
    
    # let provider = ComponentType -> let provider: StorageProvider? = ComponentType
    s/let provider = ComponentType<StorageProvider>/let provider: StorageProvider? = ComponentType<StorageProvider>/g
    
    # app.options.auth -> app.options.auth as? AuthInterop
    s/auth: app.options.auth/auth: app.options.auth as? AuthInterop/g
    
    # app.options.appCheck -> app.options.appCheck as? AppCheckInterop
    s/appCheck: app.options.appCheck/appCheck: app.options.appCheck as? AppCheckInterop/g
  ' "$STORAGE_SWIFT"
  
  echo "Storage.swift 파일 수정 완료"
else
  echo "Storage.swift 파일을 찾을 수 없음: $STORAGE_SWIFT"
  echo "먼저 'pod install'을 실행하세요."
fi

echo "===== FirebaseStorage Storage.swift 파일 수정 스크립트 완료 =====" 