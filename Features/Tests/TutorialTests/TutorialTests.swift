// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import Tutorial

@Suite(
  .snapshots(record: .failed)
)
@MainActor
struct TutorialTests {

  func makeStore(page: Tutorial.Page) -> TestStoreOf<Tutorial> {
    TestStoreOf<Tutorial>(initialState: .init(page: page)) {
      Tutorial()
    } withDependencies: {
      $0.mainQueue = .immediate
    }
  }

  @Test
  func shouldShow() throws {
    @Shared(.showedTutorial) var showedTutorial = false
    #expect(Tutorial.shouldShow)
    #expect(Tutorial.shouldShow)
    $showedTutorial.withLock { $0 = true }
    #expect(!Tutorial.shouldShow)
    #expect(!Tutorial.shouldShow)
  }

  @Test
  func dismissButtonTappeed() async throws {
    let store = makeStore(page: .intro)
    await store.send(.dismissButtonTapped)
  }

  @Test
  func intoChangePage() async throws {
    let store = makeStore(page: .intro)
    await store.send(.prev)
    await store.send(.next) { $0.page = .fonts }
  }

  @Test
  func fontsChangePage() async throws {
    let store = makeStore(page: .fonts)
    await store.send(.prev) { $0.page = .intro }
    await store.send(.next) { $0.page = .fonts }
    await store.send(.next) { $0.page = .presets }
  }

  @Test
  func presetsChangePage() async throws {
    let store = makeStore(page: .presets)
    await store.send(.prev) { $0.page = .fonts }
    await store.send(.next) { $0.page = .presets }
    await store.send(.next) { $0.page = .favorites }
  }

  @Test
  func favoritesChangePage() async throws {
    let store = makeStore(page: .favorites)
    await store.send(.prev) { $0.page = .presets }
    await store.send(.next) { $0.page = .favorites }
    await store.send(.next) { $0.page = .tags }
  }

  @Test
  func tagsChangePage() async throws {
    let store = makeStore(page: .tags)
    await store.send(.prev) { $0.page = .favorites }
    await store.send(.next) { $0.page = .tags }
    await store.send(.next) { $0.page = .toolBar1 }
  }

  @Test
  func toolBar1ChangePage() async throws {
    let store = makeStore(page: .toolBar1)
    await store.send(.prev) { $0.page = .tags }
    await store.send(.next) { $0.page = .toolBar1 }
    await store.send(.next) { $0.page = .toolBar2 }
  }

  @Test
  func toolBar2ChangePage() async throws {
    let store = makeStore(page: .toolBar2)
    await store.send(.prev) { $0.page = .toolBar1 }
    await store.send(.next) { $0.page = .toolBar2 }
    await store.send(.next) { $0.page = .reverb }
  }

  @Test
  func reverbChangePage() async throws {
    let store = makeStore(page: .reverb)
    await store.send(.prev) { $0.page = .toolBar2 }
    await store.send(.next) { $0.page = .reverb }
    await store.send(.next) { $0.page = .delay }
  }

  @Test
  func delayChangePage() async throws {
    let store = makeStore(page: .delay)
    await store.send(.prev) { $0.page = .reverb }
    await store.send(.next) { $0.page = .delay }
    await store.send(.next) { $0.page = .settings }
  }

  @Test
  func settingsChangePage() async throws {
    let store = makeStore(page: .settings)
    await store.send(.prev) { $0.page = .delay }
    await store.send(.next) { $0.page = .settings }
    await store.send(.next) { $0.page = .last }
  }

  @Test
  func lastChangePage() async throws {
    let store = makeStore(page: .last)
    await store.send(.prev) { $0.page = .settings }
    await store.send(.next) { $0.page = .last }
    await store.send(.next)
  }

  func snapshotPage(
    _ page: Tutorial.Page,
    fileID: StaticString = #fileID,
    file: StaticString = #filePath,
    testName: StaticString = #function,
    line: Int = #line,
    col: Int = #column
  ) throws {
    let store = StoreOf<Tutorial>(initialState: .init(page: page)) { Tutorial() }
    TestSupport.assertSnapshot(
      matching: TutorialView(store: store),
      fileID: fileID,
      file: file,
      testName: testName,
      line: line,
      col: col
    )
  }

  @Test
  func introPage() throws { try snapshotPage(.intro) }
  @Test
  func fontsPage() throws { try snapshotPage(.fonts) }
  @Test
  func presetsPage() throws { try snapshotPage(.presets) }
  @Test
  func favoritesPage() throws { try snapshotPage(.favorites) }
  @Test
  func tagsPage() throws { try snapshotPage(.tags) }
  @Test
  func toolBar1Page() throws { try snapshotPage(.toolBar1) }
  @Test
  func toolBar2Page() throws { try snapshotPage(.toolBar2) }
  @Test
  func reverbPage() throws { try snapshotPage(.reverb) }
  @Test
  func delayPage() throws { try snapshotPage(.delay) }
  @Test
  func settingsPage() throws { try snapshotPage(.settings) }
  @Test
  func lastPage() throws { try snapshotPage(.last) }
}
