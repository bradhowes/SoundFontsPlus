import ComposableArchitecture
import Models
import SwiftUI
import SwiftUISupport
import Tagged

@Reducer
public struct SoundFontTagsEditorItem {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var id: TagModel.Key { tag.key }
    let tag: TagModel
    var tagState: Bool

    public init(tag: TagModel, tagState: Bool) {
      self.tag = tag
      self.tagState = tagState
    }
  }

  public enum Action {
    case tagStateChanged(Bool)
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .tagStateChanged(let value):
        state.tagState = value
        return .none
      }
    }
  }
}

struct SoundFontTagsEditorItemView: View {
  @Bindable private var store: StoreOf<SoundFontTagsEditorItem>

  public init(store: StoreOf<SoundFontTagsEditorItem>) {
    self.store = store
  }

  public var body: some View {
    Toggle(store.tag.name, isOn: $store.tagState.sending(\.tagStateChanged))
      .disabled(store.tag.isUbiquitous)
      .toggleStyle(CheckToggleStyle())
  }
}
