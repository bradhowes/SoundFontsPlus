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
  public var isBuiltIn: Bool { kind == .builtin }
}

extension SoundFontInfo {

  public static var query: Select<SoundFontInfo.Columns.QueryValue, TaggedSoundFont, SoundFont> {
    @Shared(.activeState) var activeState
    let tagId = activeState.activeTagId ?? FontTag.Ubiquitous.all.id
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
