// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox

// extension AUAudioUnit: @unchecked @retroactive Sendable {}

extension AUAudioUnit {

  /**
   Create an async stream of changes for a given key path, and for each change invoke the given closure. The code combines the
   establishment of the AsyncStream for the property value, and a `for await` loop that invokes the closure.

   - parameter keyPath: the key path for the property to observe.
   - parameter block: the closure to invoke when the property changes. Closure takes one ``Sendable`` argument, the new value of
   the property.
   */
  public func propertyValueStream<V: Sendable>(for keyPath: KeyPath<AUAudioUnit, V>, _ block: @escaping (V) async -> Void) async {
    let (stream, continuation) = AsyncStream<V>.makeStream()
    let observerToken = self.observe(keyPath, options: [.initial, .new]) { _, change in
      if let value = change.newValue {
        continuation.yield(value)
      }
    }
    let silenceWarning: (NSKeyValueObservation) -> Void = { _ in }
    silenceWarning(observerToken)
    for await value in stream { await block(value) }
  }

  /**
   Create an async stream of changes for a given key path, and for each change invoke the given closure. The code combines the
   establishment of the AsyncStream for the property value, and a `for wait` loop that invokes the closure.

   This variant is used when the value is not ``Sendable`` or if the value is not used by the block.

   - parameter keyPath: the key path for the property to observe.
   - parameter block: the closure to invoke when the property changes. The closure takes no arguments.
   */
  public func propertyValueStream<V>(for keyPath: KeyPath<AUAudioUnit, V>, _ block: @escaping () async -> Void) async {
    let (stream, continuation) = AsyncStream<Bool>.makeStream()
    let observerToken = self.observe(keyPath, options: [.initial, .new]) { _, _ in continuation.yield(false) }
    let silenceWarning: (NSKeyValueObservation) -> Void = { _ in }
    silenceWarning(observerToken)
    for await _ in stream { await block() }
  }
}
