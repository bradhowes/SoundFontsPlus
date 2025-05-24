//import Testing
//
//import ComposableArchitecture
//import Dependencies
//import Tagged
//
//@MainActor
//struct PresetsListSectionTests {
//
//  func initialize(_ body: (TestStoreOf<PresetsListSection>) async throws -> Void) async throws {
//    try await TestSupport.initialize { soundFonts, presets in
//      try await body(TestStore(initialState: PresetsListSection.State(section: 20, presets: presets[20..<30])) {
//        PresetsListSection()
//      })
//    }
//  }
//
//  @Test func sectionSeesButtonTap() async throws {
//    try await initialize { store in
//      let preset = store.state.rows.first!.preset
//      await store.send(.rows(.element(id: preset.id, action: PresetButton.Action.buttonTapped)))
//      await store.receive(.rows(.element(id: preset.id, action: .delegate(.selectPreset(preset)))))
//    }
//  }
//}
