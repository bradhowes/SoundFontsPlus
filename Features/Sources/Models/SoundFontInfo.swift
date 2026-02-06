// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Sharing
import SQLiteData
import Tagged

/**
 Subset of SoundFont table columns used to show the list of available soundfont files and the kind of font file so that the view
 can display availability info for the file.
 */
@Selection
nonisolated public struct SoundFontInfo {
  public let id: SoundFont.ID
  public let displayName: String
  public let kind: SoundFont.Kind
  public let location: Data

  public var isInstalled: Bool { kind == .installed }
  public var isExternal: Bool { kind == .external }
  public var isBuiltin: Bool { kind == .builtin }

  public init(
    id: SoundFont.ID,
    displayName: String,
    kind: SoundFont.Kind,
    location: Data
  ) {
    self.id = id
    self.displayName = displayName
    self.kind = kind
    self.location = location
  }
}

extension SoundFontInfo {

  var source: SoundFontKind? {
    withErrorReporting {
      try SoundFontKind(kind: kind, location: location, displayName: displayName)
    }
  }
}

extension SoundFontInfo {

  /**
   Obtain a query to get ``SoundFontInfo`` rows for each ``SoundFont`` associated with the given tagId. The query honors the
   ``hideBuiltinFonts`` app setting such that when enabled, there will be no entries for the built-in sound fonts in the
   query output.

   - parameter tagId: the tag to look for. If `nil` then use the value found in ``ActiveState``. If that is also `nil` then
   return rows for all ``SoundFont`` entries.
   - returns: a query that produces a row for each associated ``SoundFont``
   */
  public static func query(for tagId: Tag.ID) -> Select<Columns.QueryValue, TaggedSoundFont, SoundFont> {
    @Shared(.hideBuiltinFonts) var hideBuiltinFonts
    return TaggedSoundFont
      .join(hideBuiltinFonts ? (SoundFont.all.where { $0.kind.neq(SoundFont.Kind.builtin) }) : SoundFont.all) {
        $0.tagId.eq(tagId) && $0.soundFontId.eq($1.id)
      }
      .select {
        Columns(id: $1.id, displayName: $1.displayName, kind: $1.kind, location: $1.location)
      }
      .order { $1.displayName }
  }
}

extension SoundFontInfo: Equatable, Identifiable, Sendable {}
