// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import Models

/**
 Minor feature that represents section of presets where each section has up to 10 entries in it.
 */
@Reducer
public struct PresetsListSection {

  @ObservableState
  public struct State: Identifiable {
    public var id: Int { section }

    let section: Int
    var rows: IdentifiedArrayOf<PresetButton.State>

    public init(section: Int, presets: [Preset]) {
      self.section = section
      self.rows = .init(uniqueElements: presets.map { .init(preset: $0) })
    }
  }

  public enum Action {
    case rows(IdentifiedActionOf<PresetButton>)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .rows: return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      PresetButton()
    }
  }
}

public struct PresetsListSectionView: View {
  @Bindable private var store: StoreOf<PresetsListSection>
  @Shared(.activeState) private var activeState
  @Environment(\.editMode) private var editMode

  public init(store: StoreOf<PresetsListSection>) {
    self.store = store
  }

  public var body: some View {
    let header = Text(store.section == 0 ? "" : "\(store.section)")
      .font(.system(.caption2))
      .foregroundStyle(.indigo)

    Section(header: header) {
      if editMode?.wrappedValue == EditMode.active {
        ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
          HStack {
            PresetButtonView(store: rowStore)
            Spacer()
            Image(systemName: rowStore.isVisible ? "checkmark" : "circle")
              .foregroundStyle(.blue)
              .onTapGesture {
                rowStore.send(.toggleVisibility, animation: .default)
              }
          }
        }
      } else {
        ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
          PresetButtonView(store: rowStore)
        }
      }
    }
  }
}

#Preview {
  PresetsListView.preview
}
