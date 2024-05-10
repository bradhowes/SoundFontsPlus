//import Models
//import SF2Files
//import SwiftData
//import SwiftUI
//
//struct SoundFontsView: View {
//  @Query private var soundFonts: [SoundFont]
//
//  init(tag: Tag) {
//    let name = tag.name
//    let query = Query(filter: #Predicate { $0.tags.contains { $0.name == name } }, sort: \SoundFont.displayName)
//    self._soundFonts = query
//  }
//
//  var body: some View {
//    List(soundFonts) { soundFont in
//      soundFontButton(soundFont)
//    }
//  }
//}
//
//#Preview {
//  let container = VersionedModelContainer.make(isTemporary: true)
//  let mainContext = container.mainContext
//  let tag = try! mainContext.ubiquitousTag(.all)
//  return SoundFontsView(tag: tag)
//    .modelContainer(container)
//}
