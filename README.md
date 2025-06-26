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


# Status

At present this is just the user interface and SQLite backing store. It has served as a playground while I've been
learning about TCA and SQLite.


# History

The original SoundFonts app is written in Swift and UIKit. The data store is a disk file and a collection of
UserDefaults keys/value pairs. This repo is my attempt to replace the original with SwiftUI and SQLite.

Originally it was based on SwiftData, but I encountered too many issues and hurdles. Another repo of mine
[SwiftDataTCA](https://github.com/bradhowes/SwiftDataTCA) contains some of my experiments in this area.
