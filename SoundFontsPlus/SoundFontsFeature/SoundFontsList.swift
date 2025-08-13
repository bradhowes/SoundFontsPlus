// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Dependencies
import SharingGRDB
import SwiftUI

@Reducer
public struct SoundFontsList {

  @ObservableState
  public struct State: Equatable {
    var rows: IdentifiedArrayOf<SoundFontButton.State> = []

    public init() {}
  }

  public enum Action {
    case activeTagIdChanged(FontTag.ID?)
    case delegate(Delegate)
    case initialize
    case rows(IdentifiedActionOf<SoundFontButton>)
    case showActiveSoundFont
    case soundFontInfosChanged([SoundFontInfo])

    public enum Delegate {
      case edit(SoundFont)
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .activeTagIdChanged:
        return monitorFetchAll(&state)
      case .initialize:
        return monitorActiveTag(&state)
      case .rows(.element(_, .delegate(let action))):
        return dispatchRowAction(&state, action: action)
      case .showActiveSoundFont:
        return showActiveSoundFont(&state)
      case .soundFontInfosChanged(let soundFontInfos):
        return updateRows(&state, soundFontInfos: soundFontInfos)
      default:
        break
      }
      return .none
    }
    .forEach(\.rows, action: \.rows) {
      SoundFontButton()
    }
  }

  private enum CancelId {
    case monitorActiveTagId
    case monitorFetchAll
  }

  @Dependency(\.defaultDatabase) var database
  @Shared(.activeState) var activeState
}

extension SoundFontsList {

  private func dispatchRowAction(_ state: inout State, action: SoundFontButton.Delegate) -> Effect<Action> {
    print("dispatchRowAction: \(action)")
    switch action {
    case .deleteSoundFont(let soundFont):
      SoundFont.delete(id: soundFont.id)
    case .editSoundFont(let soundFont):
      return edit(&state, soundFontId: soundFont.id)
    case .selectSoundFont(let soundFont):
      return select(&state, soundFontId: soundFont.id)
    }
    return .none
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
        .map { .activeTagIdChanged($0) }
    }.cancellable(id: CancelId.monitorActiveTagId, cancelInFlight: true)
  }

  private func monitorFetchAll(_ state: inout State) -> Effect<Action> {
    return .run { send in
      // Update a query for the SoundFont list view. When the DB changes, this will emit a `soundFontInfoChanged` action
      // causing the rows to change. The query depends on the value of `activeState.activeTagId` so when that changes,
      // `monitorFetchAll` reruns which cancels the old query and installs a new one.
      @FetchAll(SoundFontInfo.taggedQuery) var soundFontInfos
      try await $soundFontInfos.load(SoundFontInfo.taggedQuery)
      for try await update in $soundFontInfos.publisher.values {
        await send(.soundFontInfosChanged(update))
      }
    }.cancellable(id: CancelId.monitorFetchAll, cancelInFlight: true)
  }

  private func select(_ state: inout State, soundFontId: SoundFont.ID) -> Effect<Action> {
    $activeState.withLock {
      $0.selectedSoundFontId = soundFontId
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
    StyledList(title: "Files") {
      ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
        SoundFontButtonView(store: rowStore)
      }
    }
    .onAppear {
      store.send(.initialize)
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
