import AVFoundation
import Dependencies
import GRDB
import Tagged

public struct AudioConfig: Codable, FetchableRecord, MutablePersistableRecord {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID

  public var gain: AUValue
  public var pan: AUValue
  public var keyboardLowestNoteEnabled: Bool

  public var keyboardLowestNote: Int?
  public var pitchBendRange: Int?
  public var presetTuning: AUValue?
  public var presetTranspose: Int?

  public let favoriteId: Favorite.ID?
  public let presetId: Preset.ID?

  @discardableResult
  static func make(_ db: Database, favoriteId: Favorite.ID? = nil, presetId: Preset.ID? = nil) throws -> AudioConfig {
    precondition(favoriteId != nil || presetId != nil)
    return try PendingAudioConfig(
      gain: 1.0,
      pan: 0.0,
      keyboardLowestNoteEnabled: false,
      keyboardLowestNote: nil,
      pitchBendRange: nil,
      presetTuning: nil,
      presetTranspose: nil,
      favoriteId: favoriteId,
      presetId: presetId
    ).insertAndFetch(db, as: Self.self)
  }

  @discardableResult
  public func duplicate(
    _ db: Database,
    favoriteId: Favorite.ID? = nil,
    presetId: Preset.ID? = nil
  ) throws -> AudioConfig {
    precondition(favoriteId != nil || presetId != nil)
    let dup = try PendingAudioConfig(
      gain: gain,
      pan: pan,
      keyboardLowestNoteEnabled: keyboardLowestNoteEnabled,
      keyboardLowestNote: keyboardLowestNote,
      pitchBendRange: pitchBendRange,
      presetTuning: presetTuning,
      presetTranspose: presetTranspose,
      favoriteId: favoriteId,
      presetId: presetId
    ).insertAndFetch(db, as: Self.self)

    if let dc = try self.reverbConfig.fetchOne(db) {
      try dc.duplicate(db, for: dup.id)
    }

    if let rc = try self.delayConfig.fetchOne(db) {
      try rc.duplicate(db, for: dup.id)
    }

    return dup
  }
}

private struct PendingAudioConfig: Codable, PersistableRecord {
  let gain: Float
  let pan: Float
  let keyboardLowestNoteEnabled: Bool
  let keyboardLowestNote: Int?
  let pitchBendRange: Int?
  let presetTuning: Float?
  let presetTranspose: Int?
  let favoriteId: Favorite.ID?
  let presetId: Preset.ID?

  static let databaseTableName = AudioConfig.databaseTableName
}

extension AudioConfig: Equatable, Sendable {}

extension AudioConfig: TableCreator {

  public enum Columns {
    static let id = Column(CodingKeys.id)
    static let gain = Column(CodingKeys.gain)
    static let pan = Column(CodingKeys.pan)
    static let keyboardLowestNoteEnabled = Column(CodingKeys.keyboardLowestNoteEnabled)
    static let keyboardLowestNote = Column(CodingKeys.keyboardLowestNote)
    static let pitchBendRange = Column(CodingKeys.pitchBendRange)
    static let presetTuning = Column(CodingKeys.presetTuning)
    static let presetTranspose = Column(CodingKeys.presetTranspose)
    static let presetId = Column(CodingKeys.presetId)
    static let favoriteId = Column(CodingKeys.favoriteId)
  }

  static func createTable(in db: Database) throws {
    try db.create(table: databaseTableName, options: .ifNotExists) { table in
      table.autoIncrementedPrimaryKey(Columns.id)
      table.column(Columns.gain, .double).notNull()
      table.column(Columns.pan, .double).notNull()
      table.column(Columns.keyboardLowestNoteEnabled, .boolean).notNull()

      table.column(Columns.keyboardLowestNote, .integer)
      table.column(Columns.pitchBendRange, .integer)
      table.column(Columns.presetTuning, .double)
      table.column(Columns.presetTranspose, .integer)

      // One AudioConfig belongs to either a preset or a favorite, but never both. So, either can be NULL but not
      // both.
      table.uniqueKey([Columns.presetId.name, Columns.favoriteId.name])
      table.belongsTo(Favorite.databaseTableName, onDelete: .cascade)
      table.belongsTo(Preset.databaseTableName, onDelete: .cascade)
    }
  }
}

extension AudioConfig {
  static let delayConfig = hasOne(DelayConfig.self)
  public var delayConfig: QueryInterfaceRequest<DelayConfig> { request(for: Self.delayConfig) }

  static let reverbConfig = hasOne(ReverbConfig.self)
  public var reverbConfig: QueryInterfaceRequest<ReverbConfig> { request(for: Self.reverbConfig) }
}
