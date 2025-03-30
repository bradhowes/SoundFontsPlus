// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftData
import SwiftUI
import Models
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

    public init(soundFonts: [SoundFont]) {
      self.rows = .init(uniqueElements: soundFonts.map { .init(soundFont: $0) })
    }
  }

  public enum Action: BindableAction {
    case activeTagIdChanged(Tag.ID?)
    case addButtonTapped
    case binding(BindingAction<State>)
    case importFiles(Result<[URL], Error>)
    case destination(PresentationAction<Destination.Action>)
    case onAppear
    case refresh
    case rows(IdentifiedActionOf<SoundFontButton>)
    case showTags
  }

  public init() {}

  @Shared(.activeState) var activeState

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
      case .refresh: return refresh(&state)
      case .onAppear: return beginPublisher(&state)
      case .rows(.element(_, .delegate(.deleteSoundFont(let soundFont)))): return delete(&state, key: soundFont.id)
      case .rows(.element(_, .delegate(.editSoundFont(let soundFont)))): return edit(&state, key: soundFont.id)
      case .rows(.element(_, .delegate(.selectSoundFont(let soundFont)))): return select(soundFont.id)
      case .rows: return .none
      case .showTags: return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      SoundFontButton()
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension SoundFontsList.Destination.State: Equatable {}

extension SoundFontsList {

  private func add(_ state: inout State) -> Effect<Action> {
    state.addingSoundFonts = true
    return .none
  }

  private func beginPublisher(_ state: inout State) -> Effect<Action> {
    _ = refresh(&state)
    return .publisher {
      $activeState.activeTagId.publisher.map { Action.activeTagIdChanged($0) }
    }
  }

  private func select(_ soundFontId: SoundFont.ID) -> Effect<Action> {
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
    state.destination = .edit(SoundFontEditor.State(soundFont: state.rows[index].soundFont, tags: []))
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
  @Bindable internal var store: StoreOf<SoundFontsList>

  let types = ["com.braysoftware.sf2", "com.soundblaster.soundfont"].compactMap { UTType($0) }

  public init(store: StoreOf<SoundFontsList>) {
    self.store = store
  }

  public var body: some View {
    NavigationStack {
      List {
        ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
          SoundFontButtonView(store: rowStore)
        }
      }
      .navigationTitle("SoundFonts")
      .environment(\.defaultMinListHeaderHeight, 1)
      .toolbar {
        Button {
          store.send(.showTags)
        } label: {
          Image(systemName: "tag")
        }
        Button {
          store.send(.addButtonTapped)
        } label: {
          Image(systemName: "plus")
        }
      }
      .fileImporter(
        isPresented: $store.addingSoundFonts,
        allowedContentTypes: types,
        allowsMultipleSelection: true
      ) {
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
      .onAppear {
        store.send(.onAppear)
      }
    }
  }
}

extension SoundFontsListView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try!.appDatabase()
    }
    @Dependency(\.defaultDatabase) var db
    let tags = Tag.ordered
    let soundFonts = try? db.read{ try tags[0].soundFonts.fetchAll($0) }
    return VStack {
      SoundFontsListView(store: Store(initialState: .init(soundFonts: soundFonts ?? [])) { SoundFontsList() })
    }
  }
}

#Preview {
  SoundFontsListView.preview
}

