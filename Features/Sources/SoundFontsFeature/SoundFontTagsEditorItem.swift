import ComposableArchitecture
import Models
import SwiftUI
import SwiftUISupport
import Tagged

@Reducer
public struct SoundFontTagsEditorItem {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var id: Tag.ID { tag.id }
    let tag: Tag
    var tagState: Bool

    public init(tag: Tag, tagState: Bool) {
      self.tag = tag
      self.tagState = tagState
    }
  }

  public enum Action: Equatable {
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

public struct SoundFontTagsEditorItemView: View {
  @Bindable var store: StoreOf<SoundFontTagsEditorItem>

  public var body: some View {
    Toggle(store.tag.name, isOn: $store.tagState.sending(\.tagStateChanged))
      .disabled(store.tag.isUbiquitous)
      .checkedStyle()
  }
}
