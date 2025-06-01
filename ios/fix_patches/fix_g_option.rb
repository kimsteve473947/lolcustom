require 'xcodeproj'

project_path = "#{ARGV[0]}/ios/Pods/Pods.xcodeproj"
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  if ['BoringSSL-GRPC', 'gRPC-Core', 'gRPC-C++'].include?(target.name)
    puts "Fixing target: #{target.name}"
    target.build_configurations.each do |config|
      ['OTHER_CFLAGS', 'OTHER_CPLUSPLUSFLAGS'].each do |flag_name|
        if config.build_settings[flag_name]
          config.build_settings[flag_name] = config.build_settings[flag_name].map { |flag| flag.gsub('-G', '-GG') }
          puts "  Modified #{flag_name} in #{config.name}"
        end
      end
      # Add preprocessor definition
      if config.build_settings['GCC_PREPROCESSOR_DEFINITIONS']
        unless config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'].include?('OPENSSL_NO_ASM=1')
          config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'OPENSSL_NO_ASM=1'
          puts "  Added OPENSSL_NO_ASM=1 to GCC_PREPROCESSOR_DEFINITIONS in #{config.name}"
        end
      else
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] = ['$(inherited)', 'OPENSSL_NO_ASM=1']
        puts "  Created GCC_PREPROCESSOR_DEFINITIONS with OPENSSL_NO_ASM=1 in #{config.name}"
      end
    end
  end
end

project.save 