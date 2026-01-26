import CoreTransferable
import Foundation
import MimeTypeEnum
import OpenAPIClient
import SwiftData
import UniformTypeIdentifiers

extension CachedUpdatePost {
    @MainActor
    func pushToBackend(configuration: SynchronizeConfiguration = .shared) -> AsyncThrowingStream<PushSynchronizeState, any Error> {
        return AsyncThrowingStream { stream in
            Task {
                do {
                    if let cover, let url = URL(string: cover.image), url.isFileURL {
                        stream.yield(.uploadingImage(progress: .init()))
                        if let clientSideUpload = configuration.useClientSideImageUpload {
                            for try await state in try DefaultClientSideImageUpload.upload(url, configuration: clientSideUpload) {
                                switch state {
                                case let .uploading(progress):
                                    stream.yield(.uploadingImage(progress: progress))
                                case let .completed(resource):
                                    let serverImage = try await DefaultAPI.imagePut(imagePutRequest: .init(url: resource.absoluteString, alt: cover.alt))
                                    self.cover = UpdatePostCover(image: resource.absoluteString, alt: cover.alt, id: serverImage)
                                default: break // does not break out of the loop
                                }
                            }
                        } else {
                            let escapedAltText = cover.alt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                            let escapedFileName = url.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                            let rb = DefaultAPI.imagePostWithRequestBuilder(xAltText: escapedAltText, xFileName: escapedFileName, body: url)
                            rb.onProgressReady = { progress in
                                stream.yield(.uploadingImage(progress: progress))
                            }
                            let response = try await rb.execute()
                            self.cover = UpdatePostCover(image: response.body.url, alt: cover.alt, id: response.body.id)
                        }
                        do {
                            try FileManager.default.removeItem(at: url)
                        } catch {
                            print("Warning: failed to delete uploaded cover image")
                            print(error)
                        }
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
    func pushToBackend(configuration: SynchronizeConfiguration = .shared) -> AsyncThrowingStream<PushSynchronizeState, any Error> {
        return AsyncThrowingStream { stream in
            Task {
                do {
                    if self.draft {
                        stream.yield(.uploadingImage(progress: .init()))
                        guard let fileUrl = URL(string: self.image) else { throw URLError(.badURL) }
                        var imageId: Int = -1
                        if let clientSideUpload = configuration.useClientSideImageUpload {
                            for try await state in try DefaultClientSideImageUpload.upload(fileUrl, configuration: clientSideUpload) {
                                switch state {
                                case .uploading(let progress):
                                    stream.yield(.uploadingImage(progress: progress))
                                case .completed(let resource):
                                    let serverImage = try await DefaultAPI.imagePut(imagePutRequest: .init(url: resource.absoluteString, alt: self.alt))
                                    imageId = serverImage
                                default: break // does not break out of the loop
                                }
                            }
                        } else {
                            let escapedAltText = self.alt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self.alt
                            let escapedFileName = fileUrl.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fileUrl.lastPathComponent
                            let rb = DefaultAPI.imagePostWithRequestBuilder(xAltText: escapedAltText, xFileName: escapedFileName, body: fileUrl)
                            rb.onProgressReady = { progress in
                                stream.yield(.uploadingImage(progress: progress))
                            }
                            let response = try await rb.execute()
                            self.image = response.body.url
                            imageId = response.body.id
                        }
                        do {
                            try FileManager.default.removeItem(at: fileUrl)
                        } catch {
                            print("Warning: failed to delete uploaded gallery image")
                            print(error)
                        }

                        stream.yield(.creatingContent)
                        assert(imageId >= 0, "Image not uploaded")
                        let createRequest = GalleryPutRequest(locale: self.locale, tweet: self.tweet, imageId: imageId)
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

class SynchronizeConfiguration {
    static var shared = SynchronizeConfiguration(
        useClientSideImageUpload: .shared
    )
    var useClientSideImageUpload: ClientSideImageUploadConfiguration?

    init(useClientSideImageUpload: ClientSideImageUploadConfiguration? = nil) {
        self.useClientSideImageUpload = useClientSideImageUpload
    }
}

class DefaultClientSideImageUpload {
    class func upload(_ url: URL, configuration: ClientSideImageUploadConfiguration = .shared) throws -> AsyncThrowingStream<ClientSideImageUploadState, any Error> {
        let uploadEndpoint = configuration.baseURL.appending(components: "v1_1", configuration.cloudName, "auto", "upload")
        var request = URLRequest(url: uploadEndpoint)
        request.httpMethod = "POST"
        var formData = MultipartRequest()

        return AsyncThrowingStream { stream in
            do {
                stream.yield(.buffering)
                let urlContent = try Data(contentsOf: url)
                formData.add(key: "file", fileName: url.suggestedFilename ?? url.lastPathComponent, fileData: urlContent)
            } catch {
                stream.finish(throwing: error)
                return
            }
            formData.add(key: "upload_preset", value: configuration.presetName)
            request.httpBody = formData.httpBody
            request.setValue(formData.httpContentTypeHeaderValue, forHTTPHeaderField: "Content-Type")

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    stream.finish(throwing: error)
                    return
                }
                if let response = response as? HTTPURLResponse, response.statusCode < 200 || response.statusCode > 299 {
                    if let data {
                        print("Client image upload failed: \(String(data: data, encoding: .utf8)!)")
                    }
                    stream.finish(throwing: ClientSideImageUploadError.unsuccessfulHttpStatus(response.statusCode))
                    return
                }
                if let data {
                    do {
                        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                        if let dict, let secureUrl = dict["secure_url"] as? String {
                            stream.yield(.completed(resource: URL(string: secureUrl)!))
                            stream.finish()
                        } else {
                            stream.finish(throwing: ClientSideImageUploadError.invalidResponse)
                        }
                    } catch {
                        stream.finish(throwing: error)
                    }
                    return
                }
                stream.finish(throwing: ClientSideImageUploadError.noResponse)
            }

            task.resume()
            stream.yield(.uploading(progress: task.progress))
        }
    }
}

class ClientSideImageUploadConfiguration {
    static var shared = ClientSideImageUploadConfiguration(
        baseURL: URL(string: DefaultCloudinaryAPIEndpoint)!,
        cloudName: "",
        presetName: ""
    )

    var baseURL: URL
    var cloudName: String
    var presetName: String

    init(baseURL: URL, cloudName: String, presetName: String) {
        self.baseURL = baseURL
        self.cloudName = cloudName
        self.presetName = presetName
    }
}

enum ClientSideImageUploadState {
    case buffering
    case uploading(progress: Progress)
    case completed(resource: URL)
}

enum ClientSideImageUploadError: Error {
    case invalidResponse
    case unsuccessfulHttpStatus(Int)
    case noResponse
}

fileprivate extension Data {
    mutating func append(
        _ string: String,
        encoding: String.Encoding = .utf8
    ) {
        guard let data = string.data(using: encoding) else {
            return
        }
        append(data)
    }
}

fileprivate struct MultipartRequest {
    public let boundary: String

    private let separator: String = "\r\n"
    private var data: Data

    public init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
        data = .init()
    }

    private mutating func appendBoundarySeparator() {
        data.append("--\(boundary)\(separator)")
    }

    private mutating func appendSeparator() {
        data.append(separator)
    }

    private func disposition(_ key: String) -> String {
        "Content-Disposition: form-data; name=\"\(key)\""
    }

    mutating func add(
        key: String,
        value: String
    ) {
        appendBoundarySeparator()
        data.append(disposition(key) + separator)
        appendSeparator()
        data.append(value + separator)
    }

    mutating func add(
        key: String,
        fileName: String,
        fileData: Data,
        fileMimeType: String? = nil,
    ) {
        appendBoundarySeparator()
        data.append(disposition(key) + "; filename=\"\(fileName)\"" + separator)
        let mime = fileMimeType ?? MimeType.from(filename: fileName).rawValue
        data.append("Content-Type: \(mime)")
        data.append(separator + separator)
        data.append(fileData)
        appendSeparator()
    }

    var httpContentTypeHeaderValue: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    var httpBody: Data {
        var bodyData = data
        bodyData.append("--\(boundary)--")
        return bodyData
    }
}
