import Foundation
import ImageIO

extension Data {
    func removingEXIF() -> Data? {
        guard let source = CGImageSourceCreateWithData(self as NSData, nil),
              let type = CGImageSourceGetType(source) else
        {
            return nil
        }

        let count = CGImageSourceGetCount(source)
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, type, count, nil) else {
            return nil
        }

        let exifToRemove: CFDictionary = [
            kCGImagePropertyExifDictionary: kCFNull,
            kCGImagePropertyGPSDictionary: kCFNull,
        ] as CFDictionary

        for index in 0 ..< count {
            CGImageDestinationAddImageFromSource(destination, source, index, exifToRemove)
            if !CGImageDestinationFinalize(destination) {
                print("Failed to finalize")
            }
        }

        return mutableData as Data
    }
}
