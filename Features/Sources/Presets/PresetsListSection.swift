// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import FeatureSupport
import Models
import SwiftUI
import Tagged

/**
 Minor feature that represents section of presets where each section has up to 10 entries in it.
 */
@Reducer
public struct PresetsListSection {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var id: Int { sectionId }
    fileprivate let section: Int
    fileprivate var rows: IdentifiedArrayOf<PresetButton.State>
    // Make sure section IDs do not conflict with preset IDs.
    fileprivate var sectionId: Int { (section + 1) * PresetsList.noGroupingSize }

    public init(section: Int, presets: ArraySlice<Preset>) {
      self.section = section
      self.rows = .init(uniqueElements: presets.map { .init(preset: $0) })
      print("PresetsListSection: \(section) - sectionId: \(sectionId)")
    }

    /**
     Update any row that is showing the given preset

     - parameter presetId: the preset to update
     - parameter displayName: the new display name to show
     - returns: true if updated
     */
    mutating func update(presetId: Preset.ID, displayName: String) {
      guard let index = rows.firstIndex(where: { $0.id == presetId }) else { return }
      rows[index].preset.displayName = displayName
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
      case .delegate:
        return .none

      case let .headerTapped(count):
        return headerTapped(&state, count: count)

      case .rows:
        return .none

      case .searchButtonTapped:
        return .send(.delegate(.searchButtonTapped))
      }
    }
    .forEach(\.rows, action: \.rows) {
      PresetButton()
    }
  }

  private func headerTapped(_ state: inout State, count: Int) -> Effect<Action> {
    // For a 1-tap, jump to first item in previous section
    // For a 2-tap, jump to first item in first section
    let target = count == 1 ? state.section - (PresetsList.groupingSize - 1) : 1
    print("headerTapped - target: \(target)")
    return .send(.delegate(.headerTapped(Preset.ID(rawValue: Int64(target)))))
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
      StyledHeader {
        sectionHeader
          .id(store.sectionId)
      }
      .onTapGesture(count: 2) {
        store.send(.headerTapped(2))
      }
      .onTapGesture(count: 1) {
        store.send(.headerTapped(1))
      }
    }
  }

  @ViewBuilder
  private var sectionHeader: some View {
    if searching {
      Text(sectionText)
    } else {
      HStack {
        Text(sectionText)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        Spacer()
        if (showSearchButton || store.section == 0) && !(editMode?.wrappedValue.isEditing ?? false) {
          Button {
            store.send(.searchButtonTapped)
          } label: {
            Image(systemName: "magnifyingglass")
              .imageScale(.small)
              .contentShape(Rectangle())
          }
        }
      }
      // Track vertical position of our header -- when it becomes pinned, show the search button
      .onGeometryChange(for: Double.self) {
        $0.frame(in: .global).origin.y
      } action: {
        showSearchButton = $0 < 94.0
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
      StyledEntry {
        PresetButtonView(store: rowStore)
      }
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
