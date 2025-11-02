import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Foundation
import SnapshotTesting
import SwiftUI
import Testing
import TestSupport

@testable import FeatureSupport

@Suite(
  .snapshots(record: .failed)
)
@MainActor
struct PrsetNameViewTests {
  let viewSize = CGSize(width: 200, height: 200)

  @Test
  func defaultRendering() throws {
    @Shared(.favoriteSymbolName) var symbolName = "star.circle.fill"
    @Shared(.starFavoriteNames) var starFavoriteNames = true

    let view = VStack {
      PresetNameView(preset: nil)
      PresetNameView(
        preset: .init(
          id: 1,
          index: 1,
          bank: 0,
          program: 1,
          originalName: "Name",
          soundFontId: 1,
          displayName: "Preset",
          notes: "",
          kind: .preset
        )
      )
      PresetNameView(
        preset: .init(
          id: 1,
          index: 1,
          bank: 0,
          program: 1,
          originalName: "Name",
          soundFontId: 1,
          displayName: "Favorite",
          notes: "",
          kind: .favorite
        )
      )
    }
    try TestSupport.assertSnapshot(matching: view, size: viewSize)
  }

  @Test
  func noStarRendering() throws {
    @Shared(.favoriteSymbolName) var symbolName = "star.circle.fill"
    @Shared(.starFavoriteNames) var starFavoriteNames = false

    let view = VStack {
      PresetNameView(preset: nil)
      PresetNameView(
        preset: .init(
          id: 1,
          index: 1,
          bank: 0,
          program: 1,
          originalName: "Name",
          soundFontId: 1,
          displayName: "Preset",
          notes: "",
          kind: .preset
        )
      )
      PresetNameView(
        preset: .init(
          id: 1,
          index: 1,
          bank: 0,
          program: 1,
          originalName: "Name",
          soundFontId: 1,
          displayName: "Favorite",
          notes: "",
          kind: .favorite
        )
      )
    }
    try TestSupport.assertSnapshot(matching: view, size: viewSize)
  }

  @Test
  func emptySymbolRendering() throws {
    @Shared(.favoriteSymbolName) var symbolName = ""
    @Shared(.starFavoriteNames) var starFavoriteNames = true

    let view = VStack {
      PresetNameView(preset: nil)
      PresetNameView(
        preset: .init(
          id: 1,
          index: 1,
          bank: 0,
          program: 1,
          originalName: "Name",
          soundFontId: 1,
          displayName: "Preset",
          notes: "",
          kind: .preset
        )
      )
      PresetNameView(
        preset: .init(
          id: 1,
          index: 1,
          bank: 0,
          program: 1,
          originalName: "Name",
          soundFontId: 1,
          displayName: "Favorite",
          notes: "",
          kind: .favorite
        )
      )
    }
    try TestSupport.assertSnapshot(matching: view, size: viewSize)
  }
}
