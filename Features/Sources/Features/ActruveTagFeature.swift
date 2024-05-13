// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import ComposableArchitecture


@Reducer
struct ActiveTagFeature {

  @ObservableState
  struct State {
    var tags: [TagModel] = []
    var activeTag: TagModel.Id = TagModel.allId
  }

  enum Action {
    case tagTapped
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .tagTapped:
        
      }
    }
  }
}
