// Copyright © 2025 Brad Howes. All rights reserved.

import Clocks
import Dependencies
import FeatureSupport

/**
 Feature that handles activity for SoundFont buttons shown in the list of fonts. Provides a visual indication of
 the availability of the font file when the file exist in an iCloud folder or on an external device.
 */
@Reducer
public struct TagButton {

  @ObservableState
  public struct State: Equatable, Identifiable {

    public var id: Tag.ID { tagInfo.id }
    public let tagInfo: TagInfo

    public init(
      tagInfo: TagInfo
    ) {
      self.tagInfo = tagInfo
    }
  }

  public enum Action {
    case delegate(Delegate)
  }

  @CasePathable
  public enum Delegate: Equatable {
    case activate(TagInfo)
    case delete(TagInfo)
    case edit(TagInfo)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { _, action in
      switch action {

      case .delegate:
        return .none

      }
    }
  }
}

extension TagButton {

}

// MARK: - View

struct TagButtonView: View {
  @State private var store: StoreOf<TagButton>
  @Shared(.activeState) private var activeState
  private var state: IndicatorModifier.State { activeState.activeTagId == store.id ? .active : .none }

  public init(store: StoreOf<TagButton>) {
    self.store = store
  }

  public var body: some View {
    Button {
      store.send(.delegate(.activate(store.tagInfo)))
    } label: {
      HStack {
        Text(store.tagInfo.displayName)
          .font(.button)
          .indicator(state)
        Spacer()
        Text("\(store.tagInfo.soundFontsCount)")
      }
      .contentShape(.interaction, Rectangle())
      .simultaneousGesture(
        LongPressGesture(minimumDuration: 1.0)
          .onEnded { _ in store.send(.delegate(.edit(store.tagInfo))) }
      )
    }
    .listRowSeparator(.hidden)
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button {
        store.send(.delegate(.edit(store.tagInfo)), animation: .default)
      } label: {
        Image(systemName: "pencil")
          .tint(.cyan)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if !store.tagInfo.isUbiquitous {
        Button {
          store.send(.delegate(.delete(store.tagInfo)), animation: .default)
        } label: {
          Image(systemName: "trash")
            .tint(.red)
        }
      }
    }
  }
}

private let log: Logger = .init(category: "TagButton")

#if DEBUG

extension TagButtonView {
  static var preview: some View {
    // swiftlint:disable:next force_try
    let tagInfos = try! prepareDependencies {
      $0.defaultDatabase = previewDatabase()
      return try $0.defaultDatabase.read { db in
        try TagInfo.queryAll.fetchAll(db)
      }
    }

    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activeTagId = tagInfos[0].id }

    return VStack {
      Section {
        List {
          TagButtonView(store: Store(initialState: .init(tagInfo: tagInfos[0])) { TagButton() })
          TagButtonView(store: Store(initialState: .init(tagInfo: tagInfos[1])) { TagButton() })
        }
        .listRowSeparator(.hidden)
        .listStyle(.plain)
      }
      List {
        TagButtonView(store: Store(initialState: .init(tagInfo: tagInfos[0])) { TagButton() })
        TagButtonView(store: Store(initialState: .init(tagInfo: tagInfos[1])) { TagButton() })
      }
#if os(iOS)
      .listStyle(.grouped)
#endif
    }
  }
}

#Preview {
  TagButtonView.preview
}

#endif
