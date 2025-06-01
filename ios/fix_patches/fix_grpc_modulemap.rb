#!/usr/bin/env ruby
require 'fileutils'

# gRPC-Core module.modulemap 파일 생성 스크립트
# Pod 설치 중 "No such file or directory @ rb_sysopen - /ios/Pods/gRPC-Core/include/grpc/module.modulemap" 오류 수정

project_root = ARGV[0] || Dir.pwd
module_map_dir = File.join(project_root, 'ios/Pods/gRPC-Core/include/grpc')
module_map_file = File.join(module_map_dir, 'module.modulemap')

# 디렉토리가 없으면 생성
unless Dir.exist?(module_map_dir)
  puts "Creating directory: #{module_map_dir}"
  FileUtils.mkdir_p(module_map_dir)
end

# module.modulemap 파일 생성
File.open(module_map_file, 'w') do |file|
  file.puts <<-MODULE_MAP
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
end

puts "Created module.modulemap at #{module_map_file}" 