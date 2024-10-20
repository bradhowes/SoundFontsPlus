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
    var soundFontTag: Bool

    public init(tag: TagModel, soundFontTag: Bool) {
      self.tag = tag
      self.soundFontTag = soundFontTag
    }
  }

  public enum Action {
    case soundFontTagChanged(Bool)
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .soundFontTagChanged(let value):
        state.soundFontTag = value
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
    Toggle(store.tag.name, isOn: $store.soundFontTag.sending(\.soundFontTagChanged))
      .disabled(!store.tag.isUserDefined)
      .toggleStyle(CheckToggleStyle())
  }
}
