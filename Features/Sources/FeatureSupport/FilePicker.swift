// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import UniformTypeIdentifiers
import SwiftUI

/**
 Minimal feature that allows the user to pick one or more files/folders based on their type.

 ```
 @Reducer
 struct MyFeature {

   @Reducer
   enum Destination {
     case picker(FilePicker)
   ...
   }

   @ObservableState
   struct State: Equatable {
     @Presents public var destination: Destination.State?
     ...
   }

   var body: some ReducerOf<Self> {
     BindingReducer()
     Reduce { state, action in
       switch action {
         case .chooseFileTapped:
           state.destination = .picker(.init(types: [.folder], allowsMultipleSelection: false))
           return .none
         case .destination(.presented(.picker(.picked(let result)))):
           ...
       }
     }
     .ifLet(\.destination, action: \.destination)
   }
 }

 struct ParentView: View {
   var body: some View {
     content
       .filePicker($store.scope(state: \.destination?.picker, action: \.destination.picker))
 ```

 The action from the picker will be `.destination(.presented(.picker(.picked(let result))))` and the `result` value
 is of type `Result<[URL], Error>` just like the `.fileImporter` view modifier.
 */
@Reducer
public struct FilePicker {

  @ObservableState
  public struct State: Equatable {
    public let types: [UTType]
    public let allowsMultipleSelection: Bool

    public init(types: [UTType], allowsMultipleSelection: Bool) {
      self.types = types
      self.allowsMultipleSelection = allowsMultipleSelection
    }
  }

  @frozen
  public enum Action {
    case cancelled
    case picked(Result<[URL], Error>)
  }

  public init() {}

  public var body: some ReducerOf<Self> {}
}

extension View {

  public func filePicker(_ store: Binding<StoreOf<FilePicker>?>) -> some View {
    let state = store.wrappedValue
    return self.fileImporter(
      isPresented: Binding(
        get: { state != nil },
        set: { if $0 == false { state?.send(.cancelled) } }
      ),
      allowedContentTypes: state?.types ?? [],
      allowsMultipleSelection: state?.allowsMultipleSelection ?? false
    ) {
      state?.send(.picked($0))
    }
  }
}
