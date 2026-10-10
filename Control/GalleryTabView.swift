import AsyncAlgorithms
import CachedAsyncImage
import Foundation
import OpenAPIClient
import PhotosUI
import SwiftData
import SwiftUI

struct GalleryTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var screenWidth
    @Query(sort: \CachedGalleryItem.created, order: .reverse)
    private var items: [CachedGalleryItem]

    @State private var pullState: PullState? = nil
    @State private var pullTrialId = 0
    @State private var isTweeting = false
    @State private var pushState: PushSynchronizeState? = nil
    @State private var pushErrorAlertContent: (any Error)? = nil

    private let threeColumns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private let fourColumns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private var preferredLayoutColumns: [GridItem] {
        switch screenWidth {
        case .regular:
            fourColumns
        default:
            threeColumns
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: preferredLayoutColumns) {
                    ForEach(items, id: \.persistentModelID) { item in
                        buildImageFor(item)
                    }
                }
                .padding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Tweet", systemImage: "plus") {
                        isTweeting = true
                    }
                }
            }
        }
        .bottomStatus(height: pullState != nil || pushState != nil ? 50 : 0) {
            Group {
                if let pullState {
                    PullStateView(state: pullState) {
                        pullTrialId += 1
                    }
                } else if let pushState {
                    PushStateView(state: pushState)
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: 280)
        }
        .task(id: pullTrialId) {
            do {
                pullState = .pulling
                let diff = try await items.pullFromBackend()
                try modelContext.apply(diffGallery: diff)
                pullState = nil
            } catch {
                pullState = .error(error)
            }
        }
        .sheet(isPresented: $isTweeting) {
            switch screenWidth {
            case .regular:
                tweetView.clipped() // somehow overscrolling content escapes the modal container
            default:
                tweetView
            }
        }
        .alert("Failed to push to server", isPresented: Binding(get: {
            pushErrorAlertContent != nil
        }, set: { shown in
            if !shown {
                pushErrorAlertContent = nil
            }
        }), presenting: pushErrorAlertContent, actions: { _ in
            Button(role: .cancel) {
                pushErrorAlertContent = nil
            }
        }) { content in
            Text(content.localizedDescription)
        }
    }

    private var tweetView: some View {
        TweetView(isPresented: $isTweeting) { post in
            let newItem = CachedGalleryItem(from: post)
            modelContext.insert(newItem)
            Task {
                await pushItem(newItem)
            }
        }
    }

    private func buildImageFor(_ item: CachedGalleryItem) -> some View {
        CachedGalleryItemView(item, pushState: pushState)
            .contextMenu {
                if item.draft {
                    Button("Push", systemImage: "arrow.up") {
                        Task {
                            await pushItem(item)
                        }
                    }
                }
                if item.trashed {
                    Button("Delete forever", systemImage: "trash") {
                        Task {
                            await deleteItem(item)
                        }
                    }
                    Button("Recover") {
                        Task {
                            await recoverItem(item)
                        }
                    }
                } else {
                    Button("Delete", systemImage: "trash") {
                        Task {
                            await trashItem(item)
                        }
                    }
                }
            }
    }

    private func pushItem(_ item: CachedGalleryItem) async {
        do {
            for try await state in item.pushToBackend() {
                pushState = state
            }
        } catch {
            pushErrorAlertContent = error
            print("Error pushing: \(error)")
            if let response = error as? ErrorResponse, case let .error(int, data, uRLResponse, error) = response, let data {
                print("body: \(String(data: data, encoding: .utf8)!)")
            }
        }
        pushState = nil
    }

    private func trashItem(_ item: CachedGalleryItem) async {
        item.trashed = true
        if item.draft {
            return
        }
        await pushItem(item)
    }

    private func recoverItem(_ item: CachedGalleryItem) async {
        item.trashed = false
        if item.draft {
            return
        }
        await pushItem(item)
    }

    private func deleteItem(_ item: CachedGalleryItem) async {
        if item.draft {
            modelContext.delete(item)
            return
        }
        do {
            pushState = .updatingContent
            _ = try await DefaultAPI.galleryIdDelete(id: item.id)
            modelContext.delete(item)
        } catch {
            pushErrorAlertContent = error
            print("Error while deleting: \(error)")
        }
        pushState = nil
    }
}

private struct CachedGalleryItemView: View {
    @State private var previewURL: URL? = nil

    let item: CachedGalleryItem
    let pushState: PushSynchronizeState?
    init(_ item: CachedGalleryItem, pushState: PushSynchronizeState? = nil) {
        self.item = item
        self.pushState = pushState
    }

    private func processedURL(_ url: String, width: Int) -> URL? {
        if let url = URL(string: url) {
            if url.isCloudinaryResource, let widthLimited = url.limitingSize(width: (width / 200 + 1) * 200) {
                return widthLimited
            }
            return url
        } else {
            return nil
        }
    }

    var body: some View {
        Button {
            if let url = URL(string: item.image) {
                previewURL = url
            }
        } label: {
            GeometryReader { surface in
                let url = processedURL(item.image, width: Int(surface.size.width))
                CachedAsyncImage(
                    url: url,
                    urlCache: .init(
                        memoryCapacity: 1 << 26, // 64 MiB
                        diskCapacity: 1 << 29 // 0.5 GiB
                    )
                ) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .overlay(alignment: .bottomTrailing) {
                            Group {
                                if pushState != nil && item.draft {
                                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16)
                                        .symbolEffect(.rotate.byLayer, options: .repeat(.continuous))
                                } else if item.trashed {
                                    Image(systemName: "trash")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16)
                                } else if item.draft {
                                    Image(systemName: "square.and.arrow.up.badge.clock")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16)
                                }
                            }
                            .padding(6)
                        }
                } placeholder: {
                    ProgressView()
                        .frame(width: 42)
                }
                .frame(maxWidth: .infinity, idealHeight: 200, maxHeight: .infinity)
            }
            .scaledToFill()
            .clipped()
        }
        .buttonStyle(.plain)
        .previewingImage($previewURL, altText: item.alt)
    }
}

private struct TweetView: View {
    @Binding var isPresented: Bool
    let post: (GalleryItem) -> Void

    @State private var tweetBuffer = ""
    @State private var altText = ""
    @State private var captioning: CaptioningImage<URL>? = nil
    @State private var locale: SupportedLocale? = nil
    @State private var photoSelection: PhotosPickerItem? = nil
    @State private var altTextChannel: AsyncChannel<String?>? = nil
    @State private var errorAlertContent: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    PhotosPicker("Pick a moment", selection: $photoSelection, matching: .images)
                        .photosPickerStyle(.compact)
                        .photosPickerAccessoryVisibility(.hidden)
                        .frame(idealHeight: 120)

                    TextField("What's up?", text: $tweetBuffer)
                        .textFieldStyle(.plain)
                        .frame(minHeight: 200, alignment: .top)
                }
                .padding(.horizontal)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Tweet")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    #if os(iOS)
                        ToolbarItem(placement: .navigation) {
                            closeButton
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            postButton
                                .tint(.accentColor)
                        }
                        ToolbarItemGroup(placement: .bottomBar) {
                            metadataToolbarItems
                        }
                    #elseif os(macOS)
                        ToolbarItem(placement: .cancellationAction) {
                            closeButton
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            postButton
                        }
                        ToolbarItemGroup {
                            metadataToolbarItems
                        }
                    #endif
                }
                .altTextAlert(initialText: altText, captioning: $captioning, updateText: { newValue in
                    if let altTextChannel {
                        Task {
                            await altTextChannel.send(.some(newValue))
                        }
                    } else {
                        altText = newValue
                    }
                }, onCancel: {
                    if let altTextChannel {
                        Task {
                            await altTextChannel.send(.none)
                        }
                    }
                })
                .alert("Post failed", isPresented: Binding(get: {
                    errorAlertContent != nil
                }, set: { shown in
                    if !shown {
                        errorAlertContent = nil
                    }
                }), presenting: errorAlertContent) { _ in
                    Button(role: .confirm) {
                        errorAlertContent = nil
                    }
                } message: { msg in
                    Text(msg)
                }
        }
    }

    private var generateCaption: (() async throws -> String)? {
        if let photoSelection {
            {
                let file = try await getTweetImageURL(photoSelection: photoSelection, stripExif: true)
                let image = CIImage(contentsOf: file)!
                do {
                    let caption = try await image.getCaption(service: OpenAIService.shared)
                    try? FileManager.default.removeItem(at: file)
                    return caption
                } catch {
                    try? FileManager.default.removeItem(at: file)
                    throw error
                }
            }
        } else {
            nil
        }
    }

    private var closeButton: some View {
        Button("Close", systemImage: "xmark") {
            isPresented = false
        }
    }

    private var postButton: some View {
        Menu("Post", systemImage: "arrow.up") {
            Button("Sharing metadata") {
                Task {
                    await postButtonClicked(stripExif: false)
                }
            }
            .keyboardShortcut(.none)
            Button("Removing metadata") {
                Task {
                    await postButtonClicked(stripExif: true)
                }
            }
            .keyboardShortcut(.defaultAction)
        }
        .disabled(photoSelection == nil)
    }
    
    private func ensureAltText(stripExif: Bool) async throws -> URL? {
        guard let photoSelection else {
            return nil
        }
        let imageURL = try await getTweetImageURL(photoSelection: photoSelection, stripExif: stripExif)
        if altText.isEmpty {
            let channel = AsyncChannel<String?>()
            altTextChannel = channel
            captioning = .init(id: imageURL, image: CIImage(contentsOf: imageURL)!)
            for await alt in channel {
                channel.finish()
                if let alt {
                    altText = alt
                    break
                } else {
                    return nil
                }
            }
        }
        return imageURL
    }
    
    private func postButtonClicked(stripExif: Bool) async {
        do {
            guard let imageURL = try await ensureAltText(stripExif: stripExif) else {
                return
            }
            
            post(.init(id: -1, locale: locale, tweet: tweetBuffer, image: imageURL.absoluteString, created: .now, alt: altText, trashed: false))
        } catch {
            errorAlertContent = error.localizedDescription
            return
        }
        
        isPresented = false
    }

    private var metadataToolbarItems: some View {
        Group {
            Menu("Target locale", systemImage: "globe") {
                ForEach(SupportedLocale.allCases, id: \.rawValue) { locale in
                    Toggle(locale.name, isOn: Binding(get: {
                        self.locale == locale
                    }, set: { isOn in
                        if isOn {
                            self.locale = locale
                        }
                    }))
                }
                Toggle("Global", isOn: Binding(get: {
                    self.locale == nil
                }, set: { isOn in
                    if isOn {
                        self.locale = nil
                    }
                }))
            }
            Button("Alternative text", systemImage: "text.below.photo") {
                Task {
                    do {
                        _ = try await ensureAltText(stripExif: true)
                    } catch {
                        errorAlertContent = error.localizedDescription
                    }
                }
            }
        }
    }
}

enum GetTweetImageError: LocalizedError {
    case imageRead, exifRemoval, imageWrite(any Error)

    var errorDescription: String? {
        switch self {
        case .imageRead:
            String(localized: "Image read failed")
        case .exifRemoval:
            String(localized: "EXIF removal failed")
        case let .imageWrite(error):
            String(localized: "Could not rewrite EXIF-stripped image: \(error.localizedDescription)")
        }
    }
}

#Preview {
    GalleryTabView()
}

#Preview {
    TweetView(isPresented: .constant(true)) { _ in
    }
}
