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
