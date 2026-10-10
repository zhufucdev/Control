import Foundation
import ImageIO
import UniformTypeIdentifiers

extension Data {
    init(cgImage: CGImage, type: UTType = .jpeg) throws(CGImageIOError) {
        guard let buffer = CFDataCreateMutable(nil, cgImage.bytesPerRow * cgImage.height) else { throw CGImageIOError(kind: .buffer) }
        guard let dest = CGImageDestinationCreateWithData(buffer, type.identifier as CFString, 1, nil) else { throw CGImageIOError(kind: .conversion) }
        CGImageDestinationAddImage(dest, cgImage, nil)
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
