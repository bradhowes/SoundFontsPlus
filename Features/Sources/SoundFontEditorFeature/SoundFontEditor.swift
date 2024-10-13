import Foundation
import ComposableArchitecture
import Models


@Reducer
public struct SoundFontEditorFeature {

  public enum Field: Sendable {
    case displayName
  }

  @ObservableState
  public struct State: Equatable, Sendable {
    var soundFont: SoundFontModel
    var focus: Field?
    var hasFocus: Bool { focus == Field.displayName }

    public init(soundFont: SoundFontModel, focus: Field?) {
      self.soundFont = soundFont
      self.focus = focus
    }
  }

  public enum Action: Equatable, Sendable {
    case doneButtonTapped
    case clearButtonTapped
    case editTagsTapped
    case useOriginalNameTapped
    case useEmbeddedNameTapped
  }

  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .doneButtonTapped: return .none
      case .clearButtonTapped:
        
        return .none
      case .editTagsTapped: return .none
      case .useOriginalNameTapped: return .none
      case .useEmbeddedNameTapped: return .none
      }
    }
  }
}
