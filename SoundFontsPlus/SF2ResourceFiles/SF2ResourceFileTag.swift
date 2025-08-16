// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Engine

/**
 Collection of unique tags for each SF2 file in the bundle
 */
public enum SF2ResourceFileTag: Int, CaseIterable, Sendable {

  case freeFont = 1
  case museScore = 2
  case rolandNicePiano = 3

  static let freeFontFileName = "FreeFont"
  static let museScoreFileName = "GeneralUser GS MuseScore v1.442"
  static let rolandNicePianoFileName = "RolandNicePiano"

  public var id: SoundFont.ID { .init(rawValue: Int64(self.rawValue)) }

  /// Obtain the name of the SF2 resource file without suffix
  public var fileName: String {
    switch self {
    case .freeFont: return Self.freeFontFileName
    case .museScore: return Self.museScoreFileName
    case .rolandNicePiano: return Self.rolandNicePianoFileName
    }
  }

  static let freeFontName = freeFontFileName
  static let museScoreName = "MuseScore"
  static let rolandNicePianoName = "Roland Piano"

  /// Obtain the name of the SF2 resource
  public var name: String {
    switch self {
    case .freeFont: return Self.freeFontName
    case .museScore: return Self.museScoreName
    case .rolandNicePiano: return Self.rolandNicePianoName
    }
  }

  /// Obtain the `resources` index associated with the tag
  public var resourceIndex: Int { self.rawValue - 1 }

  /// Obtain the URL for an SF2 file in the bundle
  public var url: URL { SF2ResourceFiles.resources[resourceIndex] }

  /// Obtain info and preset info about an SF2 file
  public var fileInfo: Engine.SF2FileInfo? {
    var fileInfo = Engine.SF2FileInfo(url.path(percentEncoded: false))
    return fileInfo.load() ? fileInfo : nil
  }
}
