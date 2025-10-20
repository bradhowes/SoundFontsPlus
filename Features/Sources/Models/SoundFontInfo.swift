// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Sharing
import SQLiteData
import Tagged

/**
 Subset of SoundFont table columns used to show the list of available soundfont files.
 */
@Selection
public struct SoundFontInfo: Equatable, Identifiable, Sendable {
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

  public static func fetch(for soundFontId: SoundFont.ID) -> SoundFontInfo? {
    withDatabaseReader { db in
      try SoundFont.all
        .where({ $0.id.eq(soundFontId) })
        .select {
          SoundFontInfo.Columns(id: $0.id, displayName: $0.displayName, kind: $0.kind, location: $0.location)
        }
        .fetchAll(db)
    }?.first
  }

  public static func query(id tagId: FontTag.ID? = nil) -> Select<Self.Columns.QueryValue, TaggedSoundFont, SoundFont> {
    @Shared(.activeState) var activeState
    let tagId = tagId ?? activeState.activeTagId ?? FontTag.Ubiquitous.all.id
    return TaggedSoundFont
      .join(SoundFont.all) {
        $0.tagId.eq(tagId) && $0.soundFontId.eq($1.id)
      }
      .select {
        SoundFontInfo.Columns(id: $1.id, displayName: $1.displayName, kind: $1.kind, location: $1.location)
      }
      .order { $1.displayName }
  }
}
