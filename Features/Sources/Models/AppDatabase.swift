// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Dependencies
import Foundation
import GRDB
import OSLog
import Sharing
import SF2Resources
import SQLite3
import SQLiteData

private let log = Logger(category: "appDatabase")

// swiftlint:disable:next function_body_length
public func appDatabase(
  fonts: [SF2ResourceTag] = SF2ResourceTag.allCases,
  loadAllPresets: Bool = true,
  seeder: ((Database) throws -> Void)? = nil
) throws -> any DatabaseWriter {
  @Dependency(\.context) var context
  @Shared(.sqlContentionTimeout) var sqlContentionTimeout

  var database: any DatabaseWriter
  var configuration = GRDB.Configuration()

  log.info("appDatabase BEGIN - fonts: \(fonts) loadAllPresets: \(loadAllPresets)")

  configuration.foreignKeysEnabled = true

#if DEBUG

  if !ProcessInfo.processInfo.isOnGithub {
    print("isOnGithub is false")

    // Automatically handle any SQL access contention as long as it can be handled in `sqlContentionTimeout` seconds.
    configuration.busyMode = .timeout(sqlContentionTimeout)

    // Enable suspend notification processing.
    configuration.observesSuspensionNotifications = true

    configuration.prepareDatabase { db in
      db.trace(options: .profile) {
        if context == .live {
          log.debug("\($0.expandedDescription)")
        } else {
          print("\($0.expandedDescription)")
        }
      }

      if db.configuration.readonly == false {
        var flag: CInt = 1
        let code = unsafe withUnsafeMutablePointer(to: &flag) { flagP in
          unsafe sqlite3_file_control(db.sqliteConnection, nil, SQLITE_FCNTL_PERSIST_WAL, flagP)
        }
        guard code == SQLITE_OK else {
          throw DatabaseError(resultCode: ResultCode(rawValue: code))
        }
      }
    }
  }

#endif // DEBUG

  if context == .live {
    let databaseURL: URL = FileManager.default.sharedDocumentsDirectory.appending(component: "db.sqlite")
    let coordinator = NSFileCoordinator(filePresenter: nil)
    var dbPool: DatabasePool?
    var coordinatorError: NSError?
    var dbError: Error?
    unsafe coordinator.coordinate(writingItemAt: databaseURL, options: .forMerging, error: &coordinatorError) { url in
      do {
        log.info("opening \(url)")
        dbPool = try DatabasePool(path: url.path(), configuration: configuration)
      } catch {
        dbError = error
      }
    }

    if let error = dbError ?? coordinatorError {
      throw error
    } else if let dbPool {
      database = dbPool
    } else {
      fatalError("Failed to create DatabasePool instance")
    }
  } else {
    // In-memory database for testing and previews (no sharing)
    database = try DatabaseQueue(configuration: configuration)
  }

  try performMigrations(
    database,
    fonts: fonts,
    limitedLoading: context == .test && loadAllPresets == false,
    seeder: seeder
  )

  return database
}

private func performMigrations(
  _ database: DatabaseWriter,
  fonts: [SF2ResourceTag],
  limitedLoading: Bool,
  seeder: (
    (Database) throws -> Void
  )?
) throws {
  @Dependency(\.context) var context
  var migrator = DatabaseMigrator()

#if DEBUG
  migrator.eraseDatabaseOnSchemaChange = true
#endif // DEBUG

  SoundFont.migrate(&migrator)
  Preset.migrate(&migrator)
  AudioConfig.migrate(&migrator)
  DelayConfig.migrate(&migrator)
  ReverbConfig.migrate(&migrator)
  FontTag.migrate(&migrator)
  TaggedSoundFont.migrate(&migrator)
  MIDIConfig.migrate(&migrator)

  migrator.registerMigration("Add ubiquitous tags") { db in
    let drafts: [FontTag.Draft] = FontTag.Ubiquitous.allCases.enumerated().map {
      .init(displayName: $0.1.displayName, ordering: $0.0)
    }
    try FontTag.insert {
      drafts
    }.execute(db)
  }

  migrator.registerMigration("Add builtin fonts") { db in
    for sf2 in fonts {
      log.info("add \(sf2)")
      try SoundFont.addBuiltIn(db, sf2: sf2, limitedLoading: limitedLoading)
    }
  }

  try migrator.migrate(database)

  if !fonts.isEmpty {
    // Update locations of builtin SF2 files everytime we startup since app container location could change.
    try database.write { db in
      for sf2 in SF2ResourceTag.allCases {
        withErrorReporting {
          let soundFontKind: SoundFontKind = .builtin(resource: sf2.url)
          let (kind, location) = try soundFontKind.data()
          try SoundFont
            .where { $0.id.eq(sf2.id) }
            .update {
              $0.kind = kind
              $0.location = location
            }.execute(db)
        }
      }
    }
  }

  if let seeder {
    try database.write { db in
      try seeder(db)
    }
  }
}

public func previewDatabase(
  fonts: [SF2ResourceTag] = [.fluidFont, .rolandNicePiano],
  loadAllPresets: Bool = false,
  seeder: ((Database) throws -> Void)? = nil
) -> any DatabaseWriter {
  try! appDatabase(fonts: fonts, loadAllPresets: loadAllPresets, seeder: seeder)
}

