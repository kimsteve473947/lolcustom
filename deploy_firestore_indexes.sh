#!/bin/bash

# Firestore 인덱스 배포 스크립트
echo "Firebase Firestore 인덱스 배포를 시작합니다..."

# Firebase CLI 설치 확인
if ! command -v firebase &> /dev/null; then
    echo "Firebase CLI가 설치되어 있지 않습니다. npm을 통해 설치합니다."
    npm install -g firebase-tools
fi

# Firebase 로그인 확인
firebase login --interactive

# 현재 프로젝트 설정 확인
echo "현재 프로젝트: $(grep -o '"projectId": "[^"]*' .firebaserc | cut -d'"' -f4)"

# Firestore 인덱스 배포
echo "Firestore 인덱스를 배포합니다..."
firebase deploy --only firestore:indexes

echo "인덱스 배포가 완료되었습니다!"
echo "인덱스 생성에는 몇 분 정도 소요될 수 있습니다."
echo "Firebase 콘솔에서 진행 상황을 확인할 수 있습니다: https://console.firebase.google.com/project/$(grep -o '"projectId": "[^"]*' .firebaserc | cut -d'"' -f4)/firestore/indexes" 