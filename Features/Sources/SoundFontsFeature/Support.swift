//import ComposableArchitecture
//import Engine
//import Extensions
//import Models
//import SF2ResourceFiles
//import SwiftUI
//
//enum Support {
//
//  static public func generateTagsList(from tags: [TagModel]) -> String {
//    tags.map(\.name).sorted().joined(separator: ", ")
//  }
//
//  public struct AddSoundFontsStatus {
//    public let good: [SoundFontModel]
//    public let bad: [String]
//
//    public init(good: [SoundFontModel], bad: [String]) {
//      self.good = good
//      self.bad = bad
//    }
//  }
//
//  public static func addSoundFonts(urls: [URL]) -> AddSoundFontsStatus? {
//    guard !urls.isEmpty else { return nil }
//
//    var good = [SoundFontModel]()
//    var bad = [String]()
//
//    for url in urls {
//      do {
//        let soundFont = try addSoundFont(url: url, copyFileWhenAdding: true)
//        good.append(soundFont)
//      } catch let err as NSError {
//        let fileName = url.lastPathComponent
//        if err.code == NSFileWriteFileExistsError {
//          bad.append("\(fileName): already exists")
//        } else {
//          bad.append("\(fileName): \(err.localizedDescription)")
//        }
//      } catch {
//        let fileName = url.lastPathComponent
//        bad.append("\(fileName): \(error.localizedDescription)")
//      }
//    }
//
//    return .init(good: good, bad: bad)
//  }
//
//  static func addSoundFont(url: URL, copyFileWhenAdding: Bool) throws -> SoundFontModel {
//    // Attempt to load the file to see if there are any errors
//    var fileInfo = SF2FileInfo(url.path(percentEncoded: false))
//    fileInfo.load()
//
//    // Use the file name for the initial display name. Users can change to other embedded values via editor.
//    let displayName = String(url.lastPathComponent.withoutExtension)
//
//    let location: Location
//    if copyFileWhenAdding {
//      location = .init(kind: .installed, url: try copyToSharedFolder(source: url), raw: nil)
//    } else {
//      let bookmark = Bookmark(url: url, name: displayName)
//      location = .init(kind: .external, url: bookmark.url, raw: bookmark.bookmark)
//    }
//
//    return try SoundFontModel.create(name: displayName, location: location, fileInfo: fileInfo, tags: location.tags)
//  }
//
//  static func copyToSharedFolder(source: URL) throws -> URL {
//    let secured = source.startAccessingSecurityScopedResource()
//    defer { if secured { source.stopAccessingSecurityScopedResource() } }
//    let destination = FileManager.default.sharedPath(for: source.lastPathComponent)
//    try FileManager.default.copyItem(at: source, to: destination)
//    return destination
//  }
//}
//
//extension String {
//  var withoutExtension: Substring { self[self.startIndex..<(self.lastIndex(of: ".") ?? self.endIndex)] }
//}
