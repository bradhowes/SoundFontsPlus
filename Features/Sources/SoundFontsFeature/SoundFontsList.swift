// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftData
import SwiftUI
import Models

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
    case activeTagKeyChanged(TagModel.Key?)
    case addButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case fetchSoundFonts
    case onAppear
    case rows(IdentifiedActionOf<SoundFontButton>)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .activeTagKeyChanged(let activeTagKey):
        fetchSoundFonts(&state, key: activeTagKey)
        return .none

      case .addButtonTapped:
        return .none

      case .destination(.dismiss):
        fetchSoundFonts(&state, key: state.activeState.activeTagKey)
        return .none

      case .destination:
        return .none

      case .fetchSoundFonts:
        fetchSoundFonts(&state, key: state.activeState.activeTagKey)
        return .none

      case .onAppear:
        return .publisher {
          state.$activeState.activeTagKey.publisher.map { Action.activeTagKeyChanged($0) }
        }

      case .rows(.element(_, .delegate(.deleteSoundFont(let key)))):
        deleteSoundFont(&state, key: key)
        return .none

      case .rows(.element(_, .delegate(.editSoundFont(let key)))):
        editSoundFont(&state, key: key)
        return .none

      case .rows(.element(_, .delegate(.selectSoundFont(let key)))):
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

  private func editSoundFont(_ state: inout State, key: SoundFontModel.Key) {
    do {
      let soundFont = try SoundFontModel.fetch(key: key)
      let tags = try TagModel.tags()
      state.destination = .edit(SoundFontEditor.State(soundFont: soundFont, tags: tags))
    } catch {
      print("failed to locate soundfont with key \(key)")
    }
  }

  private func fetchSoundFonts(_ state: inout State, key: TagModel.Key?) {
    do {
      let key = key ?? TagModel.Ubiquitous.all.key
      state.rows = .init(uniqueElements: try SoundFontModel.tagged(with: key).map { .init(soundFont: $0) })
    } catch {
      state.rows = []
      print("failed to fetch sound fonts tagged with \(state.activeState.activeTagKey)")
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
//        if rowStore.soundFont.tags.map(\.key).contains(activeTagKey) {
          SoundFontButtonView(store: rowStore)
//        }
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
    .onAppear {
      store.send(.onAppear)
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
    }
  }
}

#Preview {
  SoundFontsListView.preview
}

