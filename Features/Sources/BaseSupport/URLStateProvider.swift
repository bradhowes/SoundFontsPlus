public import Foundation
public import Dependencies

/**
 Collection of 'ubiquitous' (i.e. iCloud) state values for a URL.
 */
public struct URLState: Sendable {

  public let fileExists: Bool
  public let isUbiquitousItem: Bool
  public let ubiquitousItemDownloadingStatus: URLUbiquitousItemDownloadingStatus?
  public let ubiquitousItemIsDownloading: Bool?
  public let ubiquitousItemDownloadingError: NSError?

  public init(
    fileExists: Bool,
    isUbiquitousItem: Bool,
    ubiquitousItemDownloadingStatus: URLUbiquitousItemDownloadingStatus?,
    ubiquitousItemIsDownloading: Bool?,
    ubiquitousItemDownloadingError: NSError?
  ) {
    self.fileExists = fileExists
    self.isUbiquitousItem = isUbiquitousItem
    self.ubiquitousItemDownloadingStatus = ubiquitousItemDownloadingStatus
    self.ubiquitousItemIsDownloading = ubiquitousItemIsDownloading
    self.ubiquitousItemDownloadingError = ubiquitousItemDownloadingError
  }
}

/**
 A provider of ``URLState`` values for a URL.
 */
public struct URLStateProvider: Sendable {
  public static let resourceKeys = Set<URLResourceKey>([
    .isUbiquitousItemKey,
    .ubiquitousItemDownloadingStatusKey,
    .ubiquitousItemIsDownloadingKey,
    .ubiquitousItemDownloadingErrorKey
  ])

  private var generate: @Sendable (URL) -> URLState

  /**
   Create a provider that invokes the given closure to provide the ``UbiquitousItemState`` value.

   - parameter generate: the closure to call
   */
  public init(_ generate: @escaping @Sendable (URL) -> URLState) {
    self.generate = generate
  }

  /**
   Create and return a provider that always returns the same value.

   - parameter state: the constant value to use
   - returns: new instance
   */
  public static func constant(_ state: URLState) -> Self {
    Self { _ in state }
  }

  /**
   Invoke the held closure and return the result.

   - parameter url: the URL to act on
   - returns: ``UbiquitousItemState`` value for the URL
   */
  public func callAsFunction(_ url: URL) -> URLState {
    self.generate(url)
  }
}

extension DependencyValues {

  /**
   A dependency that returns the current ``UbiquitousItemState`` for a URL.
   */
  public var urlStateProvider: URLStateProvider {
    get { self[URLStateProviderKey.self] }
    set { self[URLStateProviderKey.self] = newValue }
  }

  private enum URLStateProviderKey: DependencyKey {

    static let liveValue = URLStateProvider { url in
      @Dependency(\.fileManager) var fileManager
      let values = try? url.resourceValues(forKeys: URLStateProvider.resourceKeys)
      return .init(
        fileExists: fileManager.fileExists(url),
        isUbiquitousItem: values?.isUbiquitousItem ?? false,
        ubiquitousItemDownloadingStatus: values?.ubiquitousItemDownloadingStatus,
        ubiquitousItemIsDownloading: values?.ubiquitousItemIsDownloading,
        ubiquitousItemDownloadingError: values?.ubiquitousItemDownloadingError
      )
    }

    static let previewValue = URLStateProvider { _ in
      return .init(
        fileExists: false,
        isUbiquitousItem: false,
        ubiquitousItemDownloadingStatus: nil,
        ubiquitousItemIsDownloading: nil,
        ubiquitousItemDownloadingError: nil,
      )
    }

    static let testValue = URLStateProvider { _ in
      return .init(
        fileExists: false,
        isUbiquitousItem: false,
        ubiquitousItemDownloadingStatus: nil,
        ubiquitousItemIsDownloading: nil,
        ubiquitousItemDownloadingError: nil,
      )
    }
  }
}
