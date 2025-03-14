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
  public let audioConfigId: AudioConfig.ID

  static func make(_ db: Database, for audioConfigId: AudioConfig.ID) throws -> ReverbConfig {
    try PendingReverbConfig(
      preset: 0,
      wetDryMix: 0.5,
      enabled: true,
      audioConfigId: audioConfigId
    ).insertAndFetch(db, as: Self.self)
  }

  @discardableResult
  func duplicate(_ db: Database, for audioConfigId: AudioConfig.ID) throws -> ReverbConfig {
    try PendingReverbConfig(
      preset: preset,
      wetDryMix: wetDryMix,
      enabled: enabled,
      audioConfigId: audioConfigId
    ).insertAndFetch(db, as: Self.self)
  }
}

private struct PendingReverbConfig: Codable, PersistableRecord {
  let preset: Int
  let wetDryMix: AUValue
  let enabled: Bool
  let audioConfigId: AudioConfig.ID?

  static let databaseTableName = ReverbConfig.databaseTableName
}

extension ReverbConfig: Equatable, Sendable {}

extension ReverbConfig: TableCreator {
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

      table.belongsTo(AudioConfig.databaseTableName, onDelete: .cascade)
        .notNull()
        .unique()
    }
  }
}

// MARK: AudioConfig association
extension ReverbConfig {
  static let audioConfig = belongsTo(AudioConfig.self)

  var audioConfig: QueryInterfaceRequest<AudioConfig> { request(for: Self.audioConfig) }
}
