import Foundation
import UIKit

import QuickLookThumbnailing

let thumbnailStringSeperator = "><"
let blurHashWidth = 4

func extractThumbnail(_ fileURL: URL) -> (UIImage?, UIColor?)? {
  if #available(iOS 13.4, *) {
    let file: FileHandle
    let thumbnailString: String
    
    do {
      file = try FileHandle(forReadingFrom: fileURL)
      
      try file.seek(toOffset: UInt64(saltSize + kCCBlockSizeAES128))
      let filenameAndTypeLen: Int = try file.read(upToCount: 1)!.withUnsafeBytes({ $0.pointee })
      
      try file.seek(toOffset: UInt64(ivEnd + 1 + filenameAndTypeLen))
      let thumbLen: Int = try file.read(upToCount: 1)!.withUnsafeBytes({ $0.pointee })
      
      try file.seek(toOffset: UInt64(ivEnd + 1 + filenameAndTypeLen + 1))
      let thumbData = try file.read(upToCount: thumbLen)!
      
      file.closeFile()
      
      thumbnailString = String(decoding: thumbData, as: UTF8.self)
      
      NSLog("extractThumbnail - \(fileURL.lastPathComponent) - blurHash extracted \(thumbnailString)" )
    } catch {NSLog("extractThumbnail - \(fileURL.lastPathComponent) - file ops error \(error)"); return nil}
    
    let split = thumbnailString.components(separatedBy: thumbnailStringSeperator)
    let blurHash = split[0]
    let aspectString = split.count == 2 ? split[1] : nil
    
    let aspectRatio = aspectString != nil ? (aspectString! as NSString).floatValue : 1
    
    let thumbnailWidth = 50
    let thumbnailHeight = Int(Float(thumbnailWidth) * aspectRatio)
    let image = UIImage.init(blurHash: blurHash, size: CGSize(width: thumbnailWidth, height: thumbnailHeight))
    
    if(image == nil) {NSLog("extractThumbnail - \(fileURL.lastPathComponent) - image creation failed \(fileURL)  \(thumbnailString)"); return nil}
    
    let tintColour = image?.averageColor?.modified(withAdditionalHue: 0, additionalSaturation: 0.5, additionalBrightness: 0.1)
    
    return (image, tintColour)
  } else { NSLog("extractThumbnail - \(fileURL.lastPathComponent) - iOS version failure"); return nil}
}

func createThumbnail(_ fileURL: URL, completion: @escaping (String, UIColor) -> Void) {
  let thumbnailWidth = 50
  let thumbnailHeight = thumbnailWidth
  
  let previewGenerator = QLThumbnailGenerator()
  let request = QLThumbnailGenerator.Request(fileAt: fileURL, size: CGSize(width: thumbnailWidth, height: thumbnailHeight), scale: CGFloat(1), representationTypes: .thumbnail)
  
  previewGenerator.generateBestRepresentation(for: request) { (thumbnail, error) in
    if let error = error {
      print(error.localizedDescription)
    } else if let thumb = thumbnail {
      let aspectRatio = Float(thumb.uiImage.size.height / thumb.uiImage.size.width)
      let blurHashHeight = min(Int(Float(blurHashWidth) * aspectRatio), 9)
      
      let thumbnailString = thumb.uiImage.blurHash(numberOfComponents: (blurHashWidth, blurHashHeight))! + thumbnailStringSeperator + aspectRatio.description
      
      let tintColour = thumb.uiImage.averageColor?.modified(withAdditionalHue: 0, additionalSaturation: 0.5, additionalBrightness: 0.1)
      
      completion(thumbnailString, tintColour!)
    }
  }
}


extension UIImage {
  var averageColor: UIColor? {
    guard let inputImage = CIImage(image: self) else { return nil }
    let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)
    
    guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
    guard let outputImage = filter.outputImage else { return nil }
    
    var bitmap = [UInt8](repeating: 0, count: 4)
    let context = CIContext(options: [.workingColorSpace: kCFNull])
    context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
    
    return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
  }
}

extension UIColor {
  func modified(withAdditionalHue hue: CGFloat, additionalSaturation: CGFloat, additionalBrightness: CGFloat) -> UIColor {
    
    var currentHue: CGFloat = 0.0
    var currentSaturation: CGFloat = 0.0
    var currentBrigthness: CGFloat = 0.0
    var currentAlpha: CGFloat = 0.0
    
    if self.getHue(&currentHue, saturation: &currentSaturation, brightness: &currentBrigthness, alpha: &currentAlpha){
      return UIColor(hue: currentHue + hue,
                     saturation: currentSaturation + additionalSaturation,
                     brightness: currentBrigthness + additionalBrightness,
                     alpha: currentAlpha)
    } else {
      return self
    }
  }
}
