// Copyright © 2025 Brad Howes. All rights reserved.

public import ComposableArchitecture
public import SwiftUI

public struct FileImporterViewModifier: ViewModifier {
  @Bindable private var store: StoreOf<FileImporter>

  public init(store: StoreOf<FileImporter>) {
    self.store = store
  }

  public func body(content: Content) -> some View {
    content
      .fileImporter(
        isPresented: Binding(
          get: { store.showPicker },
          set: { _ in store.send(.fileImporterDismissed) }
        ),
        allowedContentTypes: store.types,
        allowsMultipleSelection: true
      ) { result in
        store.send(.filesPicked(result))
      }
      .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
  }
}

extension View {

  public func fileImporterFeature(_ store: StoreOf<FileImporter>) -> some View {
    modifier(FileImporterViewModifier(store: store))
  }
}
