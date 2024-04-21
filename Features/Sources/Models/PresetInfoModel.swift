// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData


@Model
public final class PresetInfoModel {
  public let originalName: String
  public let bank: Int
  public let program: Int
  public var notes: String?

  public init(originalName: String, bank: Int, program: Int) {
    self.originalName = originalName
    self.bank = bank
    self.program = program
  }
}
