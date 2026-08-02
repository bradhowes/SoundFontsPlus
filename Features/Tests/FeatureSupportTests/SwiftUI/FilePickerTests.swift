import ComposableArchitecture
import DependenciesTestSupport
import SwiftUI
import Testing
import TestSupport
import UniformTypeIdentifiers

@testable import FeatureSupport

@Reducer
struct TestFeature {

  @Reducer
  enum Destination {
    case picker(FilePicker)
  }

  @ObservableState
  struct State: Equatable {
    @Presents var destination: Destination.State?
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case chooseFileTapped
    case destination(PresentationAction<Destination.Action>)
  }

  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .chooseFileTapped:
        state.destination = .picker(.init(types: [.folder], allowsMultipleSelection: false))
        return .none

      default:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension TestFeature.Destination.State: Equatable {}

@Suite
@MainActor
struct FilePickerTests {

  @Test
  func construction() throws {
    let state = FilePicker.State(types: [.folder], allowsMultipleSelection: false)
    #expect(state.types == [.folder])
    #expect(state.allowsMultipleSelection == false)
  }

  @Test
  func filePickerCancel() async throws {
    let store = TestStoreOf<TestFeature>(initialState: TestFeature.State()) { TestFeature() }
    await store.send(\.chooseFileTapped) {
      $0.destination = .picker(.init(types: [.folder], allowsMultipleSelection: false))
    }
    await store.send(\.destination, .dismiss) {
      $0.destination = nil
    }
  }

  @Test
  func filePickerPicked() async throws {
    let store = TestStoreOf<TestFeature>(initialState: TestFeature.State()) { TestFeature() }
    await store.send(\.chooseFileTapped) {
      $0.destination = .picker(.init(types: [.folder], allowsMultipleSelection: false))
    }
    let result: Result<[URL], any Error> = .success([])
    await store.send(\.destination.picker, .picked(result))
  }
}
