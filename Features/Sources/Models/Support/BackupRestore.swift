// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Dependencies
import Foundation
import GRDB
import Sharing

// Based off of code in https://github.com/groue/GRDB.swift/discussions/1798#discussioncomment-13926896
public enum BackupManager {

  public static func reinitialize() {
    withDatabaseWriter { db in

      log.info("deleting installed soundfont files")
      try SoundFont
        .where { $0.kind.neq(SoundFont.Kind.builtin) }
        .delete()
        .execute(db)

      log.info("deleting custom tags")
      try Tag
        .where { $0.id.gte(Tag.ID(0)) }
        .delete()
        .execute(db)

      log.info("deleting favorites")
      try Preset
        .where { $0.kind.eq(Preset.Kind.favorite) }
        .delete()
        .execute(db)

      log.info("unhiding presets")
      try Preset
        .where { $0.kind.eq(Preset.Kind.hidden) }
        .update { $0.kind = .preset }
        .execute(db)

      log.info("removing custom audio configurations")
      try AudioConfig
        .delete()
        .execute(db)

      log.info("removing delay configurations")
      try DelayConfig
        .delete()
        .execute(db)

      log.info("removing reverb configurations")
      try ReverbConfig
        .delete()
        .execute(db)
    }

    @Dependency(\.fileManager) var fileManager

    do {
      try fileManager.removeItem(fileManager.fontFilesDirectory())
    } catch {
      log.error("removeItem on 'FontFiles' failed - \(error.localizedDescription, privacy: .public)")
    }

    do {
      try fileManager.createDirectory(fileManager.fontFilesDirectory())
    } catch {
      log.error("createDirectory on 'FontFiles' failed - \(error.localizedDescription, privacy: .public)")
    }

    // @Shared(.activeState) var activeState
    // $activeState.withLock { $0 = .default }

    @Shared(.selectedSoundFontId) var selectedSoundFontId
    $selectedSoundFontId.withLock { $0 = nil }
  }

  // swiftlint:disable:next function_body_length
  public static func backup() throws(BackupError) -> URL {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.fileManager) var fileManager
    @Dependency(\.date.now) var now
    @Dependency(\.uuid) var uuid

    guard let cloudDocuments = fileManager.cloudDocumentsDirectory() else {
      log.info("no cloud documents directory available")
      throw BackupError.noCloudDirectory
    }

    let backupName = "Backup - " + now.ISO8601Format(.init().timeSeparator(.omitted))
    log.debug("backupName: \(backupName, privacy: .public)")

    let tmpDirectory = URL.temporaryDirectory.appending(component: uuid().uuidString, directoryHint: .isDirectory)
    let backupDirectory = tmpDirectory.appending(component: backupName, directoryHint: .isDirectory)
    log.debug("backupDirectory: \(backupDirectory, privacy: .public)")

    defer {
      try? fileManager.removeItem(backupDirectory)
    }

    do {
      try fileManager.createDirectory(backupDirectory)
    } catch {
      log.error("failed createDirectory: \(error.localizedDescription, privacy: .public)")
      throw BackupError.backupCreationFailed(error)
    }

    let version: String = Bundle.main.releaseVersionNumber
    let backupFile: URL = backupDirectory.appending(path: "backup.sqlite-\(version)", directoryHint: .notDirectory)
    log.debug("backupFile: \(backupFile, privacy: .public)")

    do {
      let backupDatabase: DatabaseQueue = try DatabaseQueue(path: backupFile.path(percentEncoded: false))
      log.info("backing up databse to \(backupFile.path(percentEncoded: false), privacy: .public)")
      try database.backup(to: backupDatabase)

      // Finish backup
      try backupDatabase.writeWithoutTransaction { db in
        _ = try db.execute(sql: "PRAGMA journal_mode=DELETE")
        _ = try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        let integrityResult = try String.fetchOne(db, sql: "PRAGMA integrity_check")
        guard integrityResult == "ok" else {
          log.error("failed database integrity check - nil result")
          throw BackupError.databaseIntegrityCheckFailed
        }

        let check = try Row.fetchAll(db, sql: "PRAGMA foreign_key_check")
        guard check.isEmpty else {
          log.error("failed database foreign key check - \(check)")
          throw BackupError.databaseForeignKeyCheckFailed
        }
      }

      log.info("backup vacuuming")
      try backupDatabase.vacuum()
      log.info("backup closing")
      try backupDatabase.close()

    } catch let error as BackupError {
      log.error("encountered error while creating backup - \(error.description, privacy: .public)")
      throw error
    } catch {
      log.error("encountered error while creating backup - \(error.localizedDescription, privacy: .public)")
      throw BackupError.backupCreationFailed(error)
    }

    // Now move the temporary directory into the app iCloud documents directory.
    let finalDestination = cloudDocuments.appending(component: backupName, directoryHint: .isDirectory)

    do {
      log.info("moving backup directory into iCloud - start")
      try fileManager.moveItem(backupDirectory, finalDestination)
      log.info("moving backup directory into iCloud - done")
    } catch {
      log.error("failed to move backup directory into iCloud - \(error.localizedDescription, privacy: .public)")
      throw BackupError.moveItemFailed(error)
    }

    // Copy the SF2 files to the iCloud directory.
    do {
      log.info("copying font files into iCloud - start")
      try fileManager.copyItem(
        fileManager.fontFilesDirectory(),
        finalDestination.appending(component: FileManager.fontFilesDirectoryName, directoryHint: .isDirectory)
      )
      log.info("copying font files into iCloud - done")
    } catch {
      log.error("failed to copy font files into iCloud - \(error.localizedDescription, privacy: .public)")
      throw BackupError.fontFilesCopyFailed(error)
    }

    log.info("backup completed - \(finalDestination.path(percentEncoded: false), privacy: .public)")
    return finalDestination
  }

  // swiftlint:disable:next function_body_length
  public static func restore(backupDirectory: URL) async throws {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.fileManager) var fileManager

    log.info("restoring from \(backupDirectory.path(percentEncoded: false), privacy: .public)")

    guard backupDirectory.hasDirectoryPath else {
      log.error("given URL is not a directory")
      throw RestoreError.notBackupDirectory
    }

    let contents: [URL]
    do {
      contents = try fileManager.contentsOfDirectory(backupDirectory)
      log.debug("contents of URL: \(contents)")
    } catch {
      log.error("failed to read contents of backup directory - \(error.localizedDescription, privacy: .public)")
      throw RestoreError.cannotReadDirectory(error)
    }

    // There should be a "FontFiles" directory in the backup directory.
    var found = contents.filter { $0.lastPathComponent == FileManager.fontFilesDirectoryName }
    if found.isEmpty {
      log.error("missing FontFiles folder in backup directory")
      throw RestoreError.missingFontFiles
    }

    let fontFilesDirectory = found[0]

    // There should be a "backup.sqlite-\(version)" file in the directory and the version should be compatible with
    // ours.
    found = contents.filter { $0.lastPathComponent.hasPrefix("backup.sqlite-") }
    if found.isEmpty {
      log.error("missing database backup file in backup directory")
      throw RestoreError.missingBackupFile
    } else if found.count > 1 {
      log.error("multiple database backup files in backup directory - \(found)")
      throw RestoreError.multipleBackupFiles
    }

    let backupFile = found[0]
    guard let versionText = backupFile.lastPathComponent.split(separator: "-").last,
          let version = Version.parse(.init(versionText))
    else {
      log.error("invalid version tag on database backup file name - \(backupFile.lastPathComponent, privacy: .public)")
      throw RestoreError.invalidVersionTag
    }

    log.info("backup version: \(version)")

    guard let appVersion = Version.parse(Bundle.main.releaseVersionNumber),
          version <= appVersion
    else {
      log.error("appVersion nil or older than backup - \(Bundle.main.releaseVersionNumber, privacy: .public)")
      throw RestoreError.unsupportedVersion
    }

    log.info("verifying backup integrity")
    try verifyDatabaseIntegrity(at: backupFile)

    log.info("closing current database connection")
    do {
      try await database.writeWithoutTransaction { db in
        _ = try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
      }

      try database.close()

    } catch {
      log.error("failed to properly close current database connection - \(error.localizedDescription, privacy: .public)")
      throw error
    }

    let databaseFile = fileManager.databaseFileURL()

    log.info("removing any artifacts from current database file")
    for suffix in ["wal", "shm"] {
      try? fileManager.removeItem(databaseFile.appending(path: "-\(suffix)"))
    }

    // Restore from backup
    log.info("restoring database file from backup")
    try? fileManager.removeItem(databaseFile)
    try fileManager.copyItem(backupFile, databaseFile)

    log.info("restoring FontFiles directory from backup")
    try? fileManager.removeItem(fileManager.fontFilesDirectory())
    try? fileManager.copyItem(
      fontFilesDirectory,
      fileManager.fontFilesDirectory()
    )

    log.info("restore complete")
  }
}

extension BackupManager {

  private static func verifyDatabaseIntegrity(at url: URL) throws {
    let testDatabase = try DatabaseQueue(path: url.path)
    defer { try? testDatabase.close() }

    try testDatabase.read { db in
      let integrityCheck = try String.fetchOne(db, sql: "PRAGMA integrity_check")
      if integrityCheck != "ok" {
        throw RestoreError.databaseIntegrityCheckFailed
      }
    }
  }
}

public enum BackupError: Error {
  case noCloudDirectory
  case backupCreationFailed(Error)
  case databaseBackupFailed(Error)
  case databaseIntegrityCheckFailed
  case databaseForeignKeyCheckFailed
  case fontFilesCopyFailed(Error)
  case moveItemFailed(Error)

  public var description: String {
    switch self {

    case .noCloudDirectory:
      return "There is no iCloud directory available to use."
    case .backupCreationFailed(let error):
      return "Failed to create a backup directory - \(error.localizedDescription)"
    case .databaseBackupFailed(let error):
      return "Failed database backup - \(error.localizedDescription)"
    case .databaseIntegrityCheckFailed:
      return "Verification of database backup integrity failed."
    case .databaseForeignKeyCheckFailed:
      return "Verificaion of database foreign keys failed."
    case .fontFilesCopyFailed(let error):
      return "Failed to copy contents of the installed sound font files - \(error.localizedDescription)"
    case .moveItemFailed(let error):
      return "Failed to move backup folder to cloud documents directory - \(error.localizedDescription)"
    }
  }
}

public enum RestoreError: Error {
  case notBackupDirectory
  case cannotReadDirectory(Error)
  case missingFontFiles
  case missingBackupFile
  case multipleBackupFiles
  case invalidVersionTag
  case unsupportedVersion
  case databaseBackupFailed(Error)
  case databaseIntegrityCheckFailed
  case databaseForeignKeyCheckFailed
  case fontFilesCopyFailed(Error)
  case moveItemFailed(Error)

  public var description: String {
    switch self {

    case .notBackupDirectory:
      return "The folder is not from a backup."
    case .cannotReadDirectory(let error):
      return "Failed to read backup directory - \(error.localizedDescription)"
    case .databaseBackupFailed(let error):
      return "Failed database backup - \(error.localizedDescription)"
    case .databaseIntegrityCheckFailed:
      return "Verification of database backup integrity failed."
    case .databaseForeignKeyCheckFailed:
      return "Verificaion of database foreign keys failed."
    case .fontFilesCopyFailed(let error):
      return "Failed to copy contents of the installed sound font files - \(error.localizedDescription)"
    case .moveItemFailed(let error):
      return "Failed to move backup folder to cloud documents directory - \(error.localizedDescription)"
    case .missingBackupFile:
      return "Database backup file is missing in backup directory."
    case .multipleBackupFiles:
      return "More than one backup file candidate found in backup directory."
    case .invalidVersionTag:
      return "Invalid or missing version tag in backup file name."
    case .unsupportedVersion:
      return "Cannot restore from backup because it was created by a newer version of the app."
    case .missingFontFiles:
      return "Missing FontFiles directory in backup."
    }
  }
}

private let log = Logger(category: "BackupManager")
