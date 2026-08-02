// Copyright © 2025 Brad Howes. All rights reserved.

public import Combine
public import CoreMIDI
import Foundation
public import MorkAndMIDI

extension MIDI: @unchecked @retroactive Sendable {}

extension MIDI {

  public var activeConnectionsCountPublisher: AnyPublisher<Int, Never> {
    self.publisher(for: \.activeConnections)
      .buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
      .map({ $0.count })
      .removeDuplicates()
      .eraseToAnyPublisher()
  }

  public var activeConnectionsPublisher: AnyPublisher<Set<MIDIUniqueID>, Never> {
    self.publisher(for: \.activeConnections)
      .buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
      .removeDuplicates()
      .eraseToAnyPublisher()
  }
}
