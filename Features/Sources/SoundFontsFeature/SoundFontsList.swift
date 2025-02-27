// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftData
import SwiftUI
import Models

@Reducer
public struct SoundFontsList {

  @Reducer
  public enum Destination {
    case edit(SoundFontEditor)
    // case picker(SoundFontPicker)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    @Shared(.activeState) var activeState

    var rows: IdentifiedArrayOf<SoundFontButton.State>
    var addingSoundFonts: Bool = false
    var showingAddedSummary: Bool = false
    var addedSummary: String = ""

    public init(soundFonts: [SoundFontModel]) {
      self.rows = .init(uniqueElements: soundFonts.map { .init(soundFont: $0) })
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case activeTagKeyChanged(TagModel.Key?)
    case addButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case fetchSoundFonts
    case onAppear
    case pickerDismissed
    case pickerSelected([URL])
    case rows(IdentifiedActionOf<SoundFontButton>)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {

      case .activeTagKeyChanged(let activeTagKey):
        fetchSoundFonts(&state, key: activeTagKey)
        return .none

      case .addButtonTapped:
        state.addingSoundFonts = true
        return .none

      case .binding:
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
        fetchSoundFonts(&state, key: state.activeState.activeTagKey)
        return .publisher {
          state.$activeState.activeTagKey.publisher.map { Action.activeTagKeyChanged($0) }
        }

      case .pickerDismissed:
        state.destination = nil
        return .none

      case .pickerSelected(let urls):
        addSoundFonts(&state, urls: urls)
        return .none

      case .rows(.element(_, .delegate(.deleteSoundFont(let key)))):
        deleteSoundFont(&state, key: key)
        return .send(.fetchSoundFonts)

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
  }
}

extension SoundFontsList.Destination.State: Equatable {}

extension SoundFontsList {

  private func addSoundFonts(_ state: inout State, urls: [URL]) {
    guard !urls.isEmpty,
          let result = Support.addSoundFonts(urls: urls)
    else {
      return
    }

    if result.bad.isEmpty {
      if result.good.count == 1 {
        state.addedSummary = "Added sound font \(result.good[0].displayName)."
      } else {
        state.addedSummary = "Added all of the sound fonts."
      }
    } else {
      if urls.count == 1 {
        state.addedSummary = "Failed to add sound font."
      } else if result.good.isEmpty {
        state.addedSummary = "Failed to add any sound fonts."
      } else {
        state.addedSummary = "Added \(result.good.count) out of \(urls.count) sound fonts."
      }
    }
    state.showingAddedSummary = true
  }

  private func deleteSoundFont(_ state: inout State, key: SoundFontModel.Key) {
    do {
      try SoundFontModel.delete(key: key)
    } catch {
      print("failed to delete font \(key) - \(error.localizedDescription)")
    }
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
      let activeTagKeyValue = state.activeState.activeTagKey?.uuidString ?? "???"
      print("failed to fetch sound fonts tagged with \(activeTagKeyValue)")
    }
  }
}

public struct SoundFontsListView: View {
  @Bindable private var store: StoreOf<SoundFontsList>

  private var activeTagKey: TagModel.Key {
    store.activeState.activeTagKey ?? TagModel.Ubiquitous.all.key
  }

  public init(store: StoreOf<SoundFontsList>) {
    self.store = store
  }

  public var body: some View {
    List {
      ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
        SoundFontButtonView(store: rowStore)
      }
    }
    .navigationTitle("SoundFonts")
    .toolbar {
      Button {
      } label: {
        Image(systemName: "tag")
      }
      Button {
        store.send(.addButtonTapped)
      } label: {
        Image(systemName: "plus")
      }
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
    .sheet(isPresented: $store.addingSoundFonts) {
      SF2PickerView {
        store.send(.pickerDismissed)
      } onOpen: {
        store.send(.pickerSelected($0))
      }
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

