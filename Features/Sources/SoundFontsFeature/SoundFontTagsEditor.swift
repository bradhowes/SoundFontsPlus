import ComposableArchitecture
import Models
import SwiftUI
import SwiftUINavigation

@Reducer
public struct SoundFontTagsEditor {

  @ObservableState
  public struct State: Equatable {
    let soundFont: SoundFontModel
    var rows: IdentifiedArrayOf<SoundFontTagsEditorItem.State>

    public init(soundFont: SoundFontModel) {
      self.soundFont = soundFont
      do {
        let tags = try TagModel.tags()
        self.rows = .init(uniqueElements: tags.map{ .init(tag: $0, soundFontTag: soundFont.tags.contains($0)) })
      } catch {
        print("Error fetching tags: \(error)")
        self.rows = []
      }
    }
  }

  public enum Action {
    case delegate(Delegate)
    case dismissButtonTapped
    case rows(IdentifiedActionOf<SoundFontTagsEditorItem>)
  }

  @CasePathable
  public enum Delegate {
    case updateTags
  }

  @Dependency(\.dismiss) var dismiss

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {

      case .delegate:
        return .none

      case .dismissButtonTapped:
        let dismiss = dismiss
        return .run { _ in await dismiss() }

      case let .rows(.element(id: key, action: .soundFontTagChanged(change))):
        updateTags(&state, key: key, isMember: change)
        return .send(.delegate(.updateTags))

      case .rows:
        return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      SoundFontTagsEditorItem()
    }
  }
}

extension SoundFontTagsEditor {

  private func updateTags(_ state: inout State, key: TagModel.Key, isMember: Bool) {
    if let index = state.rows.index(id: key) {
      let tag = state.rows[index].tag
      SoundFontModel.proposeTagMembershipChange(soundFont: state.soundFont, tag: tag, isMember: isMember)
    }
  }
}

public struct SoundFontTagsEditorView: View {
  private var store: StoreOf<SoundFontTagsEditor>

  public init(store: StoreOf<SoundFontTagsEditor>) {
    self.store = store
  }

  public var body: some View {
    List {
      ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
        SoundFontTagsEditorItemView(store: rowStore)
      }
    }
    .navigationTitle("Tagging")
  }
}
