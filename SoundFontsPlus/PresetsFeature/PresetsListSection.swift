// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI

/**
 Minor feature that represents section of presets where each section has up to 10 entries in it.
 */
@Reducer
public struct PresetsListSection {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var id: Int { sectionId }
    let section: Int
    var rows: IdentifiedArrayOf<PresetButton.State>

    // Make the id change if the number of rows in the section changes to allow for searching
    public var sectionId: Int { (section + 1) * 10_000 + rows.count }
    public var previousSectionId: Int { section * 10_000 + rows.count }

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
    case delegate(Delegate)
    case headerTapped(Int)
    case rows(IdentifiedActionOf<PresetButton>)
    case searchButtonTapped

    public enum Delegate: Equatable {
      case headerTapped(Preset.ID)
      case searchButtonTapped
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .delegate: return .none
      case let .headerTapped(count): return headerTapped(&state, count: count)
      case .rows: return .none
      case .searchButtonTapped: return .send(.delegate(.searchButtonTapped))
      }
    }
    .forEach(\.rows, action: \.rows) {
      PresetButton()
    }
  }

  private func headerTapped(_ state: inout State, count: Int) -> Effect<Action> {
    if count == 1 {
      return .send(.delegate(.headerTapped(Preset.ID(rawValue: Int64(state.section - 19)))))
    } else {
      return .send(.delegate(.headerTapped(Preset.ID(rawValue: Int64(1)))))
    }
  }
}

public struct PresetsListSectionView: View {
  private var store: StoreOf<PresetsListSection>
  private let searching: Bool

  @State private var showSearchButton: Bool = false
  @Environment(\.editMode) var editMode

  public init(store: StoreOf<PresetsListSection>, searching: Bool) {
    self.store = store
    self.searching = searching
  }

  public var body: some View {
    Section {
      buttonRows
    } header: {
      sectionHeader
        .onTapGesture(count: 2) {
          store.send(.headerTapped(2))
        }
        .onTapGesture(count: 1) {
          store.send(.headerTapped(1))
        }
    }
    .id(store.sectionId)
  }

  @ViewBuilder
  private var sectionHeader: some View {
    if searching {
      Text(sectionText)
        .foregroundStyle(Color.accentColor)
    } else {
      HStack {
        Text(sectionText)
          .foregroundStyle(Color.accentColor)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        Spacer()
        if (showSearchButton || store.section == 0) && !(editMode?.wrappedValue.isEditing ?? false) {
          Button {
            store.send(.searchButtonTapped)
          } label: {
            Image(systemName: "magnifyingglass")
              .imageScale(.small)
          }
        }
      }
      // Track vertical position of our header -- when it becomes pinned, show the search button
      .onGeometryChange(for: Double.self) {
        $0.frame(in: .global).origin.y
      } action: {
        showSearchButton = $0 < 70.0
      }
    }
  }

  private var sectionText: String {
    if searching {
      return "Found \(store.rows.count)"
    } else if store.section == 0 {
      return "Presets"
    } else {
      return "\(store.section)"
    }
  }

  private var buttonRows: some View {
    ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
      PresetButtonView(store: rowStore)
    }
  }
}

/// A preference key to store ScrollView offset
public struct ViewOffsetKey: PreferenceKey {
  public typealias Value = CGFloat
  public static let defaultValue = CGFloat.zero
  public static func reduce(value: inout Value, nextValue: () -> Value) {
    value += nextValue()
  }
}

#Preview {
  PresetsListView.previewEditing
}
