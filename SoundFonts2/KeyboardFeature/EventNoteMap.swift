// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import SwiftUI

/**
 Mapping of SpatialEventGesture events to MIDI notes that are held down by one or more events. There could be more
 than one event triggering the same note (rare), so we map event IDs to Note values and for each Note that is
 active, we track the number of events mapped to it.
 */
public struct EventNoteMap: Equatable {
  public typealias Event = SpatialEventGesture.Value.Element

  private var events = [Event.ID: Note]()
  private var notes = [Note: Int]()

  public struct AssignResult {
    let previous: Note?
    let firstTime: Bool
  }
  /**
   Assign a spatial event to a note, updating note state for the event.

   - parameter event: the spatial event to track
   - parameter note: the `Note` assigned to the event
   - returns: 2-tuple containing a `Note` that was released by the activity of this event,
   and a bool if first assignment for the `Note`.
   */
  public mutating func assign(event: Event, note: Note, fixedKeys: Bool) -> AssignResult {
    var previousReleased: Note? = nil
    if let previous = events[event.id] {
      // Same note being activated?
      guard previous != note && fixedKeys else { return .init(previous: note, firstTime: true) }
      // Previous note being released?
      if reduceNoteCount(note: previous) {
        previousReleased = previous
      }
    }

    // Update accounting
    events[event.id] = note
    let count = notes[note, default: 0]
    notes[note] = count + 1
    return .init(previous: previousReleased, firstTime: count == 0)
  }

  /**
   Remove all assignments.
   */
  public mutating func releaseAll() {
    notes.removeAll()
    events.removeAll()
  }

  /**
   Release any key that is attached to the given spatial event.

   - parameter event: the event to remove
   - returns: `Note` that was released (may be nil)
   */
  public mutating func release(event: Event) -> Note? {
    // Note associated with event?
    guard let note = events[event.id] else { return nil }
    events.removeValue(forKey: event.id)
    return reduceNoteCount(note: note) ? note : nil
  }

  /**
   Determine if a given `Note` is active.

   - parameter note: the note the check
   - returns: `true` if active
   */
  public func isOn(_ note: Note) -> Bool {
    notes[note, default: 0] > 0
  }

  /**
   Reduce the counter for a `Note` returning `true` if the count goes to zero.

   - parameter note: the `Note` to update
   - returns: `true` if note is no longer active
   */
  private mutating func reduceNoteCount(note: Note) -> Bool {
    guard let count = notes[note] else { return false }
    if count > 1 {
      notes[note] = count - 1
    } else {
      notes.removeValue(forKey: note)
    }
    return count == 1
  }
}
