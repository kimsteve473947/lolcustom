#!/bin/bash

echo "===== 완전 정리 후 iOS 빌드 오류 수정 스크립트 시작 ====="

# 1. 깨끗하게 정리 (모든 캐시 삭제)
echo "모든 캐시 및 임시 파일 제거 중..."
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/Runner.xcworkspace
rm -rf ios/.symlinks
rm -rf build/
rm -rf .dart_tool/
rm -rf .flutter-plugins
rm -rf .flutter-plugins-dependencies

# 2. pubspec.yaml 파일 수정
echo "pubspec.yaml 수정 중..."
cat > pubspec.yaml << EOF
name: lol_custom_game_manager
description: League of Legends custom game manager app to handle mercenary recruitment and participation.

# Prevent accidental publishing to pub.dev.
publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # Firebase
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.15.3
  firebase_storage: ^11.6.3
  firebase_messaging: ^14.7.4

  # UI
  cupertino_icons: ^1.0.6
  flutter_svg: ^2.0.9
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0
  flutter_rating_bar: ^4.0.1
  image_picker: ^1.0.4

  # State Management
  provider: ^6.1.1

  # Routing
  go_router: ^12.1.3

  # Utils
  shared_preferences: ^2.2.2
  url_launcher: ^6.2.2
  logger: ^2.0.2
  http: ^0.13.6
  equatable: ^2.0.5
  uuid: ^4.2.1
  intl: ^0.20.2
  flutter_local_notifications: 9.9.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

# Linux 플랫폼 문제 해결용
dependency_overrides:
  flutter_local_notifications: 9.9.1

flutter:
  uses-material-design: true

  assets:
    - assets/images/
    - assets/icons/
    - assets/fonts/
    - .env
EOF

# 3. Podfile 수정
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

# 4. Flutter 패키지 다시 가져오기
echo "Flutter 패키지 다시 가져오기..."
flutter clean
flutter pub get

# 5. gRPC-Core 폴더 구조 준비
echo "gRPC-Core 폴더 구조 준비 중..."
mkdir -p ios/Pods/gRPC-Core/include/grpc

# 6. module.modulemap 생성
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

# 7. Pod 설치
echo "Pod 설치 중..."
cd ios
pod install
cd ..

# 8. 고정된 Storage.swift 파일 생성
echo "고정된 Storage.swift 파일 생성 중..."
mkdir -p ios/fix_patches
cat > ios/fix_patches/fixed_storage.swift << 'EOF'
import Foundation
import FirebaseCore
import FirebaseAppCheck

/**
 * Firebase Storage is a service that supports uploading and downloading binary objects,
 * such as images, videos, and other files to Google Cloud Storage. The Firebase Storage
 * service provides secure uploads and downloads, regardless of network quality.
 *
 * Firebase Storage adds Google security to file uploads and downloads. You can use it to
 * store images, audio, video, or other user-generated content. Firebase Storage is backed by
 * Google Cloud Storage, a powerful, simple, and cost-effective object storage service.
 */
@objc(FIRStorage) open class Storage: NSObject {
  // MARK: - Public string constants

  /**
   * Firebase Storage error domain.
   */
  @objc public static let errorDomain = "FIRStorageErrorDomain"

  /**
   * The maximum time to retry operations if there is an error.
   */
  @objc public static let maxDownloadRetryTime: TimeInterval = 600.0

  /**
   * The maximum time to retry operations if there is an error.
   */
  @objc public static let maxUploadRetryTime: TimeInterval = 600.0

  /**
   * The maximum time to retry operations if there is an error.
   */
  @objc public static let maxOperationRetryTime: TimeInterval = 120.0

  // MARK: - Public members

  /**
   * The Firebase App associated with this Storage instance.
   */
  @objc public let app: FirebaseApp

  /**
   * The storage bucket for this instance.
   */
  @objc public let bucket: String

  /**
   * Maximum time in seconds to retry a download if a failure occurs.
   * Defaults to 600 seconds (10 minutes).
   */
  @objc public var maxDownloadRetryTime: TimeInterval {
    return impl.maxDownloadRetryTime
  }

  /**
   * Maximum time in seconds to retry an upload if a failure occurs.
   * Defaults to 600 seconds (10 minutes).
   */
  @objc public var maxUploadRetryTime: TimeInterval {
    return impl.maxUploadRetryTime
  }

  /**
   * Maximum time in seconds to retry operations other than upload and download if a failure occurs.
   * Defaults to 120 seconds (2 minutes).
   */
  @objc public var maxOperationRetryTime: TimeInterval {
    return impl.maxOperationRetryTime
  }

  /// Internal Storage object implementation.
  private let impl: StorageProtocol

  /// @cond SWIFT_INTERNAL
  internal var useEmulator = false

  /**
   * Internal initializer for Storage.
   *
   * @param app The FirebaseApp associated with this Storage instance.
   * @param auth A (legacy) Firebase Auth instance associated with this Firebase Storage instance.
   * @param bucket The gs:// url to your Firebase Storage bucket.
   */
  internal init(app: FirebaseApp, auth: AuthInterop?, appCheck: AppCheckInterop?, bucket: String) {
    impl = StorageImpl(app: app, auth: auth, appCheck: appCheck, bucket: bucket)
    self.app = app
    self.bucket = bucket
  }

  internal init(app: FirebaseApp, impl: StorageProtocol, bucket: String) {
    self.impl = impl
    self.app = app
    self.bucket = bucket
  }

  // MARK: - Storage factory methods

  /**
   * Creates a Firebase Storage instance for the default Firebase app.
   * @return A Firebase Storage instance for the default Firebase app.
   */
  @objc open class func storage() -> Storage? {
    return storage(app: FirebaseApp.app())
  }

  /**
   * Creates a Firebase Storage instance for the specified Firebase app.
   * @param app The Firebase app for an instance of Firebase Storage.
   * @return A Firebase Storage instance for the specified Firebase app.
   */
  @objc open class func storage(app: FirebaseApp) -> Storage? {
    let provider: StorageProvider? = ComponentType<StorageProvider>.instance(for: StorageProvider.self,
                                                                          in: app.container)
    return provider?.storage(for: app)
  }

  /**
   * Creates a Firebase Storage instance for the default Firebase app using a custom storage bucket.
   * @param url A gs:// URL to a custom Firebase Storage bucket.
   * @return A Firebase Storage instance for the default Firebase app.
   */
  @objc open class func storage(url: String) -> Storage? {
    return storage(app: FirebaseApp.app(), url: url)
  }

  /**
   * Creates a Firebase Storage instance for the specified Firebase app using a custom storage bucket.
   * @param app The Firebase app for an instance of Firebase Storage.
   * @param url A gs:// URL to a custom Firebase Storage bucket.
   * @return A Firebase Storage instance for the specified Firebase app.
   */
  @objc open class func storage(app: FirebaseApp, url: String) -> Storage? {
    let provider: StorageProvider? = ComponentType<StorageProvider>.instance(for: StorageProvider.self,
                                                                          in: app.container)
    return provider?.storage(for: app, url: url)
  }

  /**
   * Returns a new firebase Storage instance at a custom storage bucket url.
   * @param url A gs:// url which points to a custom storage bucket.
   * @return A Firebase Storage instance for the default Firebase app.
   */
  @objc open func reference(for url: String) -> StorageReference {
    return impl.reference(for: url)
  }

  /**
   * Creates a StorageReference initialized at the root of the Firebase Storage bucket.
   * @return A StorageReference pointing to the root of the storage bucket.
   */
  @objc open func reference() -> StorageReference {
    return impl.reference()
  }

  /**
   * Creates a StorageReference given a path.
   * @param path Path to initialize the StorageReference with.
   * @return A StorageReference pointing to the root of the storage bucket.
   */
  @objc open func reference(withPath path: String) -> StorageReference {
    return impl.reference(withPath: path)
  }

  /**
   * Configures the Storage instance to use the emulator.
   *
   * Note: Call this method before using the instance to do any storage operations.
   *
   * @param host The emulator host (for example, localhost)
   * @param port The emulator port (for example, 9199)
   */
  @objc open func useEmulator(withHost host: String, port: Int) {
    useEmulator = true
    impl.useEmulator(withHost: host, port: port)
  }
}

protocol StorageProtocol {
  var maxDownloadRetryTime: TimeInterval { get set }
  var maxUploadRetryTime: TimeInterval { get set }
  var maxOperationRetryTime: TimeInterval { get set }

  func reference() -> StorageReference
  func reference(withPath path: String) -> StorageReference
  func reference(for url: String) -> StorageReference

  func useEmulator(withHost host: String, port: Int)
}

private class StorageImpl: StorageProtocol {
  var maxDownloadRetryTime: TimeInterval = Storage.maxDownloadRetryTime
  var maxUploadRetryTime: TimeInterval = Storage.maxUploadRetryTime
  var maxOperationRetryTime: TimeInterval = Storage.maxOperationRetryTime

  let app: FirebaseApp
  let auth: AuthInterop?
  let appCheck: AppCheckInterop?
  let bucket: String
  private let fetcherService: GTMSessionFetcherServiceProtocol
  private let dispatchQueue: StorageDispatchQueue
  private let storagePath: String

  init(app: FirebaseApp, auth: AuthInterop?, appCheck: AppCheckInterop?, bucket: String) {
    self.app = app
    self.auth = auth
    self.appCheck = appCheck
    self.bucket = bucket
    let fetcherService = GTMSessionFetcherService()
    fetcherService.allowLocalhostRequest = true
    self.fetcherService = fetcherService
    dispatchQueue = StorageDispatchQueue()
    storagePath = ""
  }

  init(app: FirebaseApp, auth: AuthInterop?, appCheck: AppCheckInterop?, bucket: String,
       fetcherService: GTMSessionFetcherServiceProtocol, dispatchQueue: StorageDispatchQueue,
       storagePath: String) {
    self.app = app
    self.auth = auth
    self.appCheck = appCheck
    self.bucket = bucket
    self.fetcherService = fetcherService
    self.dispatchQueue = dispatchQueue
    self.storagePath = storagePath
  }

  func reference() -> StorageReference {
    return reference(withPath: storagePath)
  }

  func reference(withPath path: String) -> StorageReference {
    var path = path
    if path.hasPrefix("gs://") {
      // Remove the gs:// prefix if present to make it a valid path.
      let percentEncodedPath = path.dropFirst("gs://".count)
      var components = percentEncodedPath.components(separatedBy: "/")
      path = components.removeFirst()
      path += "/"
      path += components.joined(separator: "/")
      return reference(for: "gs://\(path)")
    }
    var storagePath = self.storagePath
    if path != "" {
      if !storagePath.isEmpty {
        storagePath += "/"
      }
      storagePath += path
    }
    let impl = StorageReferenceImpl(storage: self, path: storagePath)
    return StorageReference(impl: impl)
  }

  func reference(for url: String) -> StorageReference {
    var path = ""
    var bucket = ""

    guard let percentEncodedString = url.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
    else {
      fatalError("Unable to encode URL: \(url)")
    }

    guard let storageComponents =
      URL(string: percentEncodedString)?.pathComponents.filter({ !$0.isEmpty && $0 != "/" }) else {
      fatalError("Internal error from invalid storage URL")
    }

    guard let host = URL(string: percentEncodedString)?.host else {
      fatalError("Internal error from invalid storage URL")
    }

    if percentEncodedString.hasPrefix("gs://") {
      bucket = host
      path = storageComponents.joined(separator: "/")
    } else {
      fatalError("Storage URL must start with 'gs://'")
    }
    var storage = Storage.storage(app: app, url: "gs://\(bucket)")
    if storage == nil {
      // Fall back to using the default bucket to prevent crashing if bucket is not specified.
      storage = Storage.storage(app: app)
    }
    guard let storage = storage else {
      fatalError("Unable to create a Storage instance")
    }
    return storage.reference(withPath: path)
  }

  func useEmulator(withHost host: String, port: Int) {
    (fetcherService as? GTMSessionFetcherService)?.allowLocalhostRequest = true
    fetcherService.setAllowedInsecureSchemes(["http"])
    fetcherService.setAllowLocalhostRequest(true)
  }
}

/**
 * StorageProvider provides an instance of Storage for a given app. It also exposes utility methods for
 * creating Storage instances.
 */
protocol StorageProvider {
  /// Creates a Storage with an existing App
  func storage(for app: FirebaseApp) -> Storage

  /// Creates a Storage with an existing App and URL
  func storage(for app: FirebaseApp, url: String) -> Storage
}

class FirebaseStorageProvider: NSObject, StorageProvider, LibraryVersionReader {
  let components: [Any] = []
  let bucket: String = {
    if let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let plist = NSDictionary(contentsOfFile: plistPath) {
      return plist["STORAGE_BUCKET"] as? String ?? ""
    }
    return ""
  }()

  func storage(for app: FirebaseApp) -> Storage {
    let bucket = app.options.storageBucket ?? self.bucket
    if bucket.isEmpty {
      fatalError("No default Storage bucket found. Please set the Storage bucket in your app's "
        + "GoogleService-Info.plist or directly via the storageURL property on FirebaseOptions.")
    }
    return storage(for: app, url: "gs://\(bucket)")
  }

  func storage(for app: FirebaseApp, url: String) -> Storage {
    var url = url
    if !url.hasPrefix("gs://") {
      fatalError("Storage URL must start with 'gs://'")
    }
    let percentEncodedString = url.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
      ?? url
    let storage = URL(string: percentEncodedString)
    if storage?.host == nil {
      fatalError("Internal error: attempting to parse an invalid URL string: \(url)")
    }
    let bucket = storage?.host ?? ""
    let appCheck = app.options.appCheck as? AppCheckInterop
    let auth = app.options.auth as? AuthInterop
    return Storage(app: app, auth: auth, appCheck: appCheck, bucket: bucket)
  }
}

/// Access to App Check. The implementation can choose to return a dummy.
protocol AppCheckInterop {
  /// An App Check token representing the current app.
  func getToken(forcingRefresh: Bool,
                completion: @escaping (AppCheckTokenResult) -> Void)

  /// An App Check token that is limited to a specific resource.
  func getLimitedUseToken(completion: @escaping (AppCheckTokenResult) -> Void)
}

/// The App Check token and/or error resulting from a call to the App Check provider.
enum AppCheckTokenResult {
  /// The completed App Check token.
  case success(AppCheckToken)

  /// An error from the App Check provider.
  case error(Error)
}

/// Access to Auth. The implementation can choose to return a dummy.
protocol AuthInterop {
  /// The current Auth token.
  func getToken(forcingRefresh: Bool, completion: @escaping AuthTokenCallback)
}

/// Auth Token and Error typealias
typealias AuthTokenCallback = (String?, Error?) -> Void

/// An App Check token.
protocol AppCheckToken {
  /// The App Check token.
  var token: String { get }

  /// The time when the token expires.
  var expirationDate: Date { get }
}
EOF

# 9. Storage.swift 복사 스크립트 생성
echo "Storage.swift 복사 스크립트 생성 중..."
cat > ios/fix_patches/copy_storage.sh << EOF
#!/bin/bash
cp -f ios/fix_patches/fixed_storage.swift ios/Pods/FirebaseStorage/FirebaseStorage/Sources/Storage.swift
chmod 644 ios/Pods/FirebaseStorage/FirebaseStorage/Sources/Storage.swift
EOF

chmod +x ios/fix_patches/copy_storage.sh

# 10. gRPC 템플릿 패치 생성
echo "gRPC 템플릿 패치 생성 중..."
cat > ios/fix_patches/fix_template.sh << EOF
#!/bin/bash
BASIC_SEQ_FILE="ios/Pods/gRPC-Core/src/core/lib/promise/detail/basic_seq.h"
if [ -f "\$BASIC_SEQ_FILE" ]; then
  # 백업 생성
  cp "\$BASIC_SEQ_FILE" "\${BASIC_SEQ_FILE}.bak"
  
  # 특정 라인의 template 문법 수정
  sed -i.bak 's/Traits::template CallSeqFactory/Traits::template <typename> CallSeqFactory/g' "\$BASIC_SEQ_FILE"
  echo "gRPC template 문법 수정 완료"
fi
EOF

chmod +x ios/fix_patches/fix_template.sh

# 11. Storage.swift 파일 복사 및 gRPC 패치 적용
echo "Storage.swift 파일 복사 및 gRPC 패치 적용 중..."
ios/fix_patches/copy_storage.sh
ios/fix_patches/fix_template.sh

# 12. 다시 Pod 설치
echo "Pod 재설치 중..."
cd ios
pod install
cd ..

# 13. 완료 메시지
echo "===== 완전 정리 후 iOS 빌드 오류 수정 스크립트 완료 ====="
echo "이제 'flutter run -d ios' 또는 Xcode에서 앱을 실행해보세요." 