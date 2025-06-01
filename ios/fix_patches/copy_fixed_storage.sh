#!/bin/bash

# 수정된 Storage.swift 파일을 Pods 디렉토리로 복사하는 스크립트

PROJECT_ROOT="$1"
FIXED_STORAGE="${PROJECT_ROOT}/ios/fix_patches/fixed_storage.swift"
TARGET_STORAGE="${PROJECT_ROOT}/ios/Pods/FirebaseStorage/FirebaseStorage/Sources/Storage.swift"

if [ -f "$FIXED_STORAGE" ] && [ -f "$TARGET_STORAGE" ]; then
  echo "고정된 Storage.swift 파일을 Pods 디렉토리로 복사 중..."
  
  # 원본 파일 백업
  cp "$TARGET_STORAGE" "${TARGET_STORAGE}.bak"
  
  # 수정된 파일 복사
  cp "$FIXED_STORAGE" "$TARGET_STORAGE"
  
  # 파일 권한 설정
  chmod 644 "$TARGET_STORAGE"
  
  echo "Storage.swift 파일이 성공적으로 교체되었습니다."
else
  if [ ! -f "$FIXED_STORAGE" ]; then
    echo "수정된 Storage.swift 파일을 찾을 수 없습니다: $FIXED_STORAGE"
  fi
  
  if [ ! -f "$TARGET_STORAGE" ]; then
    echo "대상 Storage.swift 파일을 찾을 수 없습니다: $TARGET_STORAGE"
  fi
fi 