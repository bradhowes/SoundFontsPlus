// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation

extension AVAudioUnitReverbPreset: @retroactive Identifiable {
  public var id: Int { rawValue }

  // NOTE: order here is *not* the same as the numeric ordering of the enum integer values.
  // This ordering is personal and seems sane if arbitrary
  public static let allCases: [AVAudioUnitReverbPreset] = [
    .smallRoom, // 0
    .mediumRoom, // 1
    .largeRoom, // 2
    .largeRoom2, // 9
    .mediumHall, // 3
    .mediumHall2, // 10
    .mediumHall3, // 11
    .largeHall, // 4
    .largeHall2, // 12
    .mediumChamber, // 6
    .largeChamber, // 7
    .cathedral, // 8
    .plate // 5
  ]

  public static let range: ClosedRange<Int> = 0...(allCases.count - 1)

  public var name: String {
    switch self {
    case .smallRoom: return "Room 1"
    case .mediumRoom: return "Room 2"
    case .largeRoom: return "Room 3"
    case .largeRoom2: return "Room 4"
    case .mediumHall: return "Hall 1"
    case .mediumHall2: return "Hall 2"
    case .mediumHall3: return "Hall 3"
    case .largeHall: return "Hall 4"
    case .largeHall2: return "Hall 5"
    case .mediumChamber: return "Chamber 1"
    case .largeChamber: return "Chamber 2"
    case .cathedral: return "Cathedral"
    case .plate: return "Plate"
    @unknown default:
      fatalError()
    }
  }
}
