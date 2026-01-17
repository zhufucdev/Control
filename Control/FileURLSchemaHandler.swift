import Foundation
import WebKit

class FileURLSchemaHandler: URLSchemeHandler {
    func reply(for request: URLRequest) -> KFileDataGenerator {
        KFileDataGenerator(url: request.url)
    }
}

struct KFileDataGenerator: AsyncSequence, AsyncIteratorProtocol {
    typealias AsyncIterator = Self
    typealias Failure = any Error
    typealias Element = URLSchemeTaskResult

    let url: URL?
    var stage = 0
    var data: Data? = nil

    mutating func next() async throws -> URLSchemeTaskResult? {
        guard let url = url else { throw URLError(.resourceUnavailable) }
        if url.scheme != "kfile" {
            throw URLError(.badURL)
        }
        let fileUrl = URL(string: url.absoluteString.replacingOccurrences(of: "kfile://", with: "file://"))!
        let data = if let d = self.data { d } else { try Data(contentsOf: fileUrl) }
        self.data = data

        stage += 1
        switch stage {
        case 1:
            return .response(URLResponse(url: url, mimeType: "image/jpeg", expectedContentLength: data.count, textEncodingName: nil))
        case 2:
            return .data(data)
        default:
            return nil
        }
    }

    func makeAsyncIterator() -> Self {
        self
    }
}
