// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import FeatureSupport
import SwiftUI

public struct FileImporterViewModifier: ViewModifier {
  @Bindable private var store: StoreOf<FileImporter>

  public init(store: StoreOf<FileImporter>) {
    self.store = store
  }

  public func body(content: Content) -> some View {
    content
      .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
      .filePicker($store.scope(state: \.destination?.picker, action: \.destination.picker))
  }
}

extension View {

  public func fileImporterFeature(_ store: StoreOf<FileImporter>) -> some View {
    modifier(FileImporterViewModifier(store: store))
  }
}
