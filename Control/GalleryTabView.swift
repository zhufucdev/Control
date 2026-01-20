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
            .padding(.bottom)
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
            TweetView(isPresented: $isTweeting) { post in
                let newItem = CachedGalleryItem(from: post)
                modelContext.insert(newItem)
                Task {
                    await pushItem(newItem)
                }
            }
            .clipped()
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

    private func buildImageFor(_ item: CachedGalleryItem) -> some View {
        CachedAsyncImage(
            url: URL(string: item.image),
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
        .clipped()
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

fileprivate struct TweetView: View {
    @Binding var isPresented: Bool
    let post: (GalleryItem) -> Void

    @State private var tweetBuffer = ""
    @State private var altText = ""
    @State private var isEditingAltText = false
    @State private var locale: SupportedLocale? = nil
    @State private var photoSelection: PhotosPickerItem? = nil
    @State private var altTextChannel: AsyncChannel<Optional<String>>? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    PhotosPicker("Pick a moment", selection: $photoSelection)
                        .photosPickerStyle(.compact)
                        .photosPickerAccessoryVisibility(.hidden)
                        .frame(idealHeight: 120)

                    TextField("What's up?", text: $tweetBuffer)
                        .textFieldStyle(.plain)
                        .frame(minHeight: 200, alignment: .top)
                }
                .padding(.horizontal)
            }
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
                .altTextAlert(isPresented: $isEditingAltText, initialText: altText) { newValue in
                    if let altTextChannel {
                        Task {
                            await altTextChannel.send(.some(newValue))
                        }
                    } else {
                        altText = newValue
                    }
                } onCancel: {
                    if let altTextChannel {
                        Task {
                            await altTextChannel.send(.none)
                        }
                    }
                }
        }
    }

    private var closeButton: some View {
        Button("Close", systemImage: "xmark") {
            isPresented = false
        }
    }

    private var postButton: some View {
        Button("Post", systemImage: "arrow.up") {
            Task {
                await postButtonClicked()
            }
        }
        .disabled(photoSelection == nil)
    }

    private func postButtonClicked() async {
        guard let photoSelection else { return }
        
        if altText.isEmpty {
            let channel = AsyncChannel<Optional<String>>()
            altTextChannel = channel
            isEditingAltText = true
            for await alt in channel {
                if let alt {
                    altText = alt
                    break
                } else {
                    return
                }
            }
        }

        isPresented = false
        guard let image = try? await photoSelection.loadTransferable(type: DataUrl.self) else {
            print("No suitable conversion found from PhotosPickerItem to DataUrl")
            return
        }
        let container = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appending(component: UUID().uuidString, directoryHint: .isDirectory)
        let filename = image.suggestedFilename ?? image.url.lastPathComponent
        let resultingFile = container.appending(component: filename, directoryHint: .notDirectory)

        do {
            try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: image.url, to: resultingFile)
        } catch {
            print("Error loading photo selection: \(error)")
            return
        }

        post(.init(id: -1, locale: locale, tweet: tweetBuffer, image: resultingFile.absoluteString, created: .now, alt: altText, trashed: false))
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
                isEditingAltText = true
            }
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
