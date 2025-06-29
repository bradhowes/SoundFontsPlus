// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import SharingGRDB
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

  public init(id: SoundFont.ID, displayName: String, kind: SoundFont.Kind, location: Data) {
    self.id = id
    self.displayName = displayName
    self.kind = kind
    self.location = location
  }

  public init(soundFont: SoundFont) {
    self.init(id: soundFont.id, displayName: soundFont.displayName, kind: soundFont.kind, location: soundFont.location)
  }
}

extension SoundFontInfo {

  static var taggedQuery: Select<SoundFontInfo.Columns.QueryValue, TaggedSoundFont, SoundFont> {
    @Shared(.activeState) var activeState
    return TaggedSoundFont
      .join(SoundFont.all) {
        $0.tagId.eq(activeState.activeTagId ?? FontTag.Ubiquitous.all.id) && $0.soundFontId.eq($1.id)
      }
      .select {
        SoundFontInfo.Columns(id: $1.id, displayName: $1.displayName, kind: $1.kind, location: $1.location)
      }
      .order { $1.displayName }
  }
}
