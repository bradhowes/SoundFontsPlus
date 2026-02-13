// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import Tagged

/**
 Minor feature that represents section of presets where each section has up to 20 entries in it.
 */
@Reducer
public struct PresetsListSection {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public typealias ID = Tagged<Self, Int>

    public let id: ID
    public let section: Int // 0 is first section, 1 second, etc.
    public let sectionText: String

    public var rows: IdentifiedArrayOf<PresetButton.State>
    public var presetSource: PresetSource?
    public var activePresetId: Preset.ID?

    public init(
      section: Int,
      sectionText: String,
      presets: ArraySlice<Preset>,
      presetSource: PresetSource?,
      activePresetId: Preset.ID?
    ) {
      @Shared(.favoriteSymbolName) var symbolName
      @Shared(.starFavoriteNames) var starFavoriteNames
      let symbolPrefix = starFavoriteNames ? symbolName : nil

      self.id = .init(rawValue: section)
      self.section = section
      self.sectionText = sectionText
      self.presetSource = presetSource
      self.activePresetId = activePresetId
      self.rows = .init(
        uniqueElements: presets.map {
          .init(
            preset: $0,
            symbolPrefix: $0.isFavorite ? symbolPrefix : nil
          )
        }
      )
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
      case headerTapped(section: PresetsListSection.State.ID, count: Int)
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
    case let .selectPreset(preset):
      state.activePresetId = preset.id
      state.presetSource = state.presetSource?.activated
      return .send(.delegate(.selectPreset(preset)))
    }
  }
}

public struct PresetsListSectionView: View {
  private var store: StoreOf<PresetsListSection>
  private let searching: Bool
  @State private var showSearchButton: Bool = false
  @Environment(\.editMode) private var editMode
  private var editingVisibility: Bool { (editMode?.wrappedValue ?? .inactive) == .active }

  public init(
    store: StoreOf<PresetsListSection>,
    searching: Bool
  ) {
    self.store = store
    self.searching = searching
  }

  public var body: some View {
    Section {
      buttonRows
    } header: {
      StyledHeader {
        sectionHeader
          .id(store.id)
      }
      .onTapGesture(count: 2) {
        store.send(.delegate(.headerTapped(section: store.id, count: 2)))
      }
      .onTapGesture(count: 1) {
        store.send(.delegate(.headerTapped(section: store.id, count: 1)))
      }
    }
    .animation(.smooth, value: store.rows)
  }

  private var sectionHeader: some View {
    HStack {
      Text(store.sectionText)
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
      .opacity((showSearchButton || store.section == 0) && !searching && !editingVisibility ? 1.0 : 0.0)
    }
    // Track vertical position of our header -- when it becomes pinned, show the search button
    .onGeometryChange(for: Double.self) {
      $0.frame(in: .global).origin.y
    } action: {
      showSearchButton = $0 < 94.0
    }
  }

  private var buttonRows: some View {
    ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
      StyledEntry {
        PresetButtonView(
          store: rowStore,
          indicatorModifierState: indicatorModifierState(for: rowStore.preset)
        )
      }
    }
  }

  private func indicatorModifierState(for preset: Preset) -> IndicatorModifier.State {
    if store.presetSource?.isActive ?? false,
       store.presetSource?.id == preset.soundFontId,
       store.activePresetId == preset.id {
      return preset.isFavorite ? .activeFavorite : .active
    }
    return preset.isFavorite ? .favorite : .none
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
