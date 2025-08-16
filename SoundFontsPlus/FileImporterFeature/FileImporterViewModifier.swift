//
//  FileImporterViewModifier.swift
//  SoundFontsPlus
//
//  Created by Brad Howes on 8/15/25.
//


public struct FileImporterViewModifier: ViewModifier {
  @Bindable private var store: StoreOf<FileImporterFeature>

  public init(store: StoreOf<FileImporterFeature>) {
    self.store = store
  }

  public func body(content: Content) -> some View {
    content
      .fileImporter(
        isPresented: Binding(get: { store.startImporting }, set: { _ in }),
        allowedContentTypes: store.types
      ) { result in
        store.send(.finishedImportingFile(result))
      }
      .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
  }
}

extension View {

  public func fileImporterFeature(_ store: StoreOf<FileImporterFeature>) -> some View {
    modifier(FileImporterViewModifier(store: store))
  }
}

