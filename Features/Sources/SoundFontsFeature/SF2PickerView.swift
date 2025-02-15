// Copyright © 2024 Brad Howes. All rights reserved.

import Dependencies
import Foundation
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

import Models

struct SF2PickerView: UIViewControllerRepresentable {
  let onCancel: () -> Void
  let onOpen: ([URL]) -> Void

  init(onCancel: @escaping () -> Void, onOpen: @escaping ([URL]) -> Void) {
    self.onCancel = onCancel
    self.onOpen = onOpen
  }

  func makeUIViewController(context: Context) -> some UIViewController {
    let types = ["com.braysoftware.sf2", "com.soundblaster.soundfont"].compactMap { UTType($0) }
    let controller = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
    controller.allowsMultipleSelection = true
    controller.shouldShowFileExtensions = true
    controller.delegate = context.coordinator
    return controller
  }

  func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }
}

class Coordinator: NSObject, UIDocumentPickerDelegate {
  var parent: SF2PickerView

  init(parent: SF2PickerView) {
    self.parent = parent
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    parent.onCancel()
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    parent.onOpen(urls)
  }
}
