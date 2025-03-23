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
  public struct State: Equatable, Identifiable {
    public var id: Int { section }
    let section: Int
    var rows: IdentifiedArrayOf<PresetButton.State>

    public init(section: Int, presets: ArraySlice<Preset>) {
      self.section = section
      self.rows = .init(uniqueElements: presets.map { .init(preset: $0) })
    }

    /**
     Update any row that is showing the given preset

     - parameter preset: the preset to update with
     - returns: true if updated
     */
    mutating func update(preset: Preset) -> Bool {
      guard let index = rows.firstIndex(where: { $0.id == preset.id }) else { return false }
      rows[index].preset = preset
      return true
    }
  }

  public enum Action: Equatable {
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
  @Environment(\.editMode) private var editMode

  public init(store: StoreOf<PresetsListSection>) {
    self.store = store
  }

  public var body: some View {
    let header = Text(store.section > 0 ? "\(store.section)" : "")
      .foregroundStyle(.indigo)
    // .listRowInsets(EdgeInsets(top: -20, leading: 10, bottom: 0, trailing: 0))

    Section(header: header) {
      if editMode?.wrappedValue == EditMode.active {
        editingRows
      } else {
        buttonRows
      }
    }
    // .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
  }

  private var buttonRows: some View {
    ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
      PresetButtonView(store: rowStore)
        .id(rowStore.preset.id)
    }
  }

  private var editingRows: some View {
    ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
      HStack {
        PresetButtonView(store: rowStore)
        Spacer()
        Image(systemName: rowStore.preset.visible ? "checkmark" : "circle")
          .foregroundStyle(.blue)
          .onTapGesture {
            rowStore.send(.toggleVisibility, animation: .default)
          }
      }
    }
  }
}

#Preview {
  PresetsListView.preview
}
