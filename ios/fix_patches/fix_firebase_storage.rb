#!/usr/bin/env ruby

storage_swift_path = "#{ARGV[0]}/ios/Pods/FirebaseStorage/FirebaseStorage/Sources/Storage.swift"

if File.exist?(storage_swift_path)
  puts "Patching FirebaseStorage Swift file..."
  
  content = File.read(storage_swift_path)
  
  # Provider 수정
  content.gsub!(/let provider = ComponentType<StorageProvider>/, 'let provider: StorageProvider? = ComponentType<StorageProvider>')
  content.gsub!(/return provider.storage/, 'return provider!.storage')
  
  # Firebase Options 옵셔널 처리
  content.gsub!(/auth: app.options.auth/, 'auth: app.options.auth as? AuthInterop')
  content.gsub!(/appCheck: app.options.appCheck/, 'appCheck: app.options.appCheck as? AppCheckInterop')
  
  # 직접 Storage.swift 클래스 수정
  new_content = []
  in_storage_impl = false
  in_init_method = false
  
  content.each_line do |line|
    if line.include?("private class StorageImpl: StorageProtocol")
      in_storage_impl = true
    end
    
    if in_storage_impl && line.include?("init(app: FirebaseApp")
      in_init_method = true
    end
    
    # Auth, AppCheck 옵셔널 처리
    if in_init_method && line.strip.start_with?("self.auth = ")
      line = line.gsub(/self\.auth = auth/, 'self.auth = auth!')
    end
    
    if in_init_method && line.strip.start_with?("self.appCheck = ")
      line = line.gsub(/self\.appCheck = appCheck/, 'self.appCheck = appCheck!')
    end
    
    if in_storage_impl && line.include?("var auth: AuthInterop")
      line = line.gsub(/var auth: AuthInterop/, 'var auth: AuthInterop!')
    end
    
    if in_storage_impl && line.include?("var appCheck: AppCheckInterop")
      line = line.gsub(/var appCheck: AppCheckInterop/, 'var appCheck: AppCheckInterop!')
    end
    
    new_content << line
    
    if in_init_method && line.include?("}")
      in_init_method = false
    end
    
    if in_storage_impl && line.include?("}")
      in_storage_impl = false
    end
  end
  
  File.write(storage_swift_path, new_content.join)
  puts "Firebase Storage Swift file patched successfully."
else
  puts "Could not find FirebaseStorage Swift file at: #{storage_swift_path}"
end 