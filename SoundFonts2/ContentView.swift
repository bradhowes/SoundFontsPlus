//
//  ContentView.swift
//  SoundFonts2
//
//  Created by Brad Howes on 04/02/2024.
//

import SwiftUI
import SwiftData
import Models

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var soundFonts: [SoundFontModel]

  var body: some View {
    NavigationSplitView {
      List {
        ForEach(soundFonts) { item in
          NavigationLink {
            Text("SoundFont \(item.name)")
          } label: {
            Text(item.name)
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
  ContentView()
    .modelContainer(for: SoundFontModel.self, inMemory: true)
}
