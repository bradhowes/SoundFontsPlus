//// Copyright © 2025 Brad Howes. All rights reserved.
//
//import Foundation
//import SharingGRDB
//import Tagged
//
//@Selection
//public struct PresetInfo: Equatable, Identifiable, Sendable {
//  public let id: Preset.ID
//  public let displayName: String
//  public let bank: Int
//  public let program: Int
//
//  public init(id: Preset.ID, displayName: String, bank: Int, program: Int) {
//    self.id = id
//    self.displayName = displayName
//    self.bank = bank
//    self.program = program
//  }
//
//  public init(preset: Preset) {
//    self.init(
//      id: preset.id,
//      displayName: preset.displayName,
//      bank: preset.bank,
//      program: preset.program
//    )
//  }
//}
