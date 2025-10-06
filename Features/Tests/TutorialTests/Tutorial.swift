import ComposableArchitecture
import FeatureSupport
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import Tutorial

@MainActor
struct TutorialTests {

  func makeStore(page: Tutorial.Page) -> TestStoreOf<Tutorial> {
    TestStoreOf<Tutorial>(initialState: .init(page: page)) {
      Tutorial()
    } withDependencies: {
      $0.mainQueue = .immediate
    }
  }

  @Test func shouldShow() throws {
    @Shared(.showedTutorial) var showedTutorial = false
    #expect(Tutorial.shouldShow)
    #expect(Tutorial.shouldShow)
    $showedTutorial.withLock { $0 = true }
    #expect(!Tutorial.shouldShow)
    #expect(!Tutorial.shouldShow)
  }

  @Test func dismissButtonTappeed() async throws {
    let store = makeStore(page: .intro)
    await store.send(.dismissButtonTapped)
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
    let store = StoreOf<Tutorial>(initialState: .init(page: .intro)) {
      Tutorial()
    }

    let view = TutorialView(store: store)

    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: view,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }

  @Test func fontsPage() async throws {
    let store = StoreOf<Tutorial>(initialState: .init(page: .fonts)) {
      Tutorial()
    }

    let view = TutorialView(store: store)

    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: view,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }

  @Test func presetsPage() async throws {
    let store = StoreOf<Tutorial>(initialState: .init(page: .presets)) {
      Tutorial()
    }

    let view = TutorialView(store: store)

    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: view,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }

  @Test func favoritesPage() async throws {
    let store = StoreOf<Tutorial>(initialState: .init(page: .favorites)) {
      Tutorial()
    }

    let view = TutorialView(store: store)

    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: view,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }

  @Test func tagsPage() async throws {
    let store = StoreOf<Tutorial>(initialState: .init(page: .tags)) {
      Tutorial()
    }

    let view = TutorialView(store: store)

    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: view,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }

  @Test func toolBar1Page() async throws {
    let store = StoreOf<Tutorial>(initialState: .init(page: .toolBar1)) {
      Tutorial()
    }

    let view = TutorialView(store: store)

    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: view,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }

  @Test func toolBar2Page() async throws {
    let store = StoreOf<Tutorial>(initialState: .init(page: .toolBar2)) {
      Tutorial()
    }

    let view = TutorialView(store: store)

    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: view,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }

  @Test func reverbPage() async throws {
    let store = StoreOf<Tutorial>(initialState: .init(page: .reverb)) {
      Tutorial()
    }

    let view = TutorialView(store: store)

    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: view,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }

  @Test func delayPage() async throws {
    let store = StoreOf<Tutorial>(initialState: .init(page: .delay)) {
      Tutorial()
    }

    let view = TutorialView(store: store)

    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: view,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }

  @Test func settingsPage() async throws {
    let store = StoreOf<Tutorial>(initialState: .init(page: .settings)) {
      Tutorial()
    }

    let view = TutorialView(store: store)

    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: view,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }

  @Test func lastPage() async throws {
    let store = StoreOf<Tutorial>(initialState: .init(page: .last)) {
      Tutorial()
    }

    let view = TutorialView(store: store)

    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: view,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }
}
