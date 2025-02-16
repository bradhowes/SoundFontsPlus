// Copyright © 2025 Brad Howes. All rights reserved.

import Engine
import Foundation
import GRDB
import IdentifiedCollections
import Tagged

public struct Preset: Codable, Identifiable, FetchableRecord, MutablePersistableRecord {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public var displayName: String
  public let index: Int
  public let bank: Int
  public let program: Int
  public var visible: Bool
  public let originalName: String
  public var notes: String

  public static func make(
    in db: Database,
    soundFont: SoundFont.ID,
    index: Int,
    presetInfo: SF2PresetInfo
  ) throws -> Preset {
    try PendingPreset(
      soundFont: soundFont,
      displayName: String(presetInfo.name()),
      index: index,
      bank: Int(presetInfo.bank()),
      program: Int(presetInfo.program())
    ).insertAndFetch(db, as: Preset.self)
  }
}

extension Preset: TableCreator {
  public static let soundFont = belongsTo(SoundFont.self)

  public var soundFont: QueryInterfaceRequest<SoundFont> {
    request(for: Self.soundFont)
  }

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let displayName = Column(CodingKeys.displayName)
    static let index = Column(CodingKeys.index)
    static let bank = Column(CodingKeys.bank)
    static let program = Column(CodingKeys.program)
    static let visible = Column(CodingKeys.visible)
    static let originalName = Column(CodingKeys.originalName)
    static let notes = Column(CodingKeys.notes)
  }

  static func createTable(in db: Database) throws {
    try db.create(table: databaseTableName) { table in
      table.autoIncrementedPrimaryKey(Columns.id)
      table.column(Columns.displayName, .text).notNull()
      table.column(Columns.index, .integer).notNull()
      table.column(Columns.bank, .integer).notNull()
      table.column(Columns.program, .integer).notNull()
      table.column(Columns.visible, .boolean).notNull()
      table.column(Columns.originalName, .text).notNull()
      table.column(Columns.notes, .text).notNull()
      table.belongsTo(SoundFont.databaseTableName, onDelete: .cascade).notNull()
    }

    // Create associated table used for full-text searching of the preset display names
//    try db.create(virtualTable: "preset_ft", using: FTS5()) { table in
//      table.synchronize(withTable: Preset.databaseTableName)
//      table.column(Preset.Columns.displayName.name)
//    }
  }
}

extension Preset: Hashable, Sendable {}
public typealias PresetCollection = IdentifiedArrayOf<Preset>

struct PendingPreset: Codable, FetchableRecord, PersistableRecord {
  public let displayName: String
  public let index: Int
  public let bank: Int
  public let program: Int
  public let visible: Bool
  public let originalName: String
  public let notes: String
  public let soundFontId: SoundFont.ID

  init(soundFont: SoundFont.ID, displayName: String, index: Int, bank: Int, program: Int) {
    self.soundFontId = soundFont
    self.displayName = displayName
    self.index = index
    self.bank = bank
    self.program = program
    self.visible = true
    self.originalName = displayName
    self.notes = ""
  }

  public static let databaseTableName = Preset.databaseTableName
}
