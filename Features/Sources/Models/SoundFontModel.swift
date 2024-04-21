// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData


public struct Location: Codable, Equatable {
  public enum Kind: String, Codable, CaseIterable {
    case builtin
    case installed
    case bookmark
  }

  /// The kind of SF2 file
  public let kind: Kind
  /// Location of a builtin or installed SF2 file
  public let url: URL?
  /// Bookmark data for a file that is outside of the sandbox documents directory
  public let bookmark: Data?
}


@Model
public final class SoundFontModel {

  @Attribute(.unique) public let id: String
  public var name: String
  public var location: Location
  public var visible: Bool = true

  @Relationship(deleteRule: .cascade) private let presets: [PresetModel]

  public var tags: [TagModel] = []

  public let originalDisplayName: String
  public let embeddedName: String
  public let embeddedComment: String
  public let embeddedAuthor: String
  public let embeddedCopyright: String

  public init(id: UUID,
              name: String,
              location: Location,
              presets: [PresetModel],
              embeddedName: String,
              embeddedComment: String,
              embeddedAuthor: String,
              embeddedCopyright: String) {
    self.id = id.uuidString
    self.location = location
    self.name = name
    self.presets = presets
    self.originalDisplayName = name
    self.embeddedName = embeddedName
    self.embeddedComment = embeddedComment
    self.embeddedAuthor = embeddedAuthor
    self.embeddedCopyright = embeddedCopyright
  }

  var kind: SoundFontKind {
    switch location.kind {
    case .builtin: return .builtin(resource: location.url!)
    case .installed: return .installed(file: location.url!)
    case .bookmark:
      guard let bookmark = try? Bookmark.from(data: location.bookmark!) else { fatalError("invalid Bookmark") }
      return .reference(bookmark: bookmark)
    }
  }
}
