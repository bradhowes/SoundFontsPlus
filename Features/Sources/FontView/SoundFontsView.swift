import Models
import SF2Files
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
  let container = VersionedModelContainer.make(isTemporary: true)
  return SoundFontsView()
    .modelContainer(container)
}
