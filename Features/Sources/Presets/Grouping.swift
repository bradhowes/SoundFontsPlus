// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import IdentifiedCollections
import Models
import Sharing

/**
 Bundle collection of presets into one or more sections. Honors the `sortPresetsByName` setting as well as if searching is in
 effect.

 - parameter presets: the presets to bundle
 - parameter presetSource: the current preset source
 - parameter activePresetId: the current active preset ID
 - parameter searching: true if in search mode
 - returns: IdentifiedArray of PresetListSection.State entities referencing the presets
 */
internal func group(
  _ presets: [Preset],
  presetSource: PresetSource?,
  activePresetId: Preset.ID?,
  searching: Bool
) -> IdentifiedArrayOf<PresetsListSection.State> {
  let grouping = searching ? PresetsList.searchGroupingSize : PresetsList.groupingSize
  @Shared(.sortPresetsByName) var sortPresetsByName
  return if searching || !sortPresetsByName {
    groupByCount(
      presets,
      count: grouping,
      presetSource: presetSource,
      activePresetId: activePresetId,
      searching: searching
    )
  } else {
    groupByName(
      presets,
      presetSource: presetSource,
      activePresetId: activePresetId
    )
  }
}

private func emptySection(title: String) -> IdentifiedArrayOf<PresetsListSection.State> {
  .init(
    uniqueElements: [
      PresetsListSection.State(
        section: 0,
        sectionText: title,
        sectionIndex: "",
        presets: [],
        presetSource: nil,
        activePresetId: nil
      )
    ]
  )
}

private func groupByCount(
  _ presets: [Preset],
  count: Int,
  presetSource: PresetSource?,
  activePresetId: Preset.ID?,
  searching: Bool
) -> IdentifiedArrayOf<PresetsListSection.State> {
  if presets.isEmpty {
    emptySection(title: searching ? "Found 0" : "Presets")
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

private func groupingKey(for displayName: String) -> String {
  let first = displayName.uppercased().first ?? "#"
  return first.isLetter ? "\(first)" : "#"
}

private func groupByName(
  _ presets: [Preset],
  presetSource: PresetSource?,
  activePresetId: Preset.ID?,
) -> IdentifiedArrayOf<PresetsListSection.State> {
  if presets.isEmpty {
    emptySection(title: "Presets")
  } else {
    .init(
      uniqueElements: presets.grouped { groupingKey(for: $0.displayName) }.sorted(by: {$0.0 < $1.0}).enumerated().map {
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
