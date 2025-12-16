import AudioUnit

extension AUParameter {

  /**
   Asynchronously observe the parameter for changes.

   - returns async stream of value changes
   */
  public func observe() -> AsyncStream<AUValue> {
    let (stream, continuation) = AsyncStream<AUValue>.makeStream(of: AUValue.self)
    let observer: AUParameterObserverToken = unsafe self.token(byAddingParameterObserver: { _, newValue in
      continuation.yield(newValue)
    })
    continuation.onTermination = { [weak self] _ in
      guard let self else { return }
      unsafe self.removeParameterObserver(observer)
    }
    return stream
  }
}

extension AUParameter: @retroactive @unchecked Sendable {}
extension AUParameterObserverToken: @retroactive @unchecked Sendable {}
