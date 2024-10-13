// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftData
import SwiftUI
import Models

@Reducer
struct TagFeature {

  @Reducer
  enum Destination {
    case alert(AlertState<Alert>)

    @CasePathable
    enum Alert: Equatable {
      case confirmDeletion(tag: UUID)
    }
  }

  @ObservableState
  struct State: Equatable {
    @Presents var destination: Destination.State?
    @Shared(.activeTag) var activeTag
    var tags: IdentifiedArrayOf<TagModel> = []
  }

  enum Action: Sendable {
    case addButtonTapped
    case confirmDeletion(tag: UUID)
    case deleteButtonTapped(tag: UUID, name: String)
    case destination(PresentationAction<Destination.Action>)
    case longPressGestureFired
    case fetchTags
    case tagButtonTapped(tag: UUID)
  }

  @Dependency(\.dismiss) var dismiss

  var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .addButtonTapped:
        addTag(&state)
        return .none

      case .confirmDeletion(let tag):
        deleteTag(&state, tag: tag)
        return .none

      case let .deleteButtonTapped(tag, name):
        print("deleteButtonTapped \(tag)")
        state.destination = .alert(.deleteTag(tag, name: name))
        return .none

      case .destination(.presented(.alert(let alertAction))):
        switch alertAction {
        case .confirmDeletion(let tag):
          deleteTag(&state, tag: tag)
        }
        return .none

      case .destination:
        return .none
  
      case .longPressGestureFired:
        print("editButtonTapped")
        return .none

      case .fetchTags:
        fetchTags(&state)
        return .none

      case .tagButtonTapped(let tag):
        state.activeTag = tag
        return .none

      @unknown default:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension TagFeature.Destination.State: Equatable {}

extension TagFeature {

  private func addTag(_ state: inout State) {
    do {
      _ = try TagModel.create(name: "New Tag")
      fetchTags(&state)
    } catch {
      print("duplicate tags are not allowed")
    }
  }

  private func fetchTags(_ state: inout State) {
    do {
      state.tags = .init(uniqueElements: try TagModel.tags())
      if state.activeTag == nil {
        state.activeTag = TagModel.Ubiquitous.all.uuid
        print("setting activeTag to \(TagModel.Ubiquitous.all.uuid)")
      }
    } catch {
      print("failed to get tags")
    }
  }

  private func deleteTag(_ state: inout State, tag: UUID) {
    do {
      if state.activeTag == tag {
        state.activeTag = TagModel.Ubiquitous.all.uuid
      }
      state.tags = state.tags.filter { $0.uuid != tag }
      try TagModel.delete(tag: tag)
    } catch {
      print("duplicate tags are not allowed")
    }
  }
}

extension AlertState where Action == TagFeature.Destination.Alert {
  static func deleteTag(_ tag: UUID, name: String) -> Self {
    .init {
      TextState("Delete?")
    } actions: {
      ButtonState(role: .destructive, action: .confirmDeletion(tag: tag)) {
        TextState("Yes")
      }
      ButtonState(role: .cancel) {
        TextState("No")
      }
    } message: {
      TextState("Are you sure you want to delete tag \"\(name)\"?")
    }
  }
}

public struct TagFeatureView: View {
  @Bindable private var store: StoreOf<TagFeature>

  init(store: StoreOf<TagFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack {
      List(store.tags, id: \.uuid) { tag in
        TagButtonView(name: tag.name, tag: tag.uuid) {
          store.send(.tagButtonTapped(tag: tag.uuid))
        }
        .onCustomLongPressGesture {
          store.send(.longPressGestureFired)
        }
        .swipeActions(allowsFullSwipe: false) {
          if !tag.ubiquitous {
            Button(role: .destructive) {
              store.send(.deleteButtonTapped(tag: tag.uuid, name: tag.name))
            } label: {
              Label("Delete", systemImage: "trash")
            }
          }
        }
        .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
      }
      HStack {
        Button {
          _ = store.send(.addButtonTapped)
        } label: {
          Image(systemName: "plus")
        }
      }
    }
    .onAppear() {
      _ = store.send(.fetchTags)
    }
  }
}

extension TagFeatureView {
  static var preview: some View {
    TagFeatureView(store: Store(initialState: .init()) { TagFeature() })
  }
}

#Preview {
  TagFeatureView.preview
}

