// Copyright © 2025 Brad Howes. All rights reserved.

import Algorithms
import BaseSupport
import Foundation
import IdentifiedCollections
import Models
import Sharing

/**
 Bundle collection of presets into one or more sections. Honors the `sortPresetsByName` setting as well as if searching is in
 effect.

 - parameter presets: the presets to bundle. The ordering should be based on the `sortPresetsByName` and `favoritesOnTop` settings.
 - parameter searching: true if in search mode
 - returns: IdentifiedArray of PresetListSection.State entities referencing the presets
 */
internal func group(
  _ presets: [Preset],
  searching: Bool
) -> IdentifiedArrayOf<PresetsListSection.State> {
  let grouping = searching ? PresetsList.searchGroupingSize : PresetsList.groupingSize
  @Shared(.sortPresetsByName) var sortPresetsByName
  return if searching || !sortPresetsByName {
    groupByCount(
      presets,
      count: grouping,
      searching: searching
    )
  } else {
    groupByName(
      presets
    )
  }
}

private func emptySection(title: String) -> IdentifiedArrayOf<PresetsListSection.State> {
  .init(
    uniqueElements: [
      .init(
        id: 0,
        title: title,
        indexKey: "",
        presets: []
      )
    ]
  )
}

private func groupByCount(
  _ presets: [Preset],
  count: Int,
  searching: Bool
) -> IdentifiedArrayOf<PresetsListSection.State> {
  if presets.isEmpty {
    emptySection(title: searching ? "Found 0" : "Presets")
  } else {
    .init(
      uniqueElements: presets.indices.chunks(ofCount: count).map {
        .init(
          id: $0.lowerBound / count,
          title: {
            if searching {
              "Found \(presets.count)"
            } else if $0.lowerBound == 0 {
              "Presets"
            } else {
              "\($0.lowerBound)"
            }
          }($0),
          indexKey: numericSectionIndex(from: $0.lowerBound / count),
          presets: presets[$0]
        )
      }
    )
  }
}

private func numericSectionIndex(from section: Int) -> String {
  "\(section * PresetsList.groupingSize)"
}

private let favoriteSectionText = "!"
private let numericSectionText = "#"

private func sectionGroupingKey(for displayName: String, kind: Preset.Kind) -> String {
  @Shared(.favoritesOnTop) var favoritesOnTop
  if kind == .favorite, favoritesOnTop {
    return favoriteSectionText
  } else if let first = displayName.trimmedOfWhitespaces.uppercased().first, first.isLetter {
    return "\(first)"
  } else {
    return numericSectionText
  }
}

private func groupByName(
  _ presets: [Preset],
) -> IdentifiedArrayOf<PresetsListSection.State> {
  if presets.isEmpty {
    emptySection(title: "Presets")
  } else {
    .init(
      uniqueElements: presets
        .grouped { preset in sectionGroupingKey(for: preset.displayName, kind: preset.kind) }
        .sorted(by: {$0.0 < $1.0})
        .enumerated()
        .map { (index, group) in
            .init(
              id: index,
              title: group.0,
              indexKey: group.0,
              presets: group.1[...]
            )
        }
    )
  }
}
