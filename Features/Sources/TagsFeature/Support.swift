import ComposableArchitecture
import GRDB
import Models
import SF2ResourceFiles
import SwiftUI

enum Support {

  @CasePathable
  public enum ConfirmationDialog: Equatable, Sendable {
    case confirmedDeletion(key: Tag.ID)
  }

  static func addTag(existing: [Tag]) -> IdentifiedArrayOf<Tag> {
    let tagNames = Set<String>(existing.map { $0.name })
    var newName = "New Tag"
    for index in 1..<1000 {
      if !tagNames.contains(newName) { break }
      newName = "New Tag \(index)"
    }

    @Dependency(\.defaultDatabase) var database
    let _ = try? database.write { db in _ = try Tag.make(db, name: newName) }

    return Tag.ordered
  }

  static var previewDatabase: DatabaseQueue {
    let databaseQueue = try! DatabaseQueue()
    try! databaseQueue.migrate()
    let tags = try! databaseQueue.read { try! Tag.fetchAll($0) }
    print(tags.count)

    try! databaseQueue.write { db in
      for font in SF2ResourceFileTag.allCases {
        _ = try? SoundFont.make(db, builtin: font)
      }
    }

    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activeTagId = tags[0].id
    }

    return databaseQueue
  }
}
