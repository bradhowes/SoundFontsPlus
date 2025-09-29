import ComposableArchitecture
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct TutorialFeatureTests {}
}

extension BaseTestSuite.TutorialFeatureTests {

  func makeStore(page: TutorialFeature.Page) -> TestStoreOf<TutorialFeature> {
    TestStoreOf<TutorialFeature>(initialState: .init(page: page)) {
      TutorialFeature()
    } withDependencies: {
      $0.mainQueue = .immediate
    }
  }

  @Test func shouldShow() throws {
    @Shared(.showedTutorial) var showedTutorial = false
    #expect(TutorialFeature.shouldShow)
    #expect(TutorialFeature.shouldShow)
    $showedTutorial.withLock { $0 = true }
    #expect(!TutorialFeature.shouldShow)
    #expect(!TutorialFeature.shouldShow)
  }

  @Test func intoChangePage() async throws {
    let store = makeStore(page: .intro)
    await store.send(.prev)
    await store.send(.next) { $0.page = .fonts }
  }

  @Test func fontsChangePage() async throws {
    let store = makeStore(page: .fonts)
    await store.send(.prev) { $0.page = .intro }
    await store.send(.next) { $0.page = .fonts }
    await store.send(.next) { $0.page = .presets }
  }

  @Test func presetsChangePage() async throws {
    let store = makeStore(page: .presets)
    await store.send(.prev) { $0.page = .fonts }
    await store.send(.next) { $0.page = .presets }
    await store.send(.next) { $0.page = .favorites }
  }

  @Test func favoritesChangePage() async throws {
    let store = makeStore(page: .favorites)
    await store.send(.prev) { $0.page = .presets }
    await store.send(.next) { $0.page = .favorites }
    await store.send(.next) { $0.page = .tags }
  }

  @Test func tagsChangePage() async throws {
    let store = makeStore(page: .tags)
    await store.send(.prev) { $0.page = .favorites }
    await store.send(.next) { $0.page = .tags }
    await store.send(.next) { $0.page = .toolBar1 }
  }

  @Test func toolBar1ChangePage() async throws {
    let store = makeStore(page: .toolBar1)
    await store.send(.prev) { $0.page = .tags }
    await store.send(.next) { $0.page = .toolBar1 }
    await store.send(.next) { $0.page = .toolBar2 }
  }

  @Test func toolBar2ChangePage() async throws {
    let store = makeStore(page: .toolBar2)
    await store.send(.prev) { $0.page = .toolBar1 }
    await store.send(.next) { $0.page = .toolBar2 }
    await store.send(.next) { $0.page = .reverb }
  }

  @Test func reverbChangePage() async throws {
    let store = makeStore(page: .reverb)
    await store.send(.prev) { $0.page = .toolBar2 }
    await store.send(.next) { $0.page = .reverb }
    await store.send(.next) { $0.page = .delay }
  }

  @Test func delayChangePage() async throws {
    let store = makeStore(page: .delay)
    await store.send(.prev) { $0.page = .reverb }
    await store.send(.next) { $0.page = .delay }
    await store.send(.next) { $0.page = .settings }
  }

  @Test func settingsChangePage() async throws {
    let store = makeStore(page: .settings)
    await store.send(.prev) { $0.page = .delay }
    await store.send(.next) { $0.page = .settings }
    await store.send(.next) { $0.page = .last }
  }

  @Test func lastChangePage() async throws {
    let store = makeStore(page: .last)
    await store.send(.prev) { $0.page = .settings }
    await store.send(.next) { $0.page = .last }
    await store.send(.next)
  }

  @Test func introPage() async throws {
    let store = StoreOf<TutorialFeature>(initialState: .init(page: .intro)) {
      TutorialFeature()
    }

    let view = TutorialFeatureView(store: store)

    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }

  @Test func fontsPage() async throws {
    let store = StoreOf<TutorialFeature>(initialState: .init(page: .fonts)) {
      TutorialFeature()
    }

    let view = TutorialFeatureView(store: store)

    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }

  @Test func presetsPage() async throws {
    let store = StoreOf<TutorialFeature>(initialState: .init(page: .presets)) {
      TutorialFeature()
    }

    let view = TutorialFeatureView(store: store)

    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }

  @Test func favoritesPage() async throws {
    let store = StoreOf<TutorialFeature>(initialState: .init(page: .favorites)) {
      TutorialFeature()
    }

    let view = TutorialFeatureView(store: store)

    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }

  @Test func tagsPage() async throws {
    let store = StoreOf<TutorialFeature>(initialState: .init(page: .tags)) {
      TutorialFeature()
    }

    let view = TutorialFeatureView(store: store)

    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }

  @Test func toolBar1Page() async throws {
    let store = StoreOf<TutorialFeature>(initialState: .init(page: .toolBar1)) {
      TutorialFeature()
    }

    let view = TutorialFeatureView(store: store)

    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }

  @Test func toolBar2Page() async throws {
    let store = StoreOf<TutorialFeature>(initialState: .init(page: .toolBar2)) {
      TutorialFeature()
    }

    let view = TutorialFeatureView(store: store)

    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }

  @Test func reverbPage() async throws {
    let store = StoreOf<TutorialFeature>(initialState: .init(page: .reverb)) {
      TutorialFeature()
    }

    let view = TutorialFeatureView(store: store)

    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }

  @Test func delayPage() async throws {
    let store = StoreOf<TutorialFeature>(initialState: .init(page: .delay)) {
      TutorialFeature()
    }

    let view = TutorialFeatureView(store: store)

    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }

  @Test func settingsPage() async throws {
    let store = StoreOf<TutorialFeature>(initialState: .init(page: .settings)) {
      TutorialFeature()
    }

    let view = TutorialFeatureView(store: store)

    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }

  @Test func lastPage() async throws {
    let store = StoreOf<TutorialFeature>(initialState: .init(page: .last)) {
      TutorialFeature()
    }

    let view = TutorialFeatureView(store: store)

    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }
}
