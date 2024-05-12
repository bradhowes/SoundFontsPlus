import Foundation
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

import Models

struct SF2Picker: UIViewControllerRepresentable {
  @Environment(\.modelContext) var modelContext
  @Binding var showingPicker: Bool
  let copyFilesWhenAdding = true

  func makeUIViewController(context: Context) -> some UIViewController {
    let types = ["com.braysoftware.sf2", "com.soundblaster.soundfont"].compactMap { UTType($0) }
    let controller = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: copyFilesWhenAdding)
    controller.allowsMultipleSelection = true
    controller.shouldShowFileExtensions = true
    controller.delegate = context.coordinator
    return controller
  }

  func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {

  }

  func makeCoordinator() -> Coordinator {
    Coordinator(modelContext: modelContext, showingPicker: $showingPicker, copyFilesWhenAdding: copyFilesWhenAdding)
  }
}

class Coordinator: NSObject, UIDocumentPickerDelegate {

  let modelContext: ModelContext
  @Binding var showingPicker: Bool
  let copyFilesWhenAdding: Bool

  init(modelContext: ModelContext, showingPicker: Binding<Bool>, copyFilesWhenAdding: Bool) {
    self.modelContext = modelContext
    self._showingPicker = showingPicker
    self.copyFilesWhenAdding = copyFilesWhenAdding
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    showingPicker = false

    var ok = [String]()
    var failures = [SF2LoadFailure]()

    for url in urls {
      let fileName = url.lastPathComponent
      let displayName = String(fileName[fileName.startIndex..<(fileName.lastIndex(of: ".") ?? fileName.endIndex)])

      do {
        let destination = FileManager.default.sharedDocumentsDirectory.appendingPathComponent(fileName)
        try copyToAppFolder(source: url, destination: destination)
      } catch {
        failures.append(SF2LoadFailure.unableToCreateFile(fileName))
        continue
      }

      do {
        _ = try modelContext.addSoundFont(name: displayName, kind: .installed(file: url))
      } catch {
        failures.append(SF2LoadFailure.swiftDataFailure(fileName, error: error.localizedDescription))
        continue
      }

      ok.append(fileName)
    }
  }
}

private func copyToAppFolder(source: URL, destination: URL) throws {
  print("SF2 source: \(source.absoluteString)")
  print("SF2 destination: \(destination.absoluteString)")
  let secured = source.startAccessingSecurityScopedResource()
  defer { if secured { source.stopAccessingSecurityScopedResource() } }
  try FileManager.default.copyItem(at: source, to: destination)
}


//    guard !urls.isEmpty else { return }
//
//    var ok = [String]()
//    var failures = [SoundFontFileLoadFailure]()
//
//    for each in urls {
//      switch soundFonts.add(url: each) {
//      case .success(let (_, soundFont)):
//        toActivate = soundFont.makeSoundFontAndPreset(at: 0)
//        ok.append(soundFont.fileURL.lastPathComponent)
//      case .failure(let failure):
//        failures.append(failure)
//      }
//    }
//
//    // Activate the first preset of the last valid sound font that was added
//    if let soundFontAndPreset = toActivate {
//      self.fontsTableViewController.activate(soundFontAndPreset)
//    }
//
//    if urls.count > 1 || !failures.isEmpty {
//      let message = Formatters.makeAddSoundFontBody(ok: ok, failures: failures, total: urls.count)
//      let alert = UIAlertController(title: Formatters.strings.addSoundFontsStatusTitle, message: message,
//                                    preferredStyle: .alert)
//      alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
//      self.present(alert, animated: true, completion: nil)
//    }

//
//@MainActor
//func showSoundFontPicker(_ button: AnyObject) {
//  let types = ["com.braysoftware.sf2", "com.soundblaster.soundfont"].compactMap { UTType($0) }
//  let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: types,
//                                                        asCopy: true)
//    // documentPicker.delegate = self
//    documentPicker.modalPresentationStyle = .automatic
//    documentPicker.allowsMultipleSelection = true
//    present(documentPicker, animated: true)
//  }
//
//  func addSoundFonts(urls: [URL]) {
//    os_log(.info, log: log, "addSoundFonts - BEGIN %{public}s", String.pointer(self))
//    guard !urls.isEmpty else { return }
//
//    var ok = [String]()
//    var failures = [SoundFontFileLoadFailure]()
//    var toActivate: SoundFontAndPreset?
//
//    for each in urls {
//      os_log(.debug, log: log, "processing %{public}s", each.path)
//      switch soundFonts.add(url: each) {
//      case .success(let (_, soundFont)):
//        toActivate = soundFont.makeSoundFontAndPreset(at: 0)
//        ok.append(soundFont.fileURL.lastPathComponent)
//      case .failure(let failure):
//        failures.append(failure)
//      }
//    }
//
//    // Activate the first preset of the last valid sound font that was added
//    if let soundFontAndPreset = toActivate {
//      self.fontsTableViewController.activate(soundFontAndPreset)
//    }
//
//    if urls.count > 1 || !failures.isEmpty {
//      let message = Formatters.makeAddSoundFontBody(ok: ok, failures: failures, total: urls.count)
//      let alert = UIAlertController(title: Formatters.strings.addSoundFontsStatusTitle, message: message,
//                                    preferredStyle: .alert)
//      alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
//      self.present(alert, animated: true, completion: nil)
//    }
//  }
//
//}
//
