# SoundFonts2

SwiftUI version of my [SoundFonts](https://github.com/bradhowes/SoundFonts) app.

Main dependencies:

* [Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture) -- opinionated approach to
  structuring an iOS app as composable features that provide for well-structured and understandable event flows and data
  transformation that drive the SwiftUI views.
* [sharing-grdb](https://github.com/pointfreeco/sharing-grdb) -- provides a shared-data capability by combining Point-Free's
  [Sharing](https://github.com/pointfreeco/swift-sharing) and 
  [StructuredQueries](https://github.com/pointfreeco/swift-structured-queries) libraries with the robust
  [GRDB](https://github.com/groue/GRDB.swift) toolkit for SQLite
* [AUv3Controls](https://github.com/bradhowes/AUv3Controls) -- custom SwiftUI controls (a circular knob and a toggle)
  that supports easy integration with AUv3 AUParameter entities.
* [SF2Lib](https://github.com/bradhowes/SF2Lib) -- an audio synthesizer in Objective-C++ that reads sound font (SF2)
  files. It is used here to read the files and provide the presets info and meta data that goes into the SQLite tables.

![demo](media/demo.gif)

# Status

At present this is just the user interface and SQLite backing store. It has served as a playground while I've been
learning about TCA and SQLite.

Nearly all app data resides in SQLite database, though there are some `UserDefaults` settings and a file-based `@Shared`
struct that holds:

* selected SoundFont ID
* active SoundFont ID
* active preset ID
* active tag ID

When any of these values change, the various views update as would be expected:

* active tag ID changes --> list of SoundFont entries adapts
* selected SoundFont ID changes --> list of preset entries updates
* active preset ID changes:
    * audio effects update if preset has custom config
    * keyboard shifts to a configured value
    * SF2 engine loads preset (TBD)
    * MIDI mapping updated if preset has custom config (TBD)

# History

The original SoundFonts app is written in Swift and UIKit. The data store is a disk file and a collection of
UserDefaults keys/value pairs. This repo is my attempt to replace the original with SwiftUI and SQLite.

Originally it was based on SwiftData, but I encountered too many issues and hurdles. Another repo of mine
[SwiftDataTCA](https://github.com/bradhowes/SwiftDataTCA) contains some of my experiments in this area.
