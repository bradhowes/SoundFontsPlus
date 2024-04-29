// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import Dependencies


extension Notification.Name {
  static let bookmarkChanged = Self("SoundFonts.bookmarkChanged")
}

/// A bookmark represents a file located outside of the app's own storage space. It is used to reference sound font files
/// without making a copy of them. However there are risks involved, namely that the bookmark may not resolve to a real
/// file.
public final class Bookmark: Codable {
  enum CodingKeys: CodingKey {
    case name
    case bookmark
    case original
  }

  /// The name of the sound font represented by the bookmark
  public let name: String
  public private(set) var bookmark: Data?
  public let original: URL

  public var url: URL { restore() }

  private var lastRestoredUrl: URL?
  private var lastRestoredWhen: CFTimeInterval

  @Dependency(\.fileManager.isUbiquitousItem) var isUbiquitousItem

  /**
   Construct a new bookmark

   - parameter url: the file to bookmark
   - parameter name: the name to associate with the bookmark
   */
  public init(url: URL, name: String) {
    self.name = name
    original = url
    bookmark = url.secureBookmarkData
    lastRestoredUrl = nil
    lastRestoredWhen = 0
  }

  /**
   Attempt to reconstitute a bookmark from an encoded container

   - parameter decoder: the container to read from
   - throws exception if unable to decode from container
   */
  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    name = try values.decode(String.self, forKey: .name)
    original = try values.decode(URL.self, forKey: .original)
    bookmark = try values.decode(Data.self, forKey: .bookmark)
    lastRestoredUrl = nil
    lastRestoredWhen = 0
  }
}

public extension Bookmark {

  static func from(data: Data) throws -> Bookmark {
    let decoder = PropertyListDecoder()
    return try decoder.decode(Bookmark.self, from: data)
  }

  /// Determine the availability state for a bookmarked URL
  var isAvailable: Bool {
    let secured = url.startAccessingSecurityScopedResource()
    let value = try? url.checkResourceIsReachable()
    if secured { url.stopAccessingSecurityScopedResource() }
    return value ?? false
  }

  /// Determine if the file is located in an iCloud container
  var isUbiquitous: Bool { isUbiquitousItem(url) }

  /// The various iCloud states a bookmark item may be in.
  enum CloudState {
    /// Item is on iCloud but not available locally.
    case inCloud
    /// Item is queue to be downloaded to the device
    case downloadRequested
    /// Item is currently being downloaded to the device
    case downloading
    /// Item has been downloaded and is available locally
    case downloaded
    /// Problem downloading the file from iCloud
    case downloadError
    /// Unknown state
    case unknown
  }

  /// Obtain the current iCloud state of the bookmark item
  var cloudState: CloudState {
    guard
      let values = try? url.resourceValues(forKeys: [
        .ubiquitousItemDownloadingStatusKey,
        .ubiquitousItemIsDownloadingKey,
        .ubiquitousItemDownloadingErrorKey
      ])
    else {
      return .unknown
    }
    guard values.ubiquitousItemDownloadingError == nil else { return .downloadError }
    guard let status = values.ubiquitousItemDownloadingStatus else { return .unknown }
    switch status {
    case .current: return .downloaded
    case .downloaded: return .downloading
    case .notDownloaded: return .inCloud
    default: return .unknown
    }
  }
}

private extension URL {

  var secureBookmarkData: Data? {
    let secured = self.startAccessingSecurityScopedResource()
    let data = try? self.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
    if secured { self.stopAccessingSecurityScopedResource() }
    return data
  }
}

private extension Bookmark {

  func restore() -> URL {
    let now = CFAbsoluteTimeGetCurrent()
    if let lastRestoredUrl = self.lastRestoredUrl,
       (now - lastRestoredWhen) < 1 {
      return lastRestoredUrl
    }

    let resolved = Self.resolve(from: self.bookmark)
    if resolved.stale {
      self.bookmark = resolved.url?.secureBookmarkData
      NotificationCenter.default.post(name: .bookmarkChanged, object: nil)
    }

    self.lastRestoredUrl = resolved.url
    self.lastRestoredWhen = now

    return resolved.url ?? original
  }

  static func resolve(from data: Data?) -> (url: URL?, stale: Bool) {
    guard let data = data else { return (url: nil, stale: false) }
    do {
      var isStale = false
      let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
      return (url: url, stale: isStale)
    } catch {
      return (url: nil, stale: false)
    }
  }
}

extension Bookmark: Hashable {

  /**
   Provide a hash for a bookmark. Relies on the bookmark hash value.

   - parameter hasher: the object to hash into
   */
  public func hash(into hasher: inout Hasher) { hasher.combine(bookmark) }

  /**
   Allow comparison operator for bookmarks

   - parameter lhs: first argument to compare
   - parameter rhs: second argument to compare
   - returns: true if they are the same
   */
  public static func == (lhs: Bookmark, rhs: Bookmark) -> Bool { lhs.bookmark == rhs.bookmark }
}
