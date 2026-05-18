import Foundation
import Dependencies

/**
 Collection of 'ubiquitous' (i.e. iCloud) state values for a URL.
 */
public struct UbiquitousItemState: Sendable {

  public let isUbiquitousItem: Bool?
  public let ubiquitousItemDownloadingStatus: URLUbiquitousItemDownloadingStatus?
  public let ubiquitousItemIsDownloading: Bool?
  public let ubiquitousItemDownloadingError: NSError?

  public init(
    isUbiquitousItem: Bool?,
    ubiquitousItemDownloadingStatus: URLUbiquitousItemDownloadingStatus?,
    ubiquitousItemIsDownloading: Bool?,
    ubiquitousItemDownloadingError: NSError?
  ) {
    self.isUbiquitousItem = isUbiquitousItem
    self.ubiquitousItemDownloadingStatus = ubiquitousItemDownloadingStatus
    self.ubiquitousItemIsDownloading = ubiquitousItemIsDownloading
    self.ubiquitousItemDownloadingError = ubiquitousItemDownloadingError
  }
}

/**
 A provider of ``UbiquitousItemState`` values for a URL.
 */
public struct UbiquitousItemStateProvider: Sendable {
  public static let resourceKeys = Set<URLResourceKey>([
    .isUbiquitousItemKey,
    .ubiquitousItemDownloadingStatusKey,
    .ubiquitousItemIsDownloadingKey,
    .ubiquitousItemDownloadingErrorKey
  ])

  private var generate: @Sendable (URL) -> UbiquitousItemState?

  /**
   Create a provider that invokes the given closure to provide the ``UbiquitousItemState`` value.

   - parameter generate: the closure to call
   */
  public init(_ generate: @escaping @Sendable (URL) -> UbiquitousItemState?) {
    self.generate = generate
  }

  /**
   Create and return a provider that always returns the same value.

   - parameter state: the constant value to use
   - returns: new instance
   */
  public static func constant(_ state: UbiquitousItemState) -> Self {
    Self { _ in state }
  }

  /**
   Invoke the held closure and return the result.

   - parameter url: the URL to act on
   - returns: ``UbiquitousItemState`` value for the URL
   */
  public func callAsFunction(_ url: URL) -> UbiquitousItemState? {
    self.generate(url)
  }
}

extension DependencyValues {

  /**
   A dependency that returns the current ``UbiquitousItemState`` for a URL.
   */
  public var ubiquitousItemState: UbiquitousItemStateProvider {
    get { self[UbiquitousItemStateProviderKey.self] }
    set { self[UbiquitousItemStateProviderKey.self] = newValue }
  }

  private enum UbiquitousItemStateProviderKey: DependencyKey {

    static let liveValue = UbiquitousItemStateProvider {
      let values = try? $0.resourceValues(forKeys: UbiquitousItemStateProvider.resourceKeys)
      return .init(
        isUbiquitousItem: values?.isUbiquitousItem,
        ubiquitousItemDownloadingStatus: values?.ubiquitousItemDownloadingStatus,
        ubiquitousItemIsDownloading: values?.ubiquitousItemIsDownloading,
        ubiquitousItemDownloadingError: values?.ubiquitousItemDownloadingError
      )
    }

    static let previewValue = UbiquitousItemStateProvider { _ in
      return .init(
        isUbiquitousItem: false,
        ubiquitousItemDownloadingStatus: nil,
        ubiquitousItemIsDownloading: nil,
        ubiquitousItemDownloadingError: nil,
      )
    }

    static let testValue = UbiquitousItemStateProvider { _ in
      return .init(
        isUbiquitousItem: false,
        ubiquitousItemDownloadingStatus: nil,
        ubiquitousItemIsDownloading: nil,
        ubiquitousItemDownloadingError: nil,
      )
    }
  }
}
