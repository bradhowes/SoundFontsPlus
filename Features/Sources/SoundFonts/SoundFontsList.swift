// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import SQLiteData
import Tags

@Reducer
public struct SoundFontsList {

  @ObservableState
  public struct State: Equatable {
    public var rows: IdentifiedArrayOf<SoundFontButton.State>

    public init(rows: IdentifiedArrayOf<SoundFontButton.State> = []) {
      self.rows = rows
    }
  }

  public enum Action {
    case activeTagIdChanged(FontTag.ID)
    case delegate(Delegate)
    case deinitialize
    case initialize
    case rows(IdentifiedActionOf<SoundFontButton>)
    case showActiveSoundFont
    case soundFontInfosChanged([SoundFontInfo])

    @CasePathable
    public enum Delegate: Equatable {
      case edit(SoundFont)
    }
  }

  public init() {}

  @Dependency(\.defaultDatabase) private var database
  @Shared(.activeState) private var activeState
  @Shared(.selectedSoundFontId) private var selectedSoundFontId

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
        
      case .activeTagIdChanged(let tagId):
        return monitorFetchAll(&state, tagId: tagId)
        
      case .deinitialize:
        return .merge(CancelId.allCases.map { .cancel(id: $0) })
        
      case .initialize:
        let tagId = activeState.activeTagId ?? -1
        return .merge(
          monitorFetchAll(&state, tagId: tagId),
          monitorActiveTag(&state)
        )

      case .rows(.element(_, .delegate(let action))):
        return dispatchRowAction(&state, action: action)

      case .showActiveSoundFont:
        return showActiveSoundFont(&state)

      case .soundFontInfosChanged(let soundFontInfos):
        return updateRows(&state, soundFontInfos: soundFontInfos)

      default:
        return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      SoundFontButton()
    }
  }

  private enum CancelId: CaseIterable {
    case monitorActiveTagId
    case monitorFetchAll
  }
}

extension SoundFontsList {

  private func dispatchRowAction(_ state: inout State, action: SoundFontButton.Delegate) -> Effect<Action> {
    print("dispatchRowAction: \(action)")
    switch action {

    case .deleteSoundFont(let soundFont):
      SoundFont.delete(id: soundFont.id)
      return .none

    case .editSoundFont(let soundFont):
      return edit(&state, soundFontId: soundFont.id)

    case .selectSoundFont(let soundFont):
      return select(&state, soundFontId: soundFont.id)
    }
  }

  private func edit(_ state: inout State, soundFontId: SoundFont.ID) -> Effect<Action> {
    guard let soundFont = try? database.read({ db in
      return try SoundFont.all.find(soundFontId).fetchOne(db)
    })
    else {
      return .none
    }

    return .send(.delegate(.edit(soundFont)))
  }

  private func monitorActiveTag(_ state: inout State) -> Effect<Action> {
    .publisher {
      $activeState.activeTagId
        .publisher
        .removeDuplicates()
        .map { .activeTagIdChanged($0 ?? FontTag.ID(rawValue: -1)) }
    }.cancellable(id: CancelId.monitorActiveTagId, cancelInFlight: true)
  }

  private func monitorFetchAll(_ state: inout State, tagId: FontTag.ID) -> Effect<Action> {
    .run { send in
      // Update a query for the SoundFont list view. When the DB changes, this will emit a `soundFontInfoChanged` action
      // causing the rows to change. The query depends on the value of `activeState.activeTagId` so when that changes,
      // `monitorFetchAll` reruns which cancels the old query and installs a new one.
      @FetchAll(SoundFontInfo.query(id: tagId)) var soundFontInfos
      try await $soundFontInfos.load(SoundFontInfo.query())
      for try await update in $soundFontInfos.publisher.values {
        await send(.soundFontInfosChanged(update))
      }
    }.cancellable(id: CancelId.monitorFetchAll, cancelInFlight: true)
  }

  private func select(_ state: inout State, soundFontId: SoundFont.ID) -> Effect<Action> {
    if selectedSoundFontId != soundFontId {
      $selectedSoundFontId.withLock { $0 = soundFontId }
    }
    return .none
  }

  private func showActiveSoundFont(_ state: inout State) -> Effect<Action> {
    if let activeSoundFontId = activeState.activeSoundFontId {
      return select(&state, soundFontId: activeSoundFontId)
    } else {
      return .none
    }
  }

  private func updateRows(_ state: inout State, soundFontInfos: [SoundFontInfo]) -> Effect<Action> {
    let update = IdentifiedArrayOf<SoundFontButton.State>(
      uncheckedUniqueElements: soundFontInfos.map {
        .init(soundFontInfo: $0)
      }
    )
    if state.rows != update {
      state.rows = update
    }
    return .none
  }
}

public struct SoundFontsListView: View {
  @Bindable private var store: StoreOf<SoundFontsList>

  public init(store: StoreOf<SoundFontsList>) {
    self.store = store
  }

  public var body: some View {
    StyledList {
      Section {
        ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
          StyledEntry {
            SoundFontButtonView(store: rowStore)
          }
        }
      } header: {
        StyledHeader { Text("Files") }
      }
    }
    .task {
      await store.send(.initialize).finish()
    }
  }
}

extension SoundFontsListView {
  static var preview: some View {
    prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
    }

    // swiftlint:disable:next force_try
    let tag = try! FontTag.make(displayName: "My Tag")
    Operations.tagSoundFont(tag.id, soundFontId: .init(rawValue: 2))

    return VStack {
      SoundFontsListView(store: Store(initialState: .init()) { SoundFontsList() })
      TagsListView(store: Store(initialState: .init()) { TagsList() })
    }
  }
}

#Preview {
  SoundFontsListView.preview
}
