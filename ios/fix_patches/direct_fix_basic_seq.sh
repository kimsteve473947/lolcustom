#!/bin/bash

# 이 스크립트는 gRPC-Core의 basic_seq.h 파일의 102번째 줄 주변에서 
# 템플릿 문법 오류를 직접 수정합니다.

PROJECT_ROOT=$1
BASIC_SEQ_FILE="$PROJECT_ROOT/ios/Pods/gRPC-Core/src/core/lib/promise/detail/basic_seq.h"

if [ -f "$BASIC_SEQ_FILE" ]; then
  echo "basic_seq.h 파일을 수정합니다: $BASIC_SEQ_FILE"
  
  # 백업 파일 생성
  cp "$BASIC_SEQ_FILE" "${BASIC_SEQ_FILE}.bak"
  
  # 문법 오류 수정 (템플릿 관련 문제)
  sed -i '.bak2' 's/template\([^<]*\)template/template\1/g' "$BASIC_SEQ_FILE"
  sed -i '.bak3' 's/Traits::template /Traits::template <typename> /g' "$BASIC_SEQ_FILE"
  
  echo "basic_seq.h 파일 수정 완료"
else
  echo "basic_seq.h 파일을 찾을 수 없습니다: $BASIC_SEQ_FILE"
  echo "먼저 'pod install'을 실행하세요"
fi 