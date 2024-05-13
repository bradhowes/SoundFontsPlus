// Copyright © 2024 Brad Howes. All rights reserved.

import Dependencies
import Foundation
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

import Models

struct SF2Picker: UIViewControllerRepresentable {
  @Binding var pickerResults: [URL]

  init(pickerResults: Binding<[URL]>) {
    self._pickerResults = pickerResults
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
  var parent: SF2Picker

  init(parent: SF2Picker) {
    self.parent = parent
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    print("SF2Picker urls: \(urls)")
    parent.pickerResults = urls
  }
}
