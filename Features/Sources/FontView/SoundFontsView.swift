import Models
import SwiftData
import SwiftUI

struct SoundFontsView: View {
  @Query(sort: \SoundFont.displayName) var soundFonts: [SoundFont]

  var body: some View {
    NavigationSplitView {
      List {
        ForEach(soundFonts) { item in
          NavigationLink {
            PresetsView(soundFont: item)
          } label: {
            Text(item.displayName)
          }
        }
        .onDelete(perform: deleteItems)
      }
#if os(macOS)
      .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
      .toolbar {
#if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
          EditButton()
        }
#endif
        ToolbarItem {
          Button(action: addItem) {
            Label("Add Item", systemImage: "plus")
          }
        }
      }
    } detail: {
      Text("Select an item")
    }
  }

  private func addItem() {
    withAnimation {
      //            let newItem = Item(timestamp: Date())
      //            modelContext.insert(newItem)
    }
  }

  private func deleteItems(offsets: IndexSet) {
    withAnimation {
      //            for index in offsets {
      //                modelContext.delete(items[index])
      //            }
    }
  }
}

#Preview {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  let container = try! ModelContainer(for: SoundFont.self, configurations: config)
  do {
    _ = try container.mainContext.createSoundFont(resourceTag: .freeFont)
    _ = try container.mainContext.createSoundFont(resourceTag: .museScore)
    _ = try container.mainContext.createSoundFont(resourceTag: .rolandNicePiano)
  } catch {

  }

  return SoundFontsView()
    .modelContainer(container)
}
