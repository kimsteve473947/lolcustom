#!/bin/bash

# 이 스크립트는 gRPC-Core의 basic_seq.h 파일의 102번째 줄 주변에서 
# 템플릿 문법 오류를 직접 수정합니다.

PROJECT_ROOT="$1"
BASIC_SEQ_FILE="${PROJECT_ROOT}/ios/Pods/gRPC-Core/src/core/lib/promise/detail/basic_seq.h"

if [ -f "$BASIC_SEQ_FILE" ]; then
  echo "직접 basic_seq.h 파일의 템플릿 오류 수정 중..."
  
  # 임시 파일 생성
  TMP_FILE=$(mktemp)
  
  # 100-105번째 줄 내용 확인 (오류 지점 파악용)
  echo "오류 발생 지점 코드:"
  sed -n '100,105p' "$BASIC_SEQ_FILE"
  
  # 102번째 줄 주변의 'template' 키워드 수정
  # 정확한 오류 줄을 찾아 수정합니다
  awk '{
    if (NR == 102 && $0 ~ /template[^<]*$/) {
      # 템플릿 키워드 뒤에 <> 없는 경우 수정
      gsub(/template/, "/* template */");
      print;
    } else if (NR == 102 && $0 ~ /template[^<]*template/) {
      # 중복 템플릿 키워드 수정
      gsub(/template[^<]*template/, "template");
      print;
    } else {
      print;
    }
  }' "$BASIC_SEQ_FILE" > "$TMP_FILE"
  
  # 원본 파일 백업
  cp "$BASIC_SEQ_FILE" "${BASIC_SEQ_FILE}.bak"
  
  # 수정된 내용으로 교체
  mv "$TMP_FILE" "$BASIC_SEQ_FILE"
  
  echo "basic_seq.h 파일 수정 완료"
  echo "수정 후 코드:"
  sed -n '100,105p' "$BASIC_SEQ_FILE"
else
  echo "basic_seq.h 파일을 찾을 수 없습니다: $BASIC_SEQ_FILE"
  echo "먼저 'pod install'을 실행하세요"
fi 