// Copyright © 2025 Brad Howes. All rights reserved.

import Clocks
import Dependencies
public import Foundation

/**
 A bookmark represents a file located outside of the app's sandboxed storage space or that of an app group. It is used to reference
 sound font files without making a copy of them. However there are risks involved, namely that the bookmark may not resolve to a
 real file.
 */
public final class Bookmark: Codable {
  public enum CodingKeys: CodingKey {
    case name
    case bookmark
    case original
  }

  /// The name of the sound font represented by the bookmark
  public let name: String
  /// The latest bookmark data from the URL
  public private(set) var bookmark: Data?
  /// The original URL that was picked by the user
  public let original: URL
  /// The current URL that may have deviated from the original
  public var url: URL { restore() }

  /// Cache of the last restored URL. Used to reduce churn due to UI updates.
  private var lastRestoredUrl: URL?
  private var lastRestoredWhen: CFTimeInterval = 0

  /// Determine the availability state for a bookmarked URL.
  public var isAvailable: Bool {
    url.withSecurityScoping { url in
      do {
        return try url.checkResourceIsReachable()
      } catch CocoaError.fileReadNoSuchFile {
        log.error("Bookmark.isAvaible - file does not exist")
        return false
      }
    } ?? false
  }

  /// Determine if the file is located in an iCloud container
  public var isUbiquitous: Bool {
    url.withSecurityScoping { url in
      @Dependency(\.fileManager.isUbiquitousItem) var isUbiquitousItem
      return isUbiquitousItem(url)
    } ?? false
  }

  public var urlState: URLState {
    url.withSecurityScoping { url in
      @Dependency(\.urlStateProvider) var urlStateProvider
      return urlStateProvider(url)
    }
  }
  /**
   Construct a new bookmark.

   - parameter url: the file to bookmark
   - parameter name: the name to associate with the bookmark
   */
  public init(url: URL, name: String) {
    log.info("init - url: \(url, privacy: .public), name: \(name, privacy: .public)")
    self.name = name
    original = url
    bookmark = url.secureBookmarkData
  }

  /**
   Attempt to reconstitute a bookmark from an encoded container

   - parameter decoder: the container to read from
   - throws exception if unable to decode from container
   */
  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    name = try values.decode(String.self, forKey: .name)
    original = try values.decode(URL.self, forKey: .original)
    bookmark = try values.decode(Data.self, forKey: .bookmark)
  }
}

extension Bookmark {

  /**
   Create a Bookmark from the contents of a Data instance.

   - parameter data: the container to decode
   - returns: new Bookmark instance
   */
  public static func from(data: Data) throws -> Bookmark {
    let decoder = PropertyListDecoder()
    return try decoder.decode(Bookmark.self, from: data)
  }

  /**
   Encode the Bookmark into a Data container.

   - returns: the container holding the encoded bookmark data
   */
  public func toData() throws -> Data {
    let encoder = PropertyListEncoder()
    return try encoder.encode(self)
  }

}

extension Bookmark {

  static let lastRestoreAgeLimit = 2.0

  private func restore() -> URL {
    @Dependency(\.fileManager) var fileManager
    let now = CFAbsoluteTimeGetCurrent()
    if let lastRestoredUrl = self.lastRestoredUrl,
       (now - lastRestoredWhen) < Self.lastRestoreAgeLimit,
       fileManager.fileExists(lastRestoredUrl) {
      return lastRestoredUrl
    }

    let (resolved, stale) = Self.resolve(from: self.bookmark)
    if let resolved {
      if stale {
        self.bookmark = resolved.secureBookmarkData
      }
      self.lastRestoredUrl = resolved
      self.lastRestoredWhen = CFAbsoluteTimeGetCurrent()
    } else if fileManager.fileExists(original) {
      // This is probably wrong, but trying anyway.
      let (resolved, _) = Self.resolve(from: self.original.secureBookmarkData)
      if let resolved {
        self.bookmark = resolved.secureBookmarkData
      }
      self.lastRestoredUrl = resolved
      self.lastRestoredWhen = CFAbsoluteTimeGetCurrent()
    }

    // Last-ditch attempt when restoring fails is to just return the original URL obtained by the picker.
    return resolved ?? original
  }

  private static func resolve(from data: Data?) -> (url: URL?, stale: Bool) {
    guard let data = data else { return (url: nil, stale: false) }
    do {
      var isStale = false
      let url = try URL(
        resolvingBookmarkData: data,
        options: [],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
      return (url: url, stale: isStale)
    } catch {
      return (url: nil, stale: false)
    }
  }
}

extension Bookmark: Equatable {

  /**
   Allow comparison operator for bookmarks

   - parameter lhs: first argument to compare
   - parameter rhs: second argument to compare
   - returns: true if they are the same
   */
  public static func == (lhs: Bookmark, rhs: Bookmark) -> Bool { lhs.bookmark == rhs.bookmark }
}

private let log: Logger = .init(category: "Bookmark")
