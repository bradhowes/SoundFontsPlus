// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport

/**
 Minor feature that represents section of presets where each section has up to 20 entries in it.
 */
@Reducer
public struct PresetsListSection {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var id: Int { sectionId }
    public let section: Int
    public var rows: IdentifiedArrayOf<PresetButton.State>
    // Make sure section IDs do not conflict with preset IDs.
    public var sectionId: Int { (section + 1) * PresetsList.noGroupingSize }

    public init(section: Int, presets: ArraySlice<Preset>, symbolPrefix: String?) {
      self.section = section
      self.rows = .init(uniqueElements: presets.map { .init(preset: $0, symbolPrefix: $0.isFavorite ? symbolPrefix : nil) })
    }

    /**
     Update any row that is showing the given preset

     - parameter presetId: the preset to update
     - parameter displayName: the new display name to show
     - returns: true if updated
     */
    public mutating func update(presetId: Preset.ID, displayName: String) {
      guard let index = rows.firstIndex(where: { $0.id == presetId }) else { return }
      rows[index].preset.displayName = displayName
    }
  }

  public enum Action {
    case delegate(Delegate)
    case rows(IdentifiedActionOf<PresetButton>)

    @CasePathable
    public enum Delegate {
      case createFavorite(Preset)
      case deleteFavorite(Preset)
      case editPreset(Preset)
      case headerTapped(scrollTo: Preset.ID)
      case hidePreset(Preset)
      case searchButtonTapped
      case selectPreset(Preset)
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case let .rows(.element(id: _, action: .delegate(action))):
        return processRowAction(&state, action: action)

      default:
        return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      PresetButton()
    }
  }

  private func processRowAction(_ state: inout State, action: PresetButton.Action.Delegate) -> Effect<Action> {
    switch action {
    case let .createFavorite(preset): return .send(.delegate(.createFavorite(preset)))
    case let .deleteFavorite(preset): return .send(.delegate(.deleteFavorite(preset)))
    case let .editPreset(preset): return .send(.delegate(.editPreset(preset)))
    case let .hidePreset(preset): return .send(.delegate(.hidePreset(preset)))
    case let .selectPreset(preset): return .send(.delegate(.selectPreset(preset)))
    }
  }
}

public struct PresetsListSectionView: View {
  private var store: StoreOf<PresetsListSection>
  private let searching: Bool
  @State private var showSearchButton: Bool = false
  @Environment(\.editMode) private var editMode
  private var editingVisibility: Bool { (editMode?.wrappedValue ?? .inactive) == .active }

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
        store.send(.delegate(.headerTapped(scrollTo: 1)))
      }
      .onTapGesture(count: 1) {
        store.send(.delegate(.headerTapped(scrollTo: Preset.ID(rawValue: Int64(store.section - (PresetsList.groupingSize - 1))))))
      }
    }
    .animation(.smooth, value: store.rows)
  }

  private var sectionHeader: some View {
    HStack {
      Text(sectionText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      Spacer()
      Button {
        store.send(.delegate(.searchButtonTapped))
      } label: {
        Image(systemName: "magnifyingglass")
          .imageScale(.small)
          .contentShape(Rectangle())
      }
      .opacity((showSearchButton || store.section == 0) && !editingVisibility ? 1.0 : 0.0)
    }
    // Track vertical position of our header -- when it becomes pinned, show the search button
    .onGeometryChange(for: Double.self) {
      $0.frame(in: .global).origin.y
    } action: {
      showSearchButton = $0 < 94.0
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

#if DEBUG

#Preview {
  PresetsListView.previewEditing
}

#endif // DEBUG
