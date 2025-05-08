// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Models
import SwiftUI
import SwiftUISupport
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
    var rows: IdentifiedArrayOf<SoundFontButton.State>
    var addingSoundFonts: Bool = false
    var showingAddedSummary: Bool = false
    var addedSummary: String = ""

    public init() {
      self.rows = .init(uniqueElements: Tag.activeTagSoundFonts.map { .init(soundFont: $0) })
    }
  }

  public enum Action: BindableAction {
    case activeTagIdChanged(Tag.ID?)
    case addButtonTapped
    case binding(BindingAction<State>)
    case destination(PresentationAction<Destination.Action>)
    case importFiles(Result<[URL], Error>)
    case onAppear
    case rows(IdentifiedActionOf<SoundFontButton>)
    case showActiveSoundFont
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .activeTagIdChanged: return refresh(&state)
      case .addButtonTapped: return add(&state)
      case .binding: return .none
      case .importFiles(let result): return importFiles(&state, result: result)
      case .destination(.dismiss): return refresh(&state)
      case .destination: return .none
      case .onAppear: return monitorActiveTag(&state)
      case let .rows(.element(_, .delegate(action))):
        switch action {
        case let .deleteSoundFont(soundFont): return delete(&state, key: soundFont.id)
        case let .editSoundFont(soundFont): return edit(&state, key: soundFont.id)
        case let .selectSoundFont(soundFont): return select(soundFont.id)
        }
      case .rows: return .none
      case .showActiveSoundFont:
        @Shared(.activeState) var activeState
        if let activeSoundFontId = activeState.activeSoundFontId {
          return select(activeSoundFontId)
        } else {
          return .none
        }
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

  private func monitorActiveTag(_ state: inout State) -> Effect<Action> {
    return .publisher {
      @Shared(.activeState) var activeState
      return $activeState.activeTagId.publisher.map { Action.activeTagIdChanged($0) }
    }.cancellable(id: publisherCancelId, cancelInFlight: true)
  }

  private func select(_ soundFontId: SoundFont.ID) -> Effect<Action> {
    @Shared(.activeState) var activeState
    $activeState.withLock { $0.selectedSoundFontId = soundFontId  }
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

  private func delete(_ state: inout State, key: SoundFont.ID) -> Effect<Action> {
    return .none
//    do {
//      try SoundFontModel.delete(key: key)
//    } catch {
//      print("failed to delete font \(key) - \(error.localizedDescription)")
//    }
  }

  private func edit(_ state: inout State, key: SoundFont.ID) -> Effect<Action> {
    guard let index = state.rows.index(id: key) else { return .none }
    state.destination = .edit(SoundFontEditor.State(soundFont: state.rows[index].soundFont))
    return .none
//    do {
//      let soundFont = try SoundFontModel.fetch(key: key)
//      let tags = try TagModel.tags()
//      state.destination = .edit(SoundFontEditor.State(soundFont: soundFont, tags: tags))
//    } catch {
//      print("failed to locate soundfont with key \(key)")
//    }
  }

  @discardableResult
  private func refresh(_ state: inout State) -> Effect<Action> {
    state.rows = .init(uniqueElements: Tag.activeTagSoundFonts.map { .init(soundFont: $0) })
    return .none.animation(.default)
//    do {
//      let key = key ?? TagModel.Ubiquitous.all.key
//      state.rows = .init(uniqueElements: try SoundFontModel.tagged(with: key).map { .init(soundFont: $0) })
//    } catch {
//      state.rows = []
//      let activeTagKeyValue = state.activeState.activeTagKey?.uuidString ?? "???"
//      print("failed to fetch sound fonts tagged with \(activeTagKeyValue)")
//    }
  }
}

public struct SoundFontsListView: View {
  @Bindable private var store: StoreOf<SoundFontsList>

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
    .fileImporter(isPresented: $store.addingSoundFonts, allowedContentTypes: types, allowsMultipleSelection: true) {
      store.send(.importFiles($0))
    }
    .alert("Add Complete", isPresented: $store.showingAddedSummary) {
      Button("OK") {}
    } message: {
      Text(store.addedSummary)
    }
    .sheet(
      item: $store.scope(state: \.destination?.edit, action: \.destination.edit)
    ) { editorStore in
      SoundFontEditorView(store: editorStore)
    }
  }
}

extension SoundFontsListView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try!.appDatabase()
    }
    return VStack {
      SoundFontsListView(store: Store(initialState: .init()) { SoundFontsList() })
    }
  }
}

#Preview {
  SoundFontsListView.preview
}

