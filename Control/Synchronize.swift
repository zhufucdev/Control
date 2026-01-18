import Foundation
import OpenAPIClient
import SwiftData

extension CachedUpdatePost {
    @MainActor
    func pushToBackend() -> AsyncThrowingStream<PushSynchronizeState, any Error> {
        return AsyncThrowingStream { stream in
            Task {
                do {
                    var coverId: Int?
                    if let cover, let url = URL(string: cover.image), url.isFileURL {
                        stream.yield(.uploadingImage(progress: 0))
                        let response = try await DefaultAPI.imagePost(xAltText: cover.alt, xFileName: url.lastPathComponent, body: url)
                        do {
                            try FileManager.default.removeItem(at: url)
                        } catch {
                            print("Warning: failed to delete uploaded cover image")
                            print(error)
                        }
                        coverId = response.id
                        self.cover = .init(image: response.url, alt: cover.alt)
                    } else if cover == nil {
                        coverId = -1
                    }

                    if id < 0 {
                        let request = UpdatePutRequest(locale: locale, header: header, title: title, summary: summary, cover: coverId, mask: mask)
                        stream.yield(.creatingContent)
                        let newId = try await DefaultAPI.updatePut(updatePutRequest: request)
                        self.id = newId
                    } else {
                        stream.yield(.updatingContent)
                        let request = UpdateIdPatchRequest(locale: locale, header: header, title: title, summary: summary, cover: coverId, mask: mask, trashed: trashed)
                        _ = try await DefaultAPI.updateIdPatch(id: String(id), updateIdPatchRequest: request)
                    }
                    stream.finish()
                } catch {
                    stream.finish(throwing: error)
                }
            }
        }
    }
}

enum PushSynchronizeState: Equatable {
    case uploadingImage(progress: Float)
    case updatingContent
    case creatingContent
}

extension [CachedUpdatePost] {
    func pullFromBackend() async throws -> Diff<CachedUpdatePost> {
        let posts = Set((try await DefaultAPI.updateListGet()).map(CachedUpdatePost.init))
        return Diff(old: Set(self), new: posts)
    }
}

extension ModelContext {
    func apply(diffPosts: Diff<CachedUpdatePost>) {
        for removal in diffPosts.removal {
            if removal.id >= 0 {
                delete(removal)
            }
        }
        for addition in diffPosts.addition {
            insert(addition)
        }
    }
}

enum PullSynchronizeState {
    case downloadingContent
}
