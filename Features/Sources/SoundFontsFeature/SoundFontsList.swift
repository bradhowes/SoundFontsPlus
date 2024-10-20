// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftData
import SwiftUI
import Models
import TagsFeature

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
    @Shared(.activeState) var activeState = ActiveState()

    public init(soundFonts: [SoundFontModel]) {
      self.rows = .init(uniqueElements: soundFonts.map { .init(soundFont: $0) })
    }
  }

  public enum Action {
    case addButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case fetchSoundFonts
    case rows(IdentifiedActionOf<SoundFontButton>)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .addButtonTapped:
        return .none

      case .destination(.dismiss):
        // state.destination = nil
        fetchSoundFonts(&state)
        return .none

      case .destination:
        return .none

      case .fetchSoundFonts:
        fetchSoundFonts(&state)
        return .none

      case .rows(.element(let key, .delegate(.deleteSoundFont))):
        deleteSoundFont(&state, key: key)
        return .none

      case .rows(.element(let key, .delegate(.editSoundFont))):
        if let index = state.rows.index(id: key) {
          state.destination = .edit(SoundFontEditor.State(soundFont: state.rows[index].soundFont))
        }
        return .none

      case .rows(.element(let key, .delegate(.selectSoundFont))):
        state.activeState.setSelectedSoundFontKey(key)
        return .none

      case .rows:
        return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      SoundFontButton()
    }
    .ifLet(\.$destination, action: \.destination)
    ._printChanges()
  }
}

extension SoundFontsList.Destination.State: Equatable {}

extension SoundFontsList {

  private func deleteSoundFont(_ state: inout State, key: SoundFontModel.Key) {

//    precondition(!TagModel.Ubiquitous.contains(key: key))
//    do {
//      if state.activeTagKey == key {
//        state.activeTagKey = TagModel.Ubiquitous.all.key
//      }
//      state.tags = state.tags.filter { $0.key != key }
//      try TagModel.delete(key: key)
//    } catch {
//      print("failed to delete tag \(key)")
//    }
  }

  private func fetchSoundFonts(_ state: inout State) {
    @Shared(.activeTagKey) var activeTagKey
    do {
      state.rows = .init(uniqueElements: try SoundFontModel.tagged(with: activeTagKey).map { .init(soundFont: $0) })
    } catch {
      state.rows = []
      print("failed to fetch sound fonts tagged with \(activeTagKey)")
    }
  }
}

public struct SoundFontsListView: View {
  @Bindable private var store: StoreOf<SoundFontsList>
  @Shared(.activeState) var activeState = .init()
  private var activeTagKey: TagModel.Key {
    activeState.activeTagKey ?? TagModel.Ubiquitous.all.key
  }

  public init(store: StoreOf<SoundFontsList>) {
    self.store = store
  }

  public var body: some View {
    List {
      ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
        if rowStore.soundFont.tags.map(\.key).contains(activeTagKey) {
          SoundFontButtonView(store: rowStore)
        }
      }
    }
    HStack {
      Button("Add SoundFont", systemImage: "plus") {
        store.send(.addButtonTapped, animation: .default)
      }
    }
    .onAppear() {
      _ = store.send(.fetchSoundFonts)
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
    let tags = (try? TagModel.tags()) ?? []
    _ = try! SoundFontModel.tagged(with: TagModel.Ubiquitous.all.key)
    _ = [
      try! Mock.makeSoundFont(name: "Mommy", presetNames: ["One", "Two", "Three", "Four"], tags: [tags[0], tags[2]]),
      try! Mock.makeSoundFont(name: "Daddy", presetNames: ["One", "Two", "Three", "Four"], tags: [tags[0], tags[3]]),
    ]
    let soundFonts = try! SoundFontModel.tagged(with: TagModel.Ubiquitous.all.key)
    return VStack {
      SoundFontsListView(store: Store(initialState: .init(soundFonts: soundFonts)) { SoundFontsList() })
      TagsListView(store: Store(initialState: .init(tags: tags)) { TagsList() })
    }
  }
}

#Preview {
  SoundFontsListView.preview
}

