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

  func migrate() throws {
    var migrator = DatabaseMigrator()

#if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
#endif

    migrator.registerMigration(V1.version) { db in
      try V1.migration(db)

#if targetEnvironment(simulator)
      if !isTesting {
        for each in V1.tables {
          _ = try each.deleteAll(db)
        }
      }
#endif
    }

    try migrator.migrate(self)
  }
}
