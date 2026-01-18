import Foundation
import OpenAPIClient

extension CachedUpdatePost {
    func pushToBackend() async throws {
        var coverId: Int?
        if let cover = self.cover, let url = URL(string: cover.image), url.isFileURL {
            let response = try await DefaultAPI.imagePost(xAltText: cover.alt, xFileName: url.lastPathComponent, body: url)
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Warning: failed to remove uploaded cover image")
                print(error)
            }
            self.cover?.image = response.url
            coverId = response.id
        } else if self.cover == nil {
            coverId = -1
        }
        
        if id < 0 {
            let request = UpdatePutRequest(locale: locale, header: header, title: title, summary: summary, cover: coverId, mask: mask)
            let newId = try await DefaultAPI.updatePut(updatePutRequest: request)
            self.id = Int(newId)
        } else {
            let request = UpdateIdPatchRequest(locale: locale, header: header, title: title, summary: summary, cover: coverId, mask: mask, trashed: trashed)
            _ = try await DefaultAPI.updateIdPatch(id: String(id), updateIdPatchRequest: request)
        }
    }
}
