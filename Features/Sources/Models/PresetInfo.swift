// Copyright © 2026 Brad Howes. All rights reserved.

import Foundation
import Sharing
public import SQLiteData
public import Tagged

@Selection
nonisolated public struct PresetInfo {
  public let id: Preset.ID
  public let displayName: String
  public var kind: Preset.Kind
  public let index: Int

  public var isFavorite: Bool { kind == .favorite }

  public mutating func toggleVisibility() {
    if var preset = Preset.with(id: id) {
      preset.toggleVisibility()
      kind = preset.kind
    }
  }

  public func cloneFavorite() -> PresetInfo? {
    guard
      let preset = Preset.with(id: id),
      let clone = preset.cloneFavorite()
    else {
      return nil
    }
    return .init(id: clone.id, displayName: clone.displayName, kind: clone.kind, index: clone.index)
  }
}

extension PresetInfo {

  /**
   Obtain a query that returns an ordered collection of `PresetInfo` values to show for a given sound font ID. Honors the
   `favoritesOnTop` and `sortPresetsByName` settings which affect the ordering. These two options offer 4 unique orderings of the
   records:

   - false / false -- ordered by preset index with favorites appearing immediately after their source preset
   - false / true -- ordered by entry name with favorites appearing after presets with the same name
   - true / false -- favorites appear first as a group, then presets with both ordered by their preset index
   - true / true -- favorites appears first as a group, then presets with both ordered by their display name

   - parameter soundFontId: the sound font to query for
   - returns: the select query to generate the `PresetInfo` records.
   */
  public static func visibleQuery(for soundFontId: SoundFont.ID) -> Select<PresetInfo.Selection.QueryValue, Preset, ()> {
    Preset
      .visibleQuery(for: soundFontId)
      .select {
        Columns(id: $0.id, displayName: $0.displayName, kind: $0.kind, index: $0.index)
      }
  }

  /**
   Obtain the collection of `PresetInfo` values for a given sound font ID, filterering out any that have been hidden by the user.

   - parameter soundFontId: the sound font to query for
   - returns: the collection of presets
   */
  public static func visible(for soundFontId: SoundFont.ID) -> [PresetInfo] {
    withDatabaseReader {
      try visibleQuery(for: soundFontId).fetchAll($0)
    } ?? []
  }

  /**
   Obtain a query that returns an ordered collection of `PresetInfo` values to show for a given sound font ID.

   - parameter soundFontId: the sound font to query for
   - returns: the select query to generate the collection `PresetInfo` records.
   */
  /// - returns: query for all presets (no favorites).
  public static func allQuery(for soundFontId: SoundFont.ID) -> Select<PresetInfo.Selection.QueryValue, Preset, ()> {
    Preset.allQuery(for: soundFontId)
      .select {
        Columns(id: $0.id, displayName: $0.displayName, kind: $0.kind, index: $0.index)
      }
  }

  /**
   Obtain the collection of `PresetInfo` values for a given sound font ID. Does not perform any filtering of hidden presets.
   Used when editing preset visibility.

   - parameter soundFontId: the sound font to query for
   - returns: the collection of presets
   */
  public static func all(for soundFontId: SoundFont.ID) -> [PresetInfo] {
    withDatabaseReader {
      try allQuery(for: soundFontId).fetchAll($0)
    } ?? []
  }

  /**
   Obtain a `PresetInfo` instance for the given preset ID.

   - parameter id: the `Preset.ID` to fetch
   - returns: the found instance
   */
  public static func with(id: Preset.ID) -> PresetInfo? {
    withDatabaseReader { db in
      try Preset.all
        .where {
          $0.id.eq(id)
        }
        .select {
          Columns(id: $0.id, displayName: $0.displayName, kind: $0.kind, index: $0.index)
        }
        .fetchOne(db)
    } ?? nil
  }
}

extension PresetInfo: Equatable, Identifiable, Sendable {}
