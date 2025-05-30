// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
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

    @ObservationStateIgnored
    @FetchAll var soundFontInfos: [SoundFontInfo]

    var addingSoundFonts: Bool = false
    var showingAddedSummary: Bool = false
    var addedSummary: String = ""

    public init() {
      _soundFontInfos = FetchAll(soundFontsQuery, animation: .default)
    }

    var soundFontsQuery: Select<SoundFontInfo.Columns.QueryValue, TaggedSoundFont, SoundFont> {
      @Shared(.activeState) var activeState
      return TaggedSoundFont
        .join(SoundFont.all) {
          $0.tagId.eq(activeState.activeTagId ?? Tag.Ubiquitous.all.id) && $0.soundFontId.eq($1.id)
        }
        .select {
          SoundFontInfo.Columns(id: $1.id, displayName: $1.displayName, kind: $1.kind, location: $1.location)
        }
    }

    func updateQuery() async {
      await withErrorReporting {
        try await $soundFontInfos.load(soundFontsQuery, animation: .default)
      }
    }
  }

  public enum Action {
    case activeTagIdChanged(Tag.ID?)
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
      case .activeTagIdChanged: return updateQuery(&state)
      // case .destination(.dismiss): return refresh(&state)
      case .destination: return .none
      case .onAppear: return monitor(&state)
      case let .rows(.element(_, .delegate(action))): return dispatchRowAction(&state, action: action)
      case .rows: return .none
      case let .soundFontInfosChanged(soundFontInfos): return setSoundFontInfos(&state, soundFontInfos: soundFontInfos)
      case .showActiveSoundFont: return showActiveSoundFont(&state)
      }
    }
    .forEach(\.rows, action: \.rows) {
      SoundFontButton()
    }
    .ifLet(\.$destination, action: \.destination)
  }

  let publisherCancelId = "SoundFontsList.publisherCancelId"
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
    switch action {
    case let .deleteSoundFont(soundFont): return delete(&state, soundFontId: soundFont.id)
    case let .editSoundFont(soundFont): return edit(&state, soundFontId: soundFont.id)
    case let .selectSoundFont(soundFont): return select(&state, soundFontId: soundFont.id)
    }
  }

  private func edit(_ state: inout State, soundFontId: SoundFont.ID) -> Effect<Action> {
    //    guard let index = state.rows.index(id: key) else { return .none }
    //    state.destination = .edit(SoundFontEditor.State(soundFont: state.rows[index].soundFont))
    return .none
    //    do {
    //      let soundFont = try SoundFontModel.fetch(key: key)
    //      let tags = try TagModel.tags()
    //      state.destination = .edit(SoundFontEditor.State(soundFont: soundFont, tags: tags))
    //    } catch {
    //      print("failed to locate soundfont with key \(key)")
    //    }
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

  private func monitor(_ state: inout State) -> Effect<Action> {
    return .merge(
      .publisher {
        @Shared(.activeState) var activeState
        return $activeState.activeTagId.publisher.map { Action.activeTagIdChanged($0) }
      },
      .publisher {
        state.$soundFontInfos.publisher.map { Action.soundFontInfosChanged($0) }
      }
    ).cancellable(id: publisherCancelId, cancelInFlight: true)
  }

  private func setSoundFontInfos(_ state: inout State, soundFontInfos: [SoundFontInfo]) -> Effect<Action> {
    state.rows = .init(uncheckedUniqueElements: soundFontInfos.map { .init(soundFontInfo: $0) })
    return .none
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
  private func updateQuery(_ state: inout State) -> Effect<Action> {
    let tmp = state
    return .run { send in
      Task {
        await tmp.updateQuery()
      }
    }
  }
}

public struct SoundFontsListView: View {
  private var store: StoreOf<SoundFontsList>
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

    let tag = try! Tag.make(displayName: "My Tag")
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
