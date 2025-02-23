import Foundation
import GRDB
import SF2ResourceFiles
import Models

internal func setupDatabase(all: Bool = false) async throws -> DatabaseQueue {
  let db = try DatabaseQueue.appDatabase()
  let tags = all ? SF2ResourceFileTag.allCases : [SF2ResourceFileTag.freeFont]
  try await db.write {
    for tag in tags {
      _  = try SoundFont.make($0, builtin: tag)
    }
  }
  return db
}
