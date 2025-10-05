import ComposableArchitecture
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import ChangesFeature

extension BaseTestSuite {

  @MainActor
  struct ChangesFeatureTests {}
}

extension BaseTestSuite.ChangesFeatureTests {

  func makeStore(data: String) -> TestStoreOf<Changes> {
    TestStoreOf<Changes>(initialState: .init(data)) {
      Changes()
    } withDependencies: {
      $0.mainQueue = .immediate
    }
  }

  @Test func shouldShow() throws {
    @Shared(.lastShowedChangesVersion) var lastShowedChangesVersion = ""
    #expect(Changes.shouldShow)
    #expect(!Changes.shouldShow)
    $lastShowedChangesVersion.withLock { $0 = "blah" }
    #expect(Changes.shouldShow)
    #expect(!Changes.shouldShow)
  }

  @Test func compile() throws {
    var changes: [Changes.Change] = Changes.compile("")
    #expect(changes.isEmpty)
    changes = Changes.compile("blah\nblah")
    #expect(changes.isEmpty)
    changes = Changes.compile("# 1.2.3  \nblah")
    #expect(changes == [])
    changes = Changes.compile("* item 1\n")
    #expect(changes.isEmpty)
    changes = Changes.compile("# version\n* item\n")
    #expect(
      changes == [
        .init(
          version: "version",
          items: ["item"]
        )
      ]
    )

    changes = Changes.compile("# version\n* item\n")
    #expect(
      changes == [
        .init(
          version: "version",
          items: ["item"]
        )
      ]
    )

    changes = Changes.compile("# 1.2.3  \n* item 1  \n* item 2\n")
    #expect(
      changes == [
        .init(
          version: "1.2.3",
          items: ["item 1", "item 2"]
        )
      ]
    )

    changes = Changes.compile("# 1.2.3  \n* item 1  \n* item 2\n continued.  ")
    #expect(
      changes == [
        .init(
          version: "1.2.3",
          items: ["item 1", "item 2 continued."]
        )
      ]
    )

    changes = Changes.compile("# 1.2.3  \n* item 1  \n* item 2\n continued.  \n\nskip me\n# 2\n* abc\n")
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

  @Test func changesPreview() async throws {
    let data = """
        # 1.2.3
        * foo
        * bar
        # 1.2.4
        * one
         two
        """
    let store = StoreOf<Changes>(initialState: .init(data)) {
      Changes()
    }
    let view = ChangesView(store: store)

    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: view,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }
}
