// Copyright © 2025 Brad Howes. All rights reserved.

import OSLog
import Sharing

private class BundleTag {}

extension Logger {

  public init(category: String, loggingSubsystemValue: String? = nil) {
    @Shared(.loggingSubsystem) var subsystem
    if let loggingSubsystemValue {
      $subsystem.withLock { $0 = loggingSubsystemValue }
    }
    self.init(subsystem: subsystem, category: category)
  }
}

extension Logger {

//  public func measure<T>(_ label: String, _ block: () throws -> T) throws -> T {
//    let start = Date()
//    defer { self.info("\(label, privacy: .public) END - duration: \(Date().timeIntervalSince(start))s") }
//    self.info("\(label, privacy: .public) BEGIN")
//    return try block()
//  }
//
//  public func measure<T>(_ label: String, _ block: () -> T) -> T {
//    let start = Date()
//    defer { self.info("\(label, privacy: .public) END - duration: \(Date().timeIntervalSince(start))s") }
//    self.info("\(label, privacy: .public) BEGIN")
//    return block()
//  }
//
//  public func measure(_ label: String, _ block: () throws -> Void) throws {
//    let start = Date()
//    defer { self.info("\(label, privacy: .public) END - duration: \(Date().timeIntervalSince(start))s") }
//    self.info("\(label, privacy: .public) BEGIN")
//    try block()
//  }
//
//  public func measure(_ label: String, _ block: () -> Void) {
//    let start = Date()
//    defer { self.info("\(label, privacy: .public) END - duration: \(Date().timeIntervalSince(start))s") }
//    self.info("\(label, privacy: .public) BEGIN")
//    block()
//  }
//
//  public func action<T>(_ label: String, _ action: T) where T: CustomStringConvertible {
//    self.debug("\(label) action: \(action), privacy: .public)")
//  }

  public func action<T>(_ label: String, _ action: T) {
    self.debug("\(label, privacy: .public) action: \(String(describing: action), privacy: .public)")
  }
}

private let isRunningForPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
