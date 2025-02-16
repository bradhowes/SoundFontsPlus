import AVFoundation
import Dependencies
import GRDB
import Tagged

public struct DelayConfig: Codable, FetchableRecord, MutablePersistableRecord {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public var time: AUValue
  public var feedback: AUValue
  public var cutoff: AUValue
  public var wetDryMix: AUValue
  public var enabled: Bool

  static func make(db: Database) throws -> DelayConfig {
    try PendingDelayConfig(
      time: 0.0,
      feedback: 0.0,
      cutoff: 0.0,
      wetDryMix: 0.5,
      enabled: true
    ).insertAndFetch(db, as: DelayConfig.self)
  }

  func duplicate(db: Database) throws -> DelayConfig {
    try PendingDelayConfig(
      time: time,
      feedback: feedback,
      cutoff: cutoff,
      wetDryMix: wetDryMix,
      enabled: enabled
    ).insertAndFetch(db, as: DelayConfig.self)
  }
}

extension DelayConfig: TableCreator {

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let time = Column(CodingKeys.time)
    static let feedback = Column(CodingKeys.feedback)
    static let cutoff = Column(CodingKeys.cutoff)
    static let wetDryMix = Column(CodingKeys.wetDryMix)
    static let enabled = Column(CodingKeys.enabled)
  }

  static func createTable(in db: Database) throws {
    try db.create(table: databaseTableName) { table in
      table.autoIncrementedPrimaryKey(Columns.id)
      table.column(Columns.time, .double).notNull()
      table.column(Columns.feedback, .double).notNull()
      table.column(Columns.cutoff, .double).notNull()
      table.column(Columns.wetDryMix, .double).notNull()
      table.column(Columns.enabled, .boolean).notNull()
    }
  }
}

struct PendingDelayConfig: Codable, FetchableRecord, PersistableRecord {
  let time: AUValue
  let feedback: AUValue
  let cutoff: AUValue
  let wetDryMix: AUValue
  let enabled: Bool

  static let databaseTableName = DelayConfig.databaseTableName
}
