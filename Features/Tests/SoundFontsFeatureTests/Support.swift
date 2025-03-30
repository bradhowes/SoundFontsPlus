import ComposableArchitecture
import Foundation
import GRDB
import SF2ResourceFiles
import Models
import Testing

enum TestSupport {

  @MainActor
  static func initialize(_ body: (Array<SoundFont>) async throws -> Void) async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase()
    } operation: {
      @Dependency(\.defaultDatabase) var database
      let sfs = try await database.read { try SoundFont.fetchAll($0) }
      try await body(sfs)
    }
  }
}
