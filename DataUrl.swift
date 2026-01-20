import AsyncAlgorithms
import Combine
import Foundation
import ImageIO
import OpenAPIClient
import PhotosUI
import SDWebImageSwiftUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct DataUrl: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .image) { data in
            SentTransferredFile(data.url)
        } importing: { received in
            let filename = received.file.suggestedFilename ?? received.file.lastPathComponent
            let resultingFile = try await getUniqueDocumentURL(filename: filename)
            try FileManager.default.copyItem(at: received.file, to: resultingFile)
            return Self(url: resultingFile)
        }
    }
}
