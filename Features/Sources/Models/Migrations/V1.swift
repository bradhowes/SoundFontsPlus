import Dependencies
import Foundation
import GRDB

enum V1 {
  static let version = "SchemaV1"
  static let tables: [TableCreator.Type] = [
    // NOTE: order is important
    SoundFont.self,
    Preset.self,
    AudioConfig.self,
    DelayConfig.self,
    Favorite.self,
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
