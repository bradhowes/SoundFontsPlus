import ComposableArchitecture
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct ChangesFeatureTests {}
}

extension BaseTestSuite.ChangesFeatureTests {

  func makeStore(data: String) -> TestStoreOf<ChangesFeature> {
    TestStoreOf<ChangesFeature>(initialState: .init(data)) {
      ChangesFeature()
    } withDependencies: {
      $0.mainQueue = .immediate
    }
  }

  @Test func shouldShow() throws {
    @Shared(.lastShowedChangesVersion) var lastShowedChangesVersion = ""
    #expect(ChangesFeature.shouldShow)
    #expect(!ChangesFeature.shouldShow)
    $lastShowedChangesVersion.withLock { $0 = "blah" }
    #expect(ChangesFeature.shouldShow)
    #expect(!ChangesFeature.shouldShow)
  }

  @Test func compile() throws {
    var changes: [ChangesFeature.Change] = ChangesFeature.compile("")
    #expect(changes.isEmpty)
    changes = ChangesFeature.compile("blah\nblah")
    #expect(changes.isEmpty)
    changes = ChangesFeature.compile("# 1.2.3  \nblah")
    #expect(changes == [])
    changes = ChangesFeature.compile("* item 1\n")
    #expect(changes.isEmpty)
    changes = ChangesFeature.compile("# version\n* item\n")
    #expect(
      changes == [
        .init(
          version: "version",
          items: ["item"]
        )
      ]
    )

    changes = ChangesFeature.compile("# version\n* item\n")
    #expect(
      changes == [
        .init(
          version: "version",
          items: ["item"]
        )
      ]
    )

    changes = ChangesFeature.compile("# 1.2.3  \n* item 1  \n* item 2\n")
    #expect(
      changes == [
        .init(
          version: "1.2.3",
          items: ["item 1", "item 2"]
        )
      ]
    )

    changes = ChangesFeature.compile("# 1.2.3  \n* item 1  \n* item 2\n continued.  ")
    #expect(
      changes == [
        .init(
          version: "1.2.3",
          items: ["item 1", "item 2 continued."]
        )
      ]
    )

    changes = ChangesFeature.compile("# 1.2.3  \n* item 1  \n* item 2\n continued.  \n\nskip me\n# 2\n* abc\n")
    #expect(
      changes == [
        .init(
          version: "1.2.3",
          items: ["item 1", "item 2 continued."]
        ),
        .init(
          version: "2",
          items: ["abc"]
        )
      ]
    )
  }

  @Test func creation() async throws {
    let store = makeStore(
      data:
        """
        # 1.2.3
        * foo
        * bar
        # 1.2.4
        * one
         two
        """
    )
    #expect(store.state.log == [
      .init(version: "1.2.3", items: ["foo", "bar"]),
      .init(version: "1.2.4", items: ["one two"])
    ])

    await store.send(.dismissButtonTapped)
  }

  @Test func changesFeaturePreview() async throws {
    prepareDependencies {
      let now = Date(timeIntervalSince1970: 0)
      $0.date.now = now
      @Shared(.nextReviewRequestDate) var nextReviewRequestDate = now
      @Shared(.lastReviewRequestVersion) var lastReviewRequestVersion = AppReviewFeature.currentVersion
    }

    let data = """
        # 1.2.3
        * foo
        * bar
        # 1.2.4
        * one
         two
        """
    let store = StoreOf<ChangesFeature>(initialState: .init(data)) {
      ChangesFeature()
    }
    let view = ChangesFeatureView(store: store)

    if BaseTestSuite.isLocal {
      withSnapshotTesting(record: .failed) {
        assertSnapshot(
          of: view,
          as: .image(
            layout: .fixed(width: 400, height: 800),
            traits: .init(userInterfaceStyle: .dark)
          )
        )
      }
    }
  }
}
