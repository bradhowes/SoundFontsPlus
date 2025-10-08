// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import FeatureSupport
import Sharing
import SwiftUI

@Reducer
public struct Changes {

  public struct Change: Hashable {
    public let version: String
    public let items: [String]

    public init(version: String, items: [String]) {
      self.version = version
      self.items = items
    }
  }

  @ObservableState
  public struct State: Equatable {
    let log: [Change]

    public init(_ data: String) {
      self.log = Changes.compile(data)
    }
  }

  public enum Action {
    case dismissButtonTapped
  }

  public init() {}

  public var body: some ReducerOf<Self> {

    Reduce { _, action in
      switch action {

      case .dismissButtonTapped:
        @Dependency(\.dismiss) var dismiss
        return .run { _ in await dismiss() }

      }
    }
  }

  public static var shouldShow: Bool {
#if ALWAYS_SHOW_TUTORIAL
    return true
#else
    @Shared(.lastShowedChangesVersion) var lastShowedChangesVersion
    defer { $lastShowedChangesVersion.withLock { $0 = Bundle.main.releaseVersionNumber } }
    return lastShowedChangesVersion != Bundle.main.releaseVersionNumber
#endif
  }

  public static func compile(_ data: String) -> [Change] {
    var entries = [Change]()
    var version = ""
    var items = [String]()

    for line in data.components(separatedBy: .newlines) {
      if line.hasPrefix("# ") {
        if !version.isEmpty && !items.isEmpty {
          entries.append(.init(version: version, items: items))
        }
        version = String(line[line.index(line.startIndex, offsetBy: 2)...]).trimmedOfWhitespaces
        items = []
      } else if line.hasPrefix("* ") {
        let item = String(line[line.index(line.startIndex, offsetBy: 2)...]).trimmedOfWhitespaces
        items.append(item)
      } else if line.hasPrefix(" ") && !items.isEmpty {
        items[items.count - 1] = (items.last ?? "") + " " + line.trimmedOfWhitespaces
      }
    }

    if !version.isEmpty && !items.isEmpty {
      entries.append(.init(version: version, items: items))
    }

    return entries
  }
}

public struct ChangesView: View {
  @State private var store: StoreOf<Changes>

  public init(store: StoreOf<Changes>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      Text("Changes")
        .font(.navigationTitle)
        .foregroundStyle(.orange)
      Grid(alignment: .leading, verticalSpacing: 8) {
        ForEach(store.log, id: \.self) { change in
          Text(change.version)
            .font(.version)
            .foregroundStyle(.orange)
            .gridColumnAlignment(.leading)
            .padding([.top], 18)
          ForEach(change.items, id: \.self) { item in
            GridRow {
              Text("•")
                .font(.change)
                .foregroundStyle(.orange)
              Text(item)
                .gridColumnAlignment(.leading)
                .font(.change)
                .foregroundStyle(.teal)
            }
          }
        }
      }
      .padding([.leading, .trailing], 24)
    }
    .padding([.bottom], 24)
    .navigationTitle("")
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button("Done") { store.send(.dismissButtonTapped, animation: .default) }
          .font(.button)
      }
    }
  }
}

extension ChangesView {

  static var preview: some View {
    prepareDependencies { _ in
      // swiftlint:disable:next force_try
      // $0.defaultDatabase = try! appDatabase()
      // $0.delayDevice = .init(setConfig: { print("delayDevice.set: ", $0) })
      // $0.reverbDevice = .init(setConfig: { print("reverbDevice.set: ", $0) })
    }

    let data = """
      # 1.0.0
      * First item
      * Second
        item
      * Third
        long
        item
      * Fourth item that just goes on, and on
      # 1.1.0
      * Fixed first item
      * Removed second item
      """

    return  VStack(spacing: 0) {
      Text("Hello")
        .sheet(
          isPresented: Binding(get: { true }, set: { _ in }),
          onDismiss: nil
        ) {
          NavigationStack {
            ChangesView(store: .init(initialState: .init(data)) { Changes() })
          }
        }
    }
    .preferredColorScheme(.dark)
    .environment(\.colorScheme, .dark)
  }
}

#Preview {
  ChangesView.preview
}
