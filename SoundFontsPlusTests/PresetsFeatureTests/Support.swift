//import ComposableArchitecture
//import Foundation
//import Testing
//
//enum TestSupport {
//
//  static func fetchPreset(presetId: Preset.ID) async throws -> Preset {
//    @Dependency(\.defaultDatabase) var database
//    let preset = try await database.read { try Preset.fetchOne($0, id: presetId) }
//    guard let preset else {
//      Issue.record("Failed to fetch existing preset")
//      fatalError()
//    }
//    return preset
//  }
//
//  @MainActor
//  static func initialize(_ body: (Array<SoundFont>, Array<Preset>) async throws -> Void) async throws {
//    try await withDependencies {
//      $0.defaultDatabase = try .appDatabase()
//    } operation: {
//      @Dependency(\.defaultDatabase) var database
//      let soundFonts = try await database.read { try SoundFont.fetchAll($0) }
//      try await body(soundFonts, soundFonts[0].presets)
//    }
//  }
//}
