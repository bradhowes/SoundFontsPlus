import ComposableArchitecture
import SwiftUI

public struct FileImporterViewModifier: ViewModifier {
  @Bindable private var store: StoreOf<FileImporterFeature>

  public init(store: StoreOf<FileImporterFeature>) {
    self.store = store
  }

  public func body(content: Content) -> some View {
    content
      .fileImporter(
        isPresented: Binding(get: { store.showChooser }, set: { _ in }),
        allowedContentTypes: store.types
      ) { result in
        store.send(.filePicked(result))
      }
      .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
  }
}

extension View {

  public func fileImporterFeature(_ store: StoreOf<FileImporterFeature>) -> some View {
    modifier(FileImporterViewModifier(store: store))
  }
}
