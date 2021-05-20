import Foundation

import QuickLook

class QLPreviewControllerSingleDataSource: QLPreviewControllerDataSource {
  init(fileURL: URL) {
    self.fileURL = fileURL
  }
  
  func numberOfPreviewItems(in: QLPreviewController) -> Int {return 1}
  func previewController(_: QLPreviewController, previewItemAt: Int) -> QLPreviewItem {
    return self.fileURL as QLPreviewItem
  }
  
  var fileURL: URL
}
