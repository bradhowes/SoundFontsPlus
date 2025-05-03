import Dependencies
import Foundation
import GRDB

enum V1 {
  static let version = "SchemaV1"
  static let tables: [TableCreator.Type] = [
    // NOTE: order is important for GRDB - tables that are pointed to in `belongsTo` (eg. SoundFont) need to appear
    // before the table(s) that contain(s) `belongsTo` statements (eg. Preset).
    SoundFont.self,
    Preset.self,
    Favorite.self,
    AudioConfig.self,
    DelayConfig.self,
    ReverbConfig.self,
    Tag.self,
    TaggedSoundFont.self
  ]

  static func migration(_ db: Database) throws {
    for each in V1.tables {
      try each.createTable(in: db)
    }
  }
}

extension DatabaseWriter {

  public func migrate() throws {
    var migrator = DatabaseMigrator()
    // migrator.eraseDatabaseOnSchemaChange = true
    migrator.registerMigration(V1.version) { db in
      try V1.migration(db)
    }

    try migrator.migrate(self)
  }
}
