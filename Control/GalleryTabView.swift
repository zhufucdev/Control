import CachedAsyncImage
import Foundation
import OpenAPIClient
import SwiftData
import SwiftUI

struct GalleryTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var screenWidth
    @Query(sort: \CachedGalleryItem.created, order: .reverse)
    private var items: [CachedGalleryItem]

    @State private var pullState: PullState? = nil
    @State private var pullTrialId = 0

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
        ScrollView {
            LazyVGrid(columns: preferredLayoutColumns) {
                ForEach(items, id: \.persistentModelID) { item in
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
                    } placeholder: {
                        ProgressView()
                            .frame(width: 42)
                    }
                    .clipped()
                }
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: .infinity)
        .bottomStatus(height: pullState != nil ? 50 : 0) {
            Group {
                if let pullState {
                    PullStateView(state: pullState) {
                        pullTrialId += 1
                    }
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
    }
}
