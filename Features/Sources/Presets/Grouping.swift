// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import IdentifiedCollections
import Models
import Sharing

public func group(
  _ presets: [Preset],
  presetSource: PresetSource?,
  activePresetId: Preset.ID?,
  searching: Bool
) -> IdentifiedArrayOf<PresetsListSection.State> {

  let grouping = searching ? PresetsList.searchGroupingSize : PresetsList.groupingSize

  @Shared(.sortPresetsByName) var sortPresetsByName
  if searching || !sortPresetsByName {
    return groupByCount(
      presets,
      count: grouping,
      presetSource: presetSource,
      activePresetId: activePresetId,
      searching: searching
    )
  } else {
    return groupByName(
      presets,
      presetSource: presetSource,
      activePresetId: activePresetId
    )
  }
}

public func groupByCount(
  _ presets: [Preset],
  count: Int,
  presetSource: PresetSource?,
  activePresetId: Preset.ID?,
  searching: Bool
) -> IdentifiedArrayOf<PresetsListSection.State> {
  @Shared(.favoriteSymbolName) var symbolName
  @Shared(.starFavoriteNames) var starFavoriteNames

  return if presets.isEmpty {
    .init(
      uniqueElements: [
        PresetsListSection.State(
          section: 0,
          sectionText: searching ? "Found 0" : "Presets",
          sectionIndex: "",
          presets: [],
          presetSource: presetSource,
          activePresetId: activePresetId
        )
      ]
    )
  } else {
    .init(
      uniqueElements: presets.indices.chunks(ofCount: count).map {
        PresetsListSection.State(
          section: $0.lowerBound / count,
          sectionText: {
            if searching {
              "Found \(presets.count)"
            } else if $0.lowerBound == 0 {
              "Presets"
            } else {
              "\($0.lowerBound)"
            }
          }($0),
          sectionIndex: numericSectionIndex(from: $0.lowerBound / count),
          presets: presets[$0],
          presetSource: presetSource,
          activePresetId: activePresetId
        )
      }
    )
  }
}

private func numericSectionIndex(from section: Int) -> String {
  "\(section * PresetsList.groupingSize)"
}

private func alphabeticSectionIndex(from section: Int, sectionText: String) -> String {
  // swiftlint:disable:next force_unwrapping
  section == 0 ? "#" : "\(sectionText.first!)"
}

public func groupByName(
  _ presets: [Preset],
  presetSource: PresetSource?,
  activePresetId: Preset.ID?,
) -> IdentifiedArrayOf<PresetsListSection.State> {
  @Shared(.favoriteSymbolName) var symbolName
  @Shared(.starFavoriteNames) var starFavoriteNames

  func groupingKey(for displayName: String) -> String {
    let first = displayName.uppercased().first ?? "#"
    return first.isLetter ? "\(first)" : "#"
  }

  if presets.isEmpty {
    return .init(
      uniqueElements: [
        PresetsListSection.State(
          section: 0,
          sectionText: "Presets",
          sectionIndex: "",
          presets: [],
          presetSource: presetSource,
          activePresetId: activePresetId
        )
      ]
    )
  } else {
    let dict = presets.grouped { groupingKey(for: $0.displayName) }
    return .init(
      uniqueElements: dict.sorted(by: {$0.0 < $1.0}).enumerated().map {
        PresetsListSection.State(
          section: $0.0,
          sectionText: "\($0.1.0)",
          sectionIndex: alphabeticSectionIndex(from: $0.0, sectionText: "\($0.1.0)"),
          presets: $0.1.1[...],
          presetSource: presetSource,
          activePresetId: activePresetId
        )
      }
    )
  }
}
