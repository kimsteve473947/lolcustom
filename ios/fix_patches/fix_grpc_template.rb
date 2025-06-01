#!/usr/bin/env ruby

# Fix for gRPC C++ template syntax error in basic_seq.h
# This script modifies the problematic gRPC file that causes Xcode build failures
# Error: "A template argument list is expected after a name prefixed by the template keyword"

project_root = ARGV[0]
grpc_basic_seq_path = "#{project_root}/ios/Pods/gRPC-Core/src/core/lib/promise/detail/basic_seq.h"

if File.exist?(grpc_basic_seq_path)
  puts "Patching gRPC-Core template syntax in basic_seq.h..."
  
  content = File.read(grpc_basic_seq_path)
  original_content = content.dup
  
  # Fix known template syntax errors
  # Replace problematic template pattern with correct C++17 syntax
  # This addresses the "template keyword" error
  content.gsub!(/template([^<]*)template/, 'template\1')
  
  # Fix potential template<template> syntax
  content.gsub!(/template\s+<\s*template\s*>/, 'template <typename>')
  
  # Fix missing template parameter lists
  content.gsub!(/template\s+([a-zA-Z0-9_]+)(?![<])/, 'template <typename> \1')
  
  # Additional fix for cases where 'template' is used as keyword
  # but no template argument list follows
  content.gsub!(/(\W)template(\W)(?!<)/, '\1/*template*/\2')
  
  if content != original_content
    File.write(grpc_basic_seq_path, content)
    puts "Successfully patched gRPC template syntax in basic_seq.h"
  else
    puts "No template syntax issues found in basic_seq.h"
  end
else
  puts "Could not find gRPC-Core basic_seq.h at: #{grpc_basic_seq_path}"
  puts "Make sure to run 'pod install' first."
end 