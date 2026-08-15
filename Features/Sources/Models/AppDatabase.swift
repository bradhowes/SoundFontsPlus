// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Dependencies
import Foundation
import GRDB
import OSLog
import Sharing
public import SF2Resources
import SQLite3
public import SQLiteData
import Tagged

private let log: Logger = .init(category: "appDatabase")

// swiftlint:disable:next function_body_length
public func appDatabase(
  fonts: [SF2ResourceTag] = SF2ResourceTag.allCases,
  loadAllPresets: Bool = true,
  readOnly: Bool = false,
  seeder: ((Database) throws -> Void)? = nil
) throws -> any DatabaseWriter {
  @Dependency(\.context) var context
  @Dependency(\.fileManager) var fileManager
  @Shared(.sqlContentionTimeout) var sqlContentionTimeout

  var database: any DatabaseWriter
  var configuration = GRDB.Configuration()

  log.info("appDatabase BEGIN - fonts: \(fonts) loadAllPresets: \(loadAllPresets)")

  configuration.foreignKeysEnabled = true
  configuration.readonly = readOnly

  if !ProcessInfo.processInfo.isOnGithub {

    if context == .live {
      // Automatically handle any SQL access contention as long as it can be handled in `sqlContentionTimeout` seconds.
      configuration.busyMode = .timeout(sqlContentionTimeout)
      // Enable suspend notification processing.
      configuration.observesSuspensionNotifications = true
    }

    configuration.prepareDatabase { db in
      db.trace(options: .profile) {
        if context == .live {
          log.debug("\($0.expandedDescription)")
        } else {
          print("\($0.expandedDescription)")
        }
      }

      if context == .live && db.configuration.readonly == false {
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

  if context == .live {
    let databaseURL: URL = fileManager.databaseFileURL()
    let coordinator = NSFileCoordinator(filePresenter: nil)
    var dbPool: DatabasePool?
    var coordinatorError: NSError?
    var dbError: (any Error)?

    if false { // TODO: remove when no longer needed during development
      try? fileManager.removeItem(databaseURL)
      try? fileManager.removeItem(fileManager.fontFilesDirectory())
      _ = fileManager.fontFilesDirectory()
    }

    unsafe coordinator.coordinate(writingItemAt: databaseURL, options: .forMerging, error: &coordinatorError) { url in
      do {
        log.info("opening \(url)")
        dbPool = try DatabasePool(path: url.path(percentEncoded: false), configuration: configuration)
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

public func previewDatabase(
  fonts: [SF2ResourceTag] = [.fluidFont, .rolandNicePiano],
  loadAllPresets: Bool = false,
  seeder: ((Database) throws -> Void)? = nil
) -> any DatabaseWriter {
  // swiftlint:disable:next force_try
  try! appDatabase(fonts: fonts, loadAllPresets: loadAllPresets, seeder: seeder)
}

private func performMigrations(
  _ database: any DatabaseWriter,
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

  // NOTE: order is important here.
  SoundFont.migrate(&migrator)
  SoundFontText.migrate(&migrator)
  Preset.migrate(&migrator)
  PresetConfig.migrate(&migrator)
  PresetTag.migrate(&migrator)
  AudioConfig.migrate(&migrator)
  DelayConfig.migrate(&migrator)
  ReverbConfig.migrate(&migrator)
  Tag.migrate(&migrator)
  TaggedPreset.migrate(&migrator)
  TaggedSoundFont.migrate(&migrator)
  MIDIConfig.migrate(&migrator)

  migrator.registerMigration("Add ubiquitous tags") { db in
    let tags: [Tag] = Tag.Ubiquitous.allCases.enumerated().map {
      .init(id: Tag.ID(rawValue: $0.1.rawValue), displayName: $0.1.displayName ?? "???", ordering: $0.0, visible: true)
    }
    try Tag.insert {
      tags
    }.execute(db)
  }

  migrator.registerMigration("Add builtin fonts") { db in
    for sf2 in fonts {
      log.debug("adding \(String(describing: sf2), privacy: .public)")
      try SoundFont.addBuiltIn(db, sf2: sf2, limitedLoading: limitedLoading)
    }
  }

  try migrator.migrate(database)

  if let seeder {
    try database.write { db in
      try seeder(db)
    }
  }
}
