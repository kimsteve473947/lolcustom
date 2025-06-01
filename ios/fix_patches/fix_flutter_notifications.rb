#!/usr/bin/env ruby

# Flutter Local Notifications 패키지 관련 Linux 플랫폼 오류 수정 스크립트
# 해당 패키지가 Linux 플랫폼을 잘못 참조하는 문제 해결

require 'yaml'

# 프로젝트 루트 디렉토리 
project_root = ARGV[0]
pubspec_lock_path = "#{project_root}/pubspec.lock"

if File.exist?(pubspec_lock_path)
  puts "flutter_local_notifications 패키지 참조 수정 중..."
  
  # pubspec.lock 파일 읽기
  pubspec_lock = YAML.load_file(pubspec_lock_path)
  
  # flutter_local_notifications 패키지 찾기
  if pubspec_lock['packages'] && pubspec_lock['packages']['flutter_local_notifications']
    notification_pkg = pubspec_lock['packages']['flutter_local_notifications']
    
    # dependency_overrides 추가를 위한 pubspec.yaml 수정
    pubspec_yaml_path = "#{project_root}/pubspec.yaml"
    pubspec_yaml = YAML.load_file(pubspec_yaml_path)
    
    # dependency_overrides 섹션이 없으면 추가
    pubspec_yaml['dependency_overrides'] ||= {}
    
    # flutter_local_notifications 오버라이드 추가
    pubspec_yaml['dependency_overrides']['flutter_local_notifications'] = notification_pkg['version']
    
    # 수정된 pubspec.yaml 저장
    File.write(pubspec_yaml_path, pubspec_yaml.to_yaml)
    
    puts "pubspec.yaml에 dependency_overrides 추가 완료"
    puts "이제 'flutter pub get'을 실행하세요"
  else
    puts "flutter_local_notifications 패키지를 찾을 수 없습니다"
  end
else
  puts "pubspec.lock 파일을 찾을 수 없습니다: #{pubspec_lock_path}"
end 