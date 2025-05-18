import Dependencies
import Engine
import Foundation
import OSLog
import SF2ResourceFiles
import SharingGRDB

private let logger = Logger(subsystem: "SoundFonts", category: "Database")

func appDatabase() throws -> any DatabaseWriter {
  @Dependency(\.context) var context

  let database: any DatabaseWriter
  var configuration = Configuration()

  configuration.foreignKeysEnabled = true
  configuration.prepareDatabase { db in

#if DEBUG
    db.trace(options: .profile) {
      if context == .live {
        logger.debug("\($0.expandedDescription)")
      } else {
        print("\($0.expandedDescription)")
      }
    }
#endif
  }

  if context == .live {
    let path = URL.documentsDirectory.appending(component: "db.sqlite").path()
    logger.info("open \(path)")
    database = try DatabasePool(path: path, configuration: configuration)
  } else {
    database = try DatabaseQueue(configuration: configuration)
  }

  var migrator = DatabaseMigrator()
#if DEBUG
  migrator.eraseDatabaseOnSchemaChange = true
#endif

  SoundFont.migrate(&migrator)
  Preset.migrate(&migrator)
  Favorite.migrate(&migrator)
  AudioConfig.migrate(&migrator)
  DelayConfig.migrate(&migrator)
  ReverbConfig.migrate(&migrator)
  Models.Tag.migrate(&migrator)
  TaggedSoundFont.migrate(&migrator)

  migrator.registerMigration("Add ubiquitous tags") { db in
    let drafts: [Tag.Draft] = Tag.Ubiquitous.allCases.enumerated().map {
      .init(displayName: $0.1.displayName, ordering: $0.0)
    }
    try Tag.insert(drafts).execute(db)
  }

  migrator.registerMigration("Add builtin fonts") { db in
    for sf2 in SF2ResourceFileTag.allCases {
      SoundFont.insert(db, sf2: sf2)
    }
  }

#if DEBUG && targetEnvironment(simulator)
  if context != .test {
    migrator.registerMigration("Seed sample data") { db in
      try db.seedSampleData()
    }
  }
#endif

  try migrator.migrate(database)

  return database
}

#if DEBUG
extension Database {
  func seedSampleData() throws {
  }
}
#endif
