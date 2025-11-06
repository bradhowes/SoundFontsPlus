// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport

private let log = Logger(category: "FontFileAvailabilityMonitor")

public final class FontFileAvailabilityMonitor: ObservableObject {

}

#if false

func updateBookmarkButtons() {
  for index in 0..<soundFonts.count {
    if let soundFont = soundFonts.getBy(index: index) {
      if soundFont.kind.reference {
        if let cell: TableCell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) {
          cell.updateBookmarkButton()
        }
      }
    }
  }
}

func stopBookmarkMonitor() {
  self.bookmarkMonitor?.invalidate()
  self.bookmarkMonitor = nil
}

func startBookmarkMonitor() {
  stopBookmarkMonitor()
  self.bookmarkMonitor = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
    guard let self = self else { return }
    self.updateBookmarkButtons()
  }
}

private var infoButton: UIButton? {
  guard let bookmark = self.bookmark else {
    return nil
  }

  let cloudState = bookmark.cloudState
  if cloudState == .local {
    if bookmark.isAvailable {
      return nil
    } else {
      return missingFileButton
    }
  }

  return cloudState == .downloaded ? nil : downloadableFileButton
}

private var downloadableFileButton: UIButton {
  let image = UIImage(named: "Download", in: Bundle(for: Self.self), compatibleWith: nil)
  let button = UIButton(frame: CGRect(x: 0, y: 0, width: 25, height: 25))
  button.setImage(image, for: .normal)
  button.addTarget(self, action: #selector(downloadMissingFile), for: .touchUpInside)
  return button
}

@objc private func downloadMissingFile() {
  guard let bookmark = self.bookmark else { return }
  let alert = UIAlertController(
    title: "Downloading", message: "Downloading the SF2 file for '\(bookmark.name)'",
    preferredStyle: .alert)
  activeAlert = alert
  alert.addAction(UIAlertAction(title: "OK", style: .cancel) { [weak self] _ in self?.activeAlert = nil })
  viewController?.present(alert, animated: true)
  do {
    if bookmark.url.startAccessingSecurityScopedResource() {
      try FileManager.default.startDownloadingUbiquitousItem(at: bookmark.url)
      bookmark.url.stopAccessingSecurityScopedResource()
    } else {
      try FileManager.default.startDownloadingUbiquitousItem(at: bookmark.url)
    }
  } catch {
    print("failed to start downloading \(bookmark.url)")
  }
}

private var missingFileButton: UIButton {
  let image = UIImage(named: "Error", in: Bundle(for: Self.self), compatibleWith: nil)
  let button = UIButton(frame: CGRect(x: 0, y: 0, width: 25, height: 25))
  button.setImage(image, for: .normal)
  button.addTarget(self, action: #selector(showMissingFileAlert), for: .touchUpInside)
  return button
}

@objc private func showMissingFileAlert() {
  guard let bookmark = self.bookmark else { return }
  let alert = UIAlertController(
    title: "File Missing",
    message: "Unable to access the SF2 file for '\(bookmark.name)'",
    preferredStyle: .alert)
  activeAlert = alert
  alert.addAction(UIAlertAction(title: "OK", style: .cancel) { [weak self] _ in self?.activeAlert = nil })
  viewController?.present(alert, animated: true)
}

#endif // false
