import Foundation
import ImageIO
import UniformTypeIdentifiers

extension Data {
    init(cgImage: CGImage) throws(CGImageIOError) {
        guard let buffer = CFDataCreateMutable(nil, cgImage.bytesPerRow * cgImage.height) else { throw CGImageIOError(kind: .buffer) }
        guard let dest = CGImageDestinationCreateWithData(buffer, UTType.jpeg.identifier as CFString, 1, nil) else { throw CGImageIOError(kind: .conversion) }
        if !CGImageDestinationFinalize(dest) {
            throw CGImageIOError(kind: .finalization)
        }
        self = buffer as Data
    }
}

struct CGImageIOError: Error {
    enum Kind {
        case buffer
        case conversion
        case finalization
    }
    let kind: Kind
}
