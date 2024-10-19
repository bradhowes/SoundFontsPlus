// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftData
import SwiftUI
import Models

@Reducer
public struct SoundFontEditor {
  public struct State: Equatable {
    let soundFont: SoundFontModel
  }
  public enum Action: Sendable {
  }
}

@Reducer
public struct SoundFontsList {

  @Reducer(action: .sendable)
  public enum Destination {
    case edit(SoundFontEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?

    var rows: IdentifiedArrayOf<SoundFontButton.State>

    @Shared(.activeState) var activeState = ActiveState()

    public init(soundFonts: IdentifiedArrayOf<SoundFontModel>) {
      self.rows = .init(uniqueElements: soundFonts.map { .init(soundFont: $0) })
    }
  }

  public enum Action: Sendable {
    case addButtonTapped
    case confirmedDeletion(key: SoundFontModel.Key)
    case destination(PresentationAction<Destination.Action>)
    case fetchSoundFonts
    case rows(IdentifiedActionOf<SoundFontButton>)
    case swipedToEdit(key: SoundFontModel.Key)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .addButtonTapped:
        return .none

      case .confirmedDeletion(let key):
        deleteSoundFont(&state, key: key)
        return .none

      case .destination(.dismiss):
        state.destination = nil
        fetchSoundFonts(&state)
        return .none

      case .destination:
        return .none

      case .fetchSoundFonts:
        fetchSoundFonts(&state)
        return .none

      case .rows(.element(_, .buttonTapped(let key))):
        return .none

      case .swipedToEdit(let key):
//        if let soundFont = state.soundFonts.first(where: {$0.key == key}) {
//          state.destination = .edit(SoundFontEditor.State(soundFont: soundFont))
//        }
        return .none
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
  private var store: StoreOf<SoundFontsList>
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
//    .sheet(
//      item: $store.scope(state: \.destination?.edit, action: \.destination.edit)
//    ) { tagEditStore in
//
//        SoundEditorView(store: tagEditStore)
//      }
//    }
  }
}

extension SoundFontsListView {

  private func deleteAction(soundFont: SoundFontModel) -> ((SoundFontModel.Key) -> Void)? {
    soundFont.location.kind == .builtin ? nil : { store.send(.confirmedDeletion(key: $0), animation: .default) }
  }
}

extension SoundFontsListView {
  static var preview: some View {
    let soundFonts = try! SoundFontModel.tagged(with: TagModel.Ubiquitous.all.key)
    return SoundFontsListView(store: Store(initialState: .init(soundFonts: .init(uniqueElements: soundFonts))) {
      SoundFontsList()
    })
  }
}

#Preview {
  SoundFontsListView.preview
}

