import Foundation
import OpenAPIClient
import SwiftData

extension CachedUpdatePost {
    @MainActor
    func pushToBackend() -> AsyncThrowingStream<PushSynchronizeState, any Error> {
        return AsyncThrowingStream { stream in
            Task {
                do {
                    if let cover, let url = URL(string: cover.image), url.isFileURL {
                        stream.yield(.uploadingImage(progress: .init()))
                        let rb = DefaultAPI.imagePostWithRequestBuilder(xAltText: cover.alt, xFileName: url.lastPathComponent, body: url)
                        rb.onProgressReady = { progress in
                            stream.yield(.uploadingImage(progress: progress))
                        }
                        let response = try await rb.execute()
                        do {
                            try FileManager.default.removeItem(at: url)
                        } catch {
                            print("Warning: failed to delete uploaded cover image")
                            print(error)
                        }
                        self.cover = UpdatePostCover(image: response.body.url, alt: cover.alt, id: response.body.id)
                    }

                    if id < 0 {
                        let request = UpdatePutRequest(locale: locale, header: header, title: title, summary: summary, cover: cover?.id, mask: mask)
                        stream.yield(.creatingContent)
                        let newId = try await DefaultAPI.updatePut(updatePutRequest: request)
                        self.id = newId
                    } else {
                        stream.yield(.updatingContent)
                        let request = UpdateIdPatchRequest(locale: locale, header: header, title: title, summary: summary, cover: cover?.id, mask: mask, trashed: trashed)
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
    case uploadingImage(progress: Progress)
    case updatingContent
    case creatingContent
}

extension [CachedUpdatePost] {
    func pullFromBackend() async throws -> Diff<UpdatePost> {
        let posts = Set(try await DefaultAPI.updateListGet())
        let cache = Set(map(UpdatePost.init))
        return Diff(old: cache, new: posts)
    }
}

extension ModelContext {
    func apply(diffPosts: Diff<UpdatePost>) throws {
        let existing = try fetch(FetchDescriptor<CachedUpdatePost>())
        for removal in diffPosts.removal {
            if removal.id >= 0, let item = existing.first(where: { $0.id == removal.id }) {
                delete(item)
            }
        }
        for addition in diffPosts.addition {
            insert(CachedUpdatePost(from: addition))
        }
    }

    func apply(diffGallery: Diff<GalleryItem>) throws {
        let existing = try fetch(FetchDescriptor<CachedGalleryItem>())
        for removal in diffGallery.removal {
            if removal.id >= 0, let item = existing.first(where: { $0.id == removal.id }) {
                delete(item)
            }
        }
        for addition in diffGallery.addition {
            insert(CachedGalleryItem(from: addition))
        }
    }
}

enum PullSynchronizeState {
    case downloadingContent
}

extension [CachedGalleryItem] {
    func pullFromBackend() async throws -> Diff<GalleryItem> {
        let gallery = Set(try await DefaultAPI.galleryListGet())
        let cache = Set(map(GalleryItem.init))
        return Diff(old: cache, new: gallery)
    }
}

extension CachedGalleryItem {
    @MainActor
    func pushToBackend() -> AsyncThrowingStream<PushSynchronizeState, any Error> {
        return AsyncThrowingStream { stream in
            Task {
                do {
                    if self.draft {
                        stream.yield(.uploadingImage(progress: .init()))
                        guard let fileUrl = URL(string: self.image) else { throw URLError(.badURL) }
                        let escapedAltText = self.alt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self.alt
                        let escapedFileName = fileUrl.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fileUrl.lastPathComponent
                        let rb = DefaultAPI.imagePostWithRequestBuilder(xAltText: escapedAltText, xFileName: escapedFileName, body: fileUrl)
                        rb.onProgressReady = { progress in
                            stream.yield(.uploadingImage(progress: progress))
                        }
                        let response = try await rb.execute()
                        do {
                            try FileManager.default.removeItem(at: fileUrl)
                        } catch {
                            print("Warning: failed to delete uploaded gallery image")
                            print(error)
                        }
                        self.image = response.body.url

                        stream.yield(.creatingContent)
                        let createRequest = GalleryPutRequest(locale: self.locale, tweet: self.tweet, imageId: response.body.id)
                        let postId = try await DefaultAPI.galleryPut(galleryPutRequest: createRequest)
                        self.id = postId
                    } else {
                        stream.yield(.updatingContent)
                        let updateRequest = GalleryIdPatchRequest(locale: self.locale, tweet: self.tweet, trashed: self.trashed)
                        _ = try await DefaultAPI.galleryIdPatch(id: self.id, galleryIdPatchRequest: updateRequest)
                    }

                    stream.finish()
                } catch {
                    stream.finish(throwing: error)
                }
            }
        }
    }
}
