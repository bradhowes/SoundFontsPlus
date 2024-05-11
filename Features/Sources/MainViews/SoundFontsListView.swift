import UniformTypeIdentifiers
import SwiftData
import SwiftUI
import Models

/**
 Collection of SoundFont model buttons. Activating a button will show the presets associated with the SoundFont, but
 will not change the active preset.
 */
struct SoundFontsListView: View {
  @Environment(\.modelContext) var modelContext: ModelContext
  @Query(sort: \Tag.name) private var tags: [Tag]

  @Binding var selectedSoundFont: SoundFont?
  @Binding var activeSoundFont: SoundFont?
  @Binding var activePreset: Preset?

  @State private var soundFonts: [SoundFont] = []
  @State private var activeTag: Tag?
  @State private var activeTagName: String = "All"

  var body: some View {
    NavigationStack {
      List(soundFonts) { soundFont in
        SoundFontButtonView(soundFont: soundFont,
                            activeSoundFont: $activeSoundFont,
                            selectedSoundFont: $selectedSoundFont)
      }
      .navigationTitle("Fonts")
      .toolbar {
        pickerView
        Button(LocalizedStringKey("Add"), systemImage: "plus", action: addSoundFont)
      }
    }
    .onAppear(perform: setInitialContent)
  }
}

fileprivate extension SoundFontsListView {

  @MainActor
  func setInitialContent() {
    let tag = activeTag ?? modelContext.ubiquitousTag(.all)
    activeTag = tag
    soundFonts = modelContext.soundFonts(with: tag)

    if activePreset == nil {
      activeSoundFont = soundFonts.dropFirst().first
      selectedSoundFont = activeSoundFont
      activePreset = activeSoundFont?.orderedPresets.dropFirst(40).first
    }
  }

  @MainActor
  var pickerView: some View {
    Picker("Tag", selection: $activeTagName) {
      ForEach(tags) { tag in
        Text(tag.name)
          .tag(tag.name)
      }
    }.onChange(of: activeTagName) { oldValue, newValue in
      guard let tag = modelContext.findTag(name: newValue) else {
        fatalError("Unexpected nil value from fiindTag")
      }
      activeTag = tag
      withAnimation {
        soundFonts = modelContext.soundFonts(with: tag)
      }
    }
  }

  func addSoundFont() {

  }
}

//  @MainActor
//  func showSoundFontPicker(_ button: AnyObject) {
//    let types = ["com.braysoftware.sf2", "com.soundblaster.soundfont"].compactMap { UTType($0) }
//    let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: types,
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

//class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
//  @ObservedObject var fileViewModel: FileViewModel
//  @Binding var added: Bool
//  @Binding var iniCloud: Bool
//
//  init(projectVM: ProjectReportViewModel, added: Binding<Bool>, iniCloud: Binding<Bool> ) {
//    reportsViewModel = projectVM
//    self._added = added
//    self._iniCloud = iniCloud
//
//  }
//
//  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
//    guard let url = urls.first else {
//      return
//    }
//    reportsViewModel.addURLS(pickedURL: url, storeInIcloud: iniCloud)
//    added = true
//  }
//
//}

struct SoundFontsListView_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
  static var previews: some View {
    @State var selectedSoundFont: SoundFont?
    @State var activeSoundFont: SoundFont?
    @State var activePreset: Preset?

    SoundFontsListView(selectedSoundFont: $selectedSoundFont,
                       activeSoundFont: $activeSoundFont,
                       activePreset: $activePreset)
      .environment(\.modelContext, modelContainer.mainContext)
  }
}
