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
  private var store: StoreOf<TagButton>
  private var count: String { store.tagInfo.soundFontsCount > 0 ? "\(store.tagInfo.soundFontsCount)" : "" }
  private let indicatorModifierState: IndicatorModifier.State

  public init(store: StoreOf<TagButton>, indicatorModifierState: IndicatorModifier.State) {
    self.store = store
    self.indicatorModifierState = indicatorModifierState
  }

  public var body: some View {
    Button {
      store.send(.delegate(.activate(store.tagInfo)))
    } label: {
      HStack {
        Text(store.tagInfo.displayName)
          .font(.button)
          .opacity(count.isEmpty ? 0.75 : 1.0)
          .indicator(indicatorModifierState)
        Spacer()
        Text(count)
          .font(.button)
          .indicator(indicatorModifierState == .active ? .activeNoIndicator : .none)
      }
      .contentShape(.interaction, Rectangle())
      .simultaneousGesture(
        LongPressGesture(minimumDuration: 1.0)
          .onEnded { _ in store.send(.delegate(.edit(store.tagInfo))) }
      )
    }
    .disabled(count.isEmpty)
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button {
        store.send(.delegate(.edit(store.tagInfo)), animation: .default)
      } label: {
        Image(systemName: .editButtonImageName)
          .tint(.cyan)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if !store.tagInfo.isUbiquitous {
        Button {
          store.send(.delegate(.delete(store.tagInfo)), animation: .default)
        } label: {
          Image(systemName: .deleteButtonImageName)
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
    let tagInfos = withDatabaseReader { db in
      try TagInfo.queryAll.fetchAll(db)
    } ?? []
    return VStack {
      StyledList {
        Section {
          TagButtonView(store: Store(initialState: .init(tagInfo: tagInfos[0])) { TagButton() }, indicatorModifierState: .active)
          TagButtonView(store: Store(initialState: .init(tagInfo: tagInfos[1])) { TagButton() }, indicatorModifierState: .none)
        } header: {
          StyledHeader { Text("Foo") }
        }
      }
      StyledList {
        Section {
          TagButtonView(store: Store(initialState: .init(tagInfo: tagInfos[0])) { TagButton() }, indicatorModifierState: .active)
          TagButtonView(store: Store(initialState: .init(tagInfo: tagInfos[1])) { TagButton() }, indicatorModifierState: .none)
        } header: {
          StyledHeader { Text("Bar") }
        }
      }
      Spacer(minLength: 1)
    }
  }
}

#Preview {
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
    installApplicationFont()
    $0.defaultDatabase = previewDatabase()
  }

  TagButtonView.preview
    .environment(\.font, Font.body)
}

#endif
