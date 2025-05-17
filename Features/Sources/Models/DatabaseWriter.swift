import Dependencies
import Engine
import Foundation
import SF2ResourceFiles
import SharingGRDB

public extension DatabaseWriter where Self == DatabaseQueue {

  static func appDatabase(
    path: URL? = nil,
    configuration: Configuration? = nil,
    addTags: Bool = true,
    addBuiltIns: Bool = true
  ) throws -> Self {
    var config = configuration ?? Configuration()
    config.foreignKeysEnabled = true
    #if DEBUG
        config.publicStatementArguments = true
    config.prepareDatabase {
      db in db.trace {
        print($0)
      }
    }
    #endif

    let databaseQueue: DatabaseQueue

    @Dependency(\.context) var context

    if context == .live {
      let dbPath = (path ?? URL.documentsDirectory.appending(component: "db.sqlite")).path()
      databaseQueue = try DatabaseQueue(path: dbPath, configuration: config)
      print("open \(dbPath)")
    } else {
      databaseQueue = try DatabaseQueue(configuration: config)
    }

    var migrator = DatabaseMigrator()
#if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
#endif

    V1.migrate(into: &migrator)

    migrator.registerMigration("Add ubiquitous tags") { db in
      for tag in Tag.Ubiquitous.allCases.enumerated() {
        try Tag.from(ubi: tag).execute(db)
      }
    }

    migrator.registerMigration("Add builtin fonts") { db in
      for sf2 in SF2ResourceFileTag.allCases {
        try SoundFont.from(sf2: sf2).execute(db)
      }
    }

#if DEBUG && targetEnvironment(simulator)
    if context != .test {
      migrator.registerMigration("Seed sample data") { db in
        try db.seedSampleData()
      }
    }
#endif

    return databaseQueue
  }
}

#if DEBUG
extension Database {
  func seedSampleData() throws {
  }
}
#endif
