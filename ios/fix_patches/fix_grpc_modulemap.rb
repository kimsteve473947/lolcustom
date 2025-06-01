#!/usr/bin/env ruby

# gRPC-Core module.modulemap 파일 생성 스크립트
# Pod 설치 중 "No such file or directory @ rb_sysopen - /ios/Pods/gRPC-Core/include/grpc/module.modulemap" 오류 수정

project_root = ARGV[0]
grpc_include_dir = "#{project_root}/ios/Pods/gRPC-Core/include/grpc"
grpc_modulemap_path = "#{grpc_include_dir}/module.modulemap"

if File.directory?(grpc_include_dir)
  puts "gRPC-Core include 디렉토리 확인: #{grpc_include_dir}"
  
  # module.modulemap 파일 생성
  modulemap_content = <<~MODULE_MAP
    framework module grpc {
      umbrella header "grpc.h"
      
      export *
      module * { export * }
      
      link framework "Foundation"
      link framework "Security"
      link "z"
      link "c++"
    }
  MODULE_MAP
  
  # 파일 저장
  File.write(grpc_modulemap_path, modulemap_content)
  puts "gRPC-Core module.modulemap 파일 생성 완료: #{grpc_modulemap_path}"
else
  puts "gRPC-Core include 디렉토리를 찾을 수 없습니다: #{grpc_include_dir}"
  puts "먼저 'pod install'을 실행하세요"
end 