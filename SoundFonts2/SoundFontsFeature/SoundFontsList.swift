// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Dependencies
import SharingGRDB
import SwiftUI
import UniformTypeIdentifiers

@Reducer
public struct SoundFontsList {

  @Reducer
  public enum Destination {
    case edit(SoundFontEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    var rows: IdentifiedArrayOf<SoundFontButton.State> = []
    var addingSoundFonts: Bool = false
    var showingAddedSummary: Bool = false
    var addedSummary: String = ""

    public init() {}
  }

  public enum Action {
    case activeTagIdChanged(FontTag.ID?)
    case destination(PresentationAction<Destination.Action>)
    case onAppear
    case rows(IdentifiedActionOf<SoundFontButton>)
    case showActiveSoundFont
    case soundFontInfosChanged([SoundFontInfo])
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .activeTagIdChanged: return monitorFetchAll(&state)
      case .destination: return .none
      case .onAppear: return monitorActiveTag(&state)
      case let .rows(.element(_, .delegate(action))): return dispatchRowAction(&state, action: action)
      case .rows: return .none
      case let .soundFontInfosChanged(soundFontInfos): return updateRows(&state, soundFontInfos: soundFontInfos)
      case .showActiveSoundFont: return showActiveSoundFont(&state)
      }
    }
    .forEach(\.rows, action: \.rows) {
      SoundFontButton()
    }
    .ifLet(\.$destination, action: \.destination)
  }

  private enum CancelId {
    case activeTagId
    case fetchAll
  }
}

extension SoundFontsList.Destination.State: Equatable {}

extension SoundFontsList {

  private func add(_ state: inout State) -> Effect<Action> {
    state.addingSoundFonts = true
    return .none
  }

  private func delete(_ state: inout State, soundFontId: SoundFont.ID) -> Effect<Action> {
    return .none

    //    do {
    //      try SoundFontModel.delete(key: key)
    //    } catch {
    //      print("failed to delete font \(key) - \(error.localizedDescription)")
    //    }
  }

  private func dispatchRowAction(_ state: inout State, action: SoundFontButton.Delegate) -> Effect<Action> {
    print("dispatchRowAction: \(action)")
    switch action {
    case let .deleteSoundFont(soundFont): return delete(&state, soundFontId: soundFont.id)
    case let .editSoundFont(soundFont): return edit(&state, soundFontId: soundFont.id)
    case let .selectSoundFont(soundFont): return select(&state, soundFontId: soundFont.id)
    }
  }

  private func edit(_ state: inout State, soundFontId: SoundFont.ID) -> Effect<Action> {
    @Dependency(\.defaultDatabase) var database
    guard let soundFont = try? database.read({ db in
      return try SoundFont.all.find(soundFontId).fetchOne(db)
    })
    else {
      return .none
    }

    state.destination = .edit(SoundFontEditor.State(soundFont: soundFont))
    return .none
  }

  private func importFiles(_ state: inout State, result: Result<[URL], Error>) -> Effect<Action> {
    return .none

    //    guard !urls.isEmpty,
    //          let result = Support.addSoundFonts(urls: urls)
    //    else {
    //      return
    //    }
    //
    //    if result.bad.isEmpty {
    //      if result.good.count == 1 {
    //        state.addedSummary = "Added sound font \(result.good[0].displayName)."
    //      } else {
    //        state.addedSummary = "Added all of the sound fonts."
    //      }
    //    } else {
    //      if urls.count == 1 {
    //        state.addedSummary = "Failed to add sound font."
    //      } else if result.good.isEmpty {
    //        state.addedSummary = "Failed to add any sound fonts."
    //      } else {
    //        state.addedSummary = "Added \(result.good.count) out of \(urls.count) sound fonts."
    //      }
    //    }
    //    state.showingAddedSummary = true
  }

  private func monitorActiveTag(_ state: inout State) -> Effect<Action> {
    return .publisher {
      @Shared(.activeState) var activeState
      return $activeState.activeTagId.publisher.map {
        print("activeTagId changed to \(String(describing: $0))")
        return Action.activeTagIdChanged($0)
      }
    }.cancellable(id: CancelId.activeTagId, cancelInFlight: true)
  }

  private func monitorFetchAll(_ state: inout State) -> Effect<Action> {
    return .run { send in
      // Create a query for the SoundFonf list view. When the DB changes, this will emit a `soundFontInfoChanged` action
      // causing the rows to change. The query depends on the value of `activeState.activeTagId` so when that changes,
      // `monitorFetchAll` reruns which cancels the old query and installs a new one.
      print("start monitoring fetchAll")
      @FetchAll(SoundFontInfo.taggedQuery) var soundFontInfos
      try await $soundFontInfos.load(SoundFontInfo.taggedQuery)
      for try await update in $soundFontInfos.publisher.values {
        await send(.soundFontInfosChanged(update))
      }
    }.cancellable(id: CancelId.fetchAll, cancelInFlight: true)
  }

  private func select(_ state: inout State, soundFontId: SoundFont.ID) -> Effect<Action> {
    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.selectedSoundFontId = soundFontId
    }
    return .none
  }

  private func showActiveSoundFont(_ state: inout State) -> Effect<Action> {
    @Shared(.activeState) var activeState
    if let activeSoundFontId = activeState.activeSoundFontId {
      return select(&state, soundFontId: activeSoundFontId)
    } else {
      return .none
    }
  }

  @discardableResult
  private func updateRows(_ state: inout State, soundFontInfos: [SoundFontInfo]) -> Effect<Action> {
    let update = IdentifiedArrayOf<SoundFontButton.State>(uncheckedUniqueElements: soundFontInfos.map { .init(soundFontInfo: $0) })
    if state.rows != update {
      state.rows = update
    }
    return .none
  }
}

public struct SoundFontsListView: View {
  @Bindable private var store: StoreOf<SoundFontsList>
  @Shared(.activeState) private var activeState

  let types = ["com.braysoftware.sf2", "com.soundblaster.soundfont"].compactMap { UTType($0) }

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
      store.send(.onAppear)
    }
    .sheet(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) {
      SoundFontEditorView(store: $0)
    }
//    .fileImporter(isPresented: $store.addingSoundFonts, allowedContentTypes: types, allowsMultipleSelection: true) {
//      store.send(.importFiles($0))
//    }
//    .alert("Add Complete", isPresented: $store.showingAddedSummary) {
//      Button("OK") {}
//    } message: {
//      Text(store.addedSummary)
//    }
//    .sheet(
//      item: $store.scope(state: \.destination?.edit, action: \.destination.edit)
//    ) { editorStore in
//      SoundFontEditorView(store: editorStore)
//    }
  }

//  @ViewBuilder
//  private func button(_ soundFontInfo: SoundFontInfo) -> some View {
//    let state: IndicatorModifier.State = {
//      activeState.activeSoundFontId == soundFontInfo.id ? .active :
//      activeState.selectedSoundFontId == soundFontInfo.id ? .selected : .none
//    }()
//
//    Button {
//      store.send(.soundFontButtonTapped(soundFontInfo), animation: .default)
//    } label: {
//      Text(soundFontInfo.displayName)
//        .font(.buttonFont)
//        .indicator(state)
//    }
//    .listRowSeparatorTint(.accentColor.opacity(0.5))
////    .confirmationDialog($store.scope(state: \.confirmationDialog, action: \.confirmationDialog))
//    .swipeActions(edge: .leading, allowsFullSwipe: false) {
//      Button {
//        store.send(.soundFontSwipedToEdit(soundFontInfo), animation: .default)
//      } label: {
//        Image(systemName: "pencil")
//          .tint(.cyan)
//      }
//    }
//    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
//      if !soundFontInfo.isBuiltIn {
//        Button {
//          store.send(.soundFontSwipedToDelete(soundFontInfo), animation: .default)
//        } label: {
//          Image(systemName: "trash")
//            .tint(.red)
//        }
//      }
//    }
//  }
}

extension SoundFontsListView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
    }

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
