#!/bin/bash
BASIC_SEQ_FILE="ios/Pods/gRPC-Core/src/core/lib/promise/detail/basic_seq.h"
if [ -f "$BASIC_SEQ_FILE" ]; then
  # 백업 생성
  cp "$BASIC_SEQ_FILE" "${BASIC_SEQ_FILE}.bak"
  
  # 특정 라인의 template 문법 수정
  sed -i.bak 's/Traits::template CallSeqFactory/Traits::template <typename> CallSeqFactory/g' "$BASIC_SEQ_FILE"
  echo "gRPC template 문법 수정 완료"
fi
