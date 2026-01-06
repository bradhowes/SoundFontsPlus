// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import SoundFonts

@Suite(
  .snapshots(record: .failed)
)
@MainActor
struct SoundFontButtonTests {
  @Shared(.activeState) var activeState = .default

  fileprivate func store(kind: SoundFont.Kind) -> TestStoreOf<SoundFontButton> {
    let soundFontInfo = SoundFontInfo(id: 123, displayName: "Testing", kind: kind, location: Data())
    return TestStoreOf<SoundFontButton>(initialState: .init(soundFontInfo: soundFontInfo)) {
      SoundFontButton()
    }
  }

  @Test
  func preview() async throws {
    try TestSupport.assertSnapshot(matching: SoundFontButtonView.preview)
  }
}
