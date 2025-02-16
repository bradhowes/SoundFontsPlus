import AVFoundation
import Dependencies
import GRDB
import Tagged

public struct AudioConfig: Codable, FetchableRecord, MutablePersistableRecord {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public var keyboardLowestNote: Int?
  public var keyboardLowestNoteEnabled: Bool
  public var pitchBendRange: Int?
  public var gain: AUValue
  public var pan: AUValue
  public var presetTuning: AUValue
  public var presetTranspose: Int?

  static func make(db: Database) throws -> AudioConfig {
    try PendingAudioConfig().insertAndFetch(db, as: AudioConfig.self)
  }
}

extension AudioConfig: TableCreator {

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let keyboardLowestNote = Column(CodingKeys.keyboardLowestNote)
    static let keyboardLowestNoteEnabled = Column(CodingKeys.keyboardLowestNoteEnabled)
    static let pitchBendRange = Column(CodingKeys.pitchBendRange)
    static let gain = Column(CodingKeys.gain)
    static let pan = Column(CodingKeys.pan)
    static let presetTuning = Column(CodingKeys.presetTuning)
    static let presetTranspose = Column(CodingKeys.presetTranspose)
  }

  static func createTable(in db: Database) throws {
    try db.create(table: databaseTableName) { table in
      table.autoIncrementedPrimaryKey(Columns.id)
      table.column(Columns.keyboardLowestNote, .integer)
      table.column(Columns.keyboardLowestNoteEnabled, .boolean)
      table.column(Columns.gain, .double).notNull()
      table.column(Columns.pan, .double).notNull()
      table.column(Columns.presetTuning, .double).notNull()
      table.column(Columns.presetTranspose, .integer)
    }
  }
}

struct PendingAudioConfig: Codable, FetchableRecord, PersistableRecord {
  let keyboardLowestNote: Int?
  let keyboardLowestNoteEnabled: Bool
  let pitchBendRange: Int?
  let gain: Float
  let pan: Float
  let presetTuning: Float?
  let presetTranspose: Int?

  init() {
    keyboardLowestNote = nil
    keyboardLowestNoteEnabled = false
    pitchBendRange = nil
    gain = 1.0
    pan = 0.0
    presetTuning = nil
    presetTranspose = nil
  }

  public static let databaseTableName = AudioConfig.databaseTableName
}
