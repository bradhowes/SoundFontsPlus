// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import Tagged

/**
 Minor feature that represents section of presets where each section has N preset buttons in it.
 */
@Reducer
public struct PresetsListSection {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public typealias ID = Tagged<Self, Int>

    public let id: ID
    public let section: Int // 0 is first section, 1 second, etc.
    public let sectionText: String
    public let sectionIndex: String

    public var rows: IdentifiedArrayOf<PresetButton.State>
    public var presetSource: PresetSource?
    public var activePresetId: Preset.ID?

    public init(
      section: Int,
      sectionText: String,
      sectionIndex: String,
      presets: ArraySlice<Preset>,
      presetSource: PresetSource? = nil,
      activePresetId: Preset.ID? = nil
    ) {
      @Shared(.favoriteSymbolName) var symbolName
      @Shared(.starFavoriteNames) var starFavoriteNames
      let symbolPrefix = starFavoriteNames ? symbolName : nil

      self.id = .init(rawValue: section)
      self.section = section
      self.sectionText = sectionText
      self.sectionIndex = sectionIndex
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

  public enum Action: Equatable {
    case delegate(Delegate)
    case rows(IdentifiedActionOf<PresetButton>)

    @CasePathable
    public enum Delegate: Equatable {
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
          .helpItemTag(HelpItem.presetsListHeader)
      }
      .onTapGesture(count: 2) {
        store.send(.delegate(.headerTapped(section: store.id, count: 2)))
      }
      .onTapGesture(count: 1) {
        store.send(.delegate(.headerTapped(section: store.id, count: 1)))
      }
    }
    .id(store.sectionIndex)
    .animation(.smooth, value: store.rows)
  }

  private var sectionHeader: some View {
    HStack {
      PresetsListView.sectionIndexTitleView(for: store.sectionText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      Spacer()
      Button {
        store.send(.delegate(.searchButtonTapped))
      } label: {
        HStack {
          Image(systemName: "magnifyingglass")
            .imageScale(.small)
            .contentShape(Rectangle())
          // Here to keep from overlapping the section index overlay from the parent view
          Color.clear
            .frame(width: 16)
        }
      }
      .opacity((showSearchButton || store.section == 0) && !searching && !editingVisibility ? 1.0 : 0.0)
      .animation(.smooth(duration: 0.2), value: showSearchButton)
    }
    // Track vertical position of our header -- when it becomes pinned, show the search button
    .onGeometryChange(for: Double.self) {
      $0.frame(in: .global).origin.y
    } action: {
      // !!! Magic constant hack to signal if section header should have the search button. This works ok except on iPhone in
      // landscape mode. Better to rely on some signal that the previous section header is going away.
      showSearchButton = $0 < 74.0
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
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
    installApplicationFont()
    $0.defaultDatabase = previewDatabase()
  }
  PresetsListView.preview
}

#endif // DEBUG
