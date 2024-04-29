// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import SwiftData

public typealias PresetInfo = SchemaV1.PresetInfo

extension SchemaV1 {
  
  @Model
  public final class PresetInfo {
    public var originalName: String = ""
    public var bank: Int = -1
    public var program: Int = -1
    public var notes: String?

    public init(originalName: String, bank: Int, program: Int) {
      self.originalName = originalName
      self.bank = bank
      self.program = program
    }
  }
}

extension ModelContext {

  func createPresetInfo(originalName: String, bank: Int, program: Int) throws -> PresetInfo {
    let entity = PresetInfo(originalName: originalName, bank: bank, program: program)
    self.insert(entity)
    try self.save()
    return entity
  }

  func presetInfos(_ fetchDescriptor: FetchDescriptor<PresetInfo>? = nil) throws -> [PresetInfo] {
    return try self.fetch(fetchDescriptor ?? FetchDescriptor<PresetInfo>())
  }
}
