import ComposableArchitecture
import Foundation
import Testing

@testable import SoundFontsPlus

enum TestSupport {

  static func fetchPreset(presetId: Preset.ID) async throws -> Preset {
    guard let preset = Preset.with(id: presetId) else {
      Issue.record("Failed to fetch existing preset")
      fatalError()
    }
    return preset
  }
}
