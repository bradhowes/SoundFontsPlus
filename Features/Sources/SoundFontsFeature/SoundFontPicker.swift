//// Copyright © 2024 Brad Howes. All rights reserved.
//
//import ComposableArchitecture
//import SwiftUI
//import SwiftUISupport
//import UIKit
//import UniformTypeIdentifiers
//
//@Reducer
//public struct SoundFontPicker {
//  @ObservableState
//  public struct State: Equatable {}
//
//  public enum Action {}
//
//  public var body: some ReducerOf<Self> {
//    Reduce<State, Action> { state, action in
//      switch action {
//      }
//    }
//  }
//}
//
//struct SoundFontPickerView: View {
//  let onCancel: () -> Void
//  let onSuccess: ([URL]) -> Void
//
//  init(onCancel: @escaping () -> Void, onSuccess: @escaping ([URL]) -> Void) {
//    self.onCancel = onCancel
//    self.onSuccess = onSuccess
//  }
//
//  public var body: some View {
//    SF2PickerView(onCancel: onCancel, onSuccess: onSuccess)
//  }
//}
//
//struct SF2PickerView: UIViewControllerRepresentable {
//  let onCancel: () -> Void
//  let onSuccess: ([URL]) -> Void
//  @Environment(\.presentationMode) private var presentationMode
//
//  init(onCancel: @escaping () -> Void, onSuccess: @escaping ([URL]) -> Void) {
//    self.onCancel = onCancel
//    self.onSuccess = onSuccess
//  }
//
//  func makeUIViewController(context: Context) -> some UIViewController {
//    let types = ["com.braysoftware.sf2", "com.soundblaster.soundfont"].compactMap { UTType($0) }
//    let controller = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
//    controller.allowsMultipleSelection = true
//    controller.shouldShowFileExtensions = true
//    controller.delegate = context.coordinator
//    return controller
//  }
//
//  func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
//
//  func makeCoordinator() -> Coordinator {
//    Coordinator(presentation: presentationMode, onCancel: onCancel, onSuccess: onSuccess)
//  }
//}
//
//class Coordinator: NSObject, UIDocumentPickerDelegate {
//  var presentation: Binding<PresentationMode>
//  let onCancel: () -> Void
//  let onSuccess: ([URL]) -> Void
//
//  init(presentation: Binding<PresentationMode>, onCancel: @escaping () -> Void, onSuccess: @escaping ([URL]) -> Void) {
//    self.presentation = presentation
//    self.onCancel = onCancel
//    self.onSuccess = onSuccess
//  }
//
//  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
//    self.onCancel()
//  }
//
//  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
//    self.onSuccess(urls)
//  }
//}
