#!/bin/bash

# 단일 파일 iOS 빌드 오류 수정 스크립트
echo "===== iOS 간단 빌드 오류 수정 스크립트 시작 ====="

# 1. flutter_local_notifications 버전 오버라이드 설정
echo "flutter_local_notifications 버전 설정 (9.9.1)..."
sed -i '' 's/flutter_local_notifications: .*/flutter_local_notifications: 9.9.1/g' pubspec.yaml

# 2. 이전 Pods 정리
echo "이전 Pods 정리 중..."
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/Runner.xcworkspace

# 3. Flutter 패키지 가져오기
echo "Flutter 패키지 가져오기..."
flutter pub get

# 4. gRPC-Core 폴더 구조 준비
echo "gRPC-Core 폴더 구조 준비 중..."
mkdir -p ios/Pods/gRPC-Core/include/grpc

# 5. module.modulemap 생성
echo "gRPC module.modulemap 생성 중..."
cat > ios/Pods/gRPC-Core/include/grpc/module.modulemap << EOF
framework module grpc {
  umbrella header "grpc.h"
  
  export *
  module * { export * }
  
  link framework "Foundation"
  link framework "Security"
  link "z"
  link "c++"
}
EOF

# 6. Pod 설치
echo "Pod 설치 중..."
cd ios
pod install
cd ..

# 7. 수정된 Podfile 업데이트
echo "Podfile 수정 중..."
cat > ios/Podfile << EOF
# iOS 최소 버전 설정
platform :ios, '12.0'

# CocoaPods 통계 비활성화
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(
    File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__
  )
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. " \
          "If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. " \
        "Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(
  File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root
)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    # '-GCC_WARN_INHIBIT_ALL_WARNINGS' 플래그 제거
    if ['BoringSSL-GRPC', 'gRPC-Core'].include?(target.name)
      target.source_build_phase.files.each do |file|
        next unless file.settings && file.settings['COMPILER_FLAGS']
        flags = file.settings['COMPILER_FLAGS'].split
        flags.reject! { |flag| flag == '-GCC_WARN_INHIBIT_ALL_WARNINGS' }
        file.settings['COMPILER_FLAGS'] = flags.join(' ')
      end
    end

    # 모든 Pod 타겟에 공통 설정 적용
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++17'
      config.build_settings['CLANG_CXX_LIBRARY'] = 'libc++'
      
      # gRPC 관련 설정
      if ['gRPC-Core', 'gRPC-C++', 'BoringSSL-GRPC'].include?(target.name)
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'GRPC_CFSTREAM=1'
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'OPENSSL_NO_ASM=1'
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'PB_FIELD_32BIT=1'
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'PB_NO_PACKED_STRUCTS=1'
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'PB_ENABLE_MALLOC=1'
        
        config.build_settings['HEADER_SEARCH_PATHS'] ||= ['$(inherited)']
        config.build_settings['HEADER_SEARCH_PATHS'] << '${PODS_ROOT}/gRPC-Core'
        config.build_settings['HEADER_SEARCH_PATHS'] << '${PODS_ROOT}/gRPC-Core/include'
        
        config.build_settings['OTHER_CPLUSPLUSFLAGS'] = '$(inherited) -fno-exceptions -std=c++17'
      end
    end
  end
end
EOF

# 8. Pod 재설치
echo "Pod 재설치 중..."
cd ios
pod install
cd ..

# 9. 기본적인 gRPC 템플릿 문법 수정
echo "gRPC 템플릿 문법 수정 중..."
BASIC_SEQ_FILE="ios/Pods/gRPC-Core/src/core/lib/promise/detail/basic_seq.h"
if [ -f "$BASIC_SEQ_FILE" ]; then
  # 백업 생성
  cp "$BASIC_SEQ_FILE" "${BASIC_SEQ_FILE}.bak"
  
  # 문법 오류 수정 (102번 줄 근처)
  sed -i.bak '101,105s/template\([^<]*\)template/template\1/g' "$BASIC_SEQ_FILE"
  sed -i.bak '101,105s/Traits::template /Traits::template <typename> /g' "$BASIC_SEQ_FILE"
  
  echo "gRPC basic_seq.h 파일 수정 완료"
fi

# 10. 완료 메시지
echo "===== iOS 간단 빌드 오류 수정 완료 ====="
echo "이제 'flutter run -d ios' 또는 Xcode에서 앱을 실행해보세요." 