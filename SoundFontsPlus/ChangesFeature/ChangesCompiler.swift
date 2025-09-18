//import SwiftUI
//
//public struct ChangesCompiler {
//
//  public static func compile() -> [String] {
//    var entries = [String]()
//    let bundle = Bundle.main
//    guard
//      let changeLogUrl = bundle.url(forResource: "Changes", withExtension: "md", subdirectory: nil)
//    else {
//      return entries
//    }
//
//    guard let data = try? String(contentsOfFile: changeLogUrl.path, encoding: .utf8) else {
//      return entries
//    }
//
//    for line in data.components(separatedBy: .newlines) {
//      if line.hasPrefix("# ") {
//        let version = String(line[line.index(line.startIndex, offsetBy: 2)...])
//          .trimmingCharacters(in: .whitespaces)
//        entries.append("#" + version)
//      } else if line.hasPrefix("* ") {
//        let entry = String(line[line.index(line.startIndex, offsetBy: 2)...])
//          .trimmingCharacters(in: .whitespaces)
//        entries.append(entry)
//      } else if line.hasPrefix(" ") && !entries.isEmpty {
//        entries[entries.count - 1] = (entries.last ?? "") + " " + line.trimmingCharacters(in: .whitespaces)
//      }
//    }
//
//    return entries
//  }
//
//  static let bullet = "•"
//  static let versionFont = UIFont.preferredFont(forTextStyle: .headline)
//  static let font = UIFont.preferredFont(forTextStyle: .title3)
//
//  @ViewBuilder
//  public static func views(_ entries: [String]) -> some View {
//    List {
//      ForEach(entries, id: \.self) { entry in
//        if entry.starts(with: "#") {
//          HStack {
//            Text(String(entry.dropFirst(1)))
//              .foregroundStyle(.orange)
//              .font(.version)
//          }
//        } else {
//          HStack {
//            bulletView,
//            entryView(entry)
//          }
//        }
//        //      stack.axis = .horizontal
//        //      stack.spacing = 8
//        //      stack.alignment = .firstBaseline
//        //      stack.distribution = .fill
//        //      stack.translatesAutoresizingMaskIntoConstraints = false
//      }
//    }
//  }
//
//  static func versionView(_ version: String) -> some View {
//  }
//
//  static func bulletView() -> UIView {
//    let bulletView = UILabel()
//    bulletView.text = bullet
//    bulletView.textColor = .systemOrange
//    bulletView.font = font
//    bulletView.textAlignment = .natural
//    bulletView.setContentHuggingPriority(.required, for: .horizontal)
//    bulletView.translatesAutoresizingMaskIntoConstraints = false
//    bulletView.setContentHuggingPriority(.required, for: .horizontal)
//    bulletView.setContentCompressionResistancePriority(.required, for: .horizontal)
//    return bulletView
//  }
//
//  static func entryView(_ content: String) -> UIView {
//    let entryView = UILabel()
//    entryView.text = content
//    entryView.textColor = .systemTeal
//    entryView.font = font
//    entryView.numberOfLines = 0
//    entryView.textAlignment = .left
//    // entryView.setContentCompressionResistancePriority(.required, for: .horizontal)
//    entryView.translatesAutoresizingMaskIntoConstraints = false
//    return entryView
//  }
//}
