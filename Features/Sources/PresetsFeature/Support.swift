import ComposableArchitecture
import GRDB
import Models
import SF2ResourceFiles
import SwiftUI

enum Support {

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

    let presets = try! databaseQueue.read { try! Preset.fetchAll($0) }

    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activePresetId = presets[0].id
      $0.activeSoundFontId = presets[0].soundFontId
      $0.selectedSoundFontId = presets[0].soundFontId
    }

    return databaseQueue
  }
}
