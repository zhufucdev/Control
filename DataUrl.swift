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
        FileRepresentation(contentType: .data) { data in
            SentTransferredFile(data.url)
        } importing: { received in
            Self(url: received.file)
        }
    }
}
