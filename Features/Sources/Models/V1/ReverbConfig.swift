import AVFoundation
import Dependencies
import GRDB
import Tagged

public struct ReverbConfig: Codable, FetchableRecord, MutablePersistableRecord {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public var preset: Int
  public var wetDryMix: AUValue
  public var enabled: Bool

  static func make(db: Database) throws -> ReverbConfig {
    try PendingReverbConfig(preset: 0, wetDryMix: 0.5, enabled: true).insertAndFetch(db, as: ReverbConfig.self)
  }

  func duplicate(db: Database) throws -> DelayConfig {
    try PendingReverbConfig(
      preset: preset,
      wetDryMix: wetDryMix,
      enabled: enabled
    ).insertAndFetch(db, as: DelayConfig.self)
  }
}

extension ReverbConfig: TableCreator {
  public static let databaseTableName = "ReverbConfig"

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let preset = Column(CodingKeys.preset)
    static let wetDryMix = Column(CodingKeys.wetDryMix)
    static let enabled = Column(CodingKeys.enabled)
  }

  static func createTable(in db: Database) throws {
    try db.create(table: databaseTableName) { table in
      table.autoIncrementedPrimaryKey(Columns.id)
      table.column(Columns.preset, .integer).notNull()
      table.column(Columns.wetDryMix, .double).notNull()
      table.column(Columns.enabled, .boolean).notNull()
    }
  }
}

struct PendingReverbConfig: Codable, FetchableRecord, PersistableRecord {
  let preset: Int
  let wetDryMix: AUValue
  let enabled: Bool

  public static let databaseTableName = ReverbConfig.databaseTableName
}
