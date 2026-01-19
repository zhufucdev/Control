import OpenAPIClient
import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var pullTrialId = 0
    @State private var selection = Set<PersistentIdentifier>()
    @State private var targetItem: CachedUpdatePost? = nil
    @State private var errorAlertContent: String? = nil
    @State private var pushErrorAlertContent: String? = nil
    @State private var pushState: PushSynchronizeState? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var syncId = 0

    let onSettingsUpdated: (SettingsUpdate?) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CachedUpdatePost.created, order: .reverse)
    private var items: [CachedUpdatePost]

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            PostsList(selection: $selection, onSettingsUpdated: onSettingsUpdated)
                .toolbar {
                    #if os(iOS)
                        ToolbarItem(placement: .navigationBarTrailing) {
                            EditButton()
                        }
                    #endif
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .bottomStatus(height: pushState != nil ? 50 : 0) {
                    Group {
                        if let pushState {
                            PushStateView(state: pushState)
                                .padding(.horizontal)
                                .padding(.bottom)
                                .frame(maxWidth: 280)
                        }
                    }
                }
        } detail: {
            if let targetItem {
                UpdatePostView(model: targetItem, id: syncId) {
                    Task {
                        do {
                            for try await state in targetItem.pushToBackend() {
                                pushState = state
                            }
                        } catch let ErrorResponse.error(_, body, _, innerError) {
                            pushErrorAlertContent = innerError.localizedDescription
                            print("Banckend push sync failed: \(innerError)")
                            if let body, let bodyText = String(data: body, encoding: .utf8) {
                                print("\(bodyText)")
                            }
                        }
                        pushState = nil
                        syncId += 1
                    }
                }
                .bottomStatus(height: pushState != nil && columnVisibility == .detailOnly ? 50 : 0) {
                    Group {
                        if let pushState {
                            PushStateView(state: pushState)
                                .padding(.horizontal)
                                .padding(.bottom)
                                .frame(maxWidth: 280)
                        }
                    }
                }
            } else {
                Text("Select an item")
            }
        }
        .task(id: pullTrialId) {
            do {
                let diff = try await items.pullFromBackend()
                modelContext.apply(diffPosts: diff)
            } catch let ErrorResponse.error(status, body, response, error) {
                if error is CancellationError {
                    return
                }
                if let body = body, response?.mimeType == "plain/text" {
                    errorAlertContent = String(data: body, encoding: .utf8)
                } else {
                    errorAlertContent = error.localizedDescription
                }
                print("Update post pulling encountered HTTP \(status)")
            } catch {
                // shouldn't happen
                print(error)
            }
        }
        .onChange(of: selection, { _, newValue in
            if let targetId = newValue.first {
                targetItem = items.first(where: { $0.persistentModelID == targetId })
            }
        })
        .alert("Could not pull update posts", isPresented: Binding(get: {
            errorAlertContent != nil
        }, set: { newValue in
            if !newValue {
                errorAlertContent = nil
            }
        }), actions: {
            Button(role: .cancel) {
                errorAlertContent = nil
            }
            Button("Retry") {
                pullTrialId += 1
                errorAlertContent = nil
            }
        }, message: {
            if let content = errorAlertContent {
                Text(content)
            }
        })
        .alert("Could not push update post", isPresented: Binding(get: {
            pushErrorAlertContent != nil
        }, set: { newValue in
            if !newValue {
                pushErrorAlertContent = nil
            }
        }), actions: {
            Button(role: .cancel) {
                pushErrorAlertContent = nil
            }
        }, message: {
            if let content = pushErrorAlertContent {
                Text(content)
            }
        })
    }
}

struct PostsList: View {
    @Binding var selection: Set<PersistentIdentifier>
    let onSettingsUpdated: (SettingsUpdate?) -> Void

    @Environment(\.modelContext) private var modelContext
    #if os(iOS)
        @State private var showCrudToolbarItems = false
    #endif

    @Query(filter: #Predicate { post in !post.trashed }, sort: \CachedUpdatePost.created, order: .reverse)
    private var items: [CachedUpdatePost]
    @Query(filter: #Predicate { post in post.trashed }, sort: \CachedUpdatePost.created, order: .reverse)
    private var trashedItems: [CachedUpdatePost]

    @State private var isDeletedExpanded = false

    var body: some View {
        List(selection: $selection) {
            ForEach(items, id: \.persistentModelID) { item in
                LabeledContent(item.title) {
                    Text(item.summary)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        trashItems([item])
                    }
                }
            }
            Section("Deleted", isExpanded: $isDeletedExpanded) {
                ForEach(trashedItems, id: \.persistentModelID) { item in
                    LabeledContent(item.title) {
                        Text(item.summary)
                    }
                    .swipeActions {
                        Button("Recover", systemImage: "arrow.up.trash") {
                            recoverItems([item])
                        }
                        Button(role: .destructive) {
                            deleteItems([item])
                        }
                    }
                }
            }
        }
        .animation(.spring, value: items)
        #if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .onDeleteCommand {
                trashItems(items.filter { selection.contains($0.persistentModelID) })
                deleteItems(trashedItems.filter { selection.contains($0.persistentModelID) })
            }
        #endif
            .toolbar {
                #if os(iOS)
                    if showCrudToolbarItems {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Button(role: .destructive) {
                                trashItems(items.filter { selection.contains($0.persistentModelID) })
                                deleteItems(trashedItems.filter { selection.contains($0.persistentModelID) })
                            }
                            Button("Recover", systemImage: "arrow.up.trash") {
                                recoverItems(trashedItems.filter { selection.contains($0.persistentModelID) })
                            }
                        }
                    }
                #endif
                ToolbarItemGroup {
                    #if os(iOS)
                        NavigationLink {
                            SettingsView(onModification: onSettingsUpdated)
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    #endif
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        #if os(iOS)
            .onChange(of: selection) { _, newValue in
                withAnimation {
                    showCrudToolbarItems = !newValue.isEmpty
                }
            }
        #endif
    }

    private func addItem() {
        withAnimation {
            let newItem = CachedUpdatePost()
            modelContext.insert(newItem)
        }
    }

    private func trashItems<S>(_ items: S) where S: Sequence, S.Element == CachedUpdatePost {
        withAnimation {
            for item in items {
                item.trashed = true
            }
        }
    }

    private func recoverItems<S>(_ items: S) where S: Sequence, S.Element == CachedUpdatePost {
        withAnimation {
            for item in items {
                item.trashed = false
            }
        }
    }

    private func deleteItems<S>(_ items: S) where S: Sequence, S.Element == CachedUpdatePost {
        withAnimation {
            for item in items {
                modelContext.delete(item)
            }
        }
    }
}

struct PushStateView: View {
    let state: PushSynchronizeState
    var body: some View {
        Group {
            switch state {
            case let .uploadingImage(progress):
                VStack {
                    ProgressView(value: progress)
                    Text("Uploading image...")
                }
            case .updatingContent:
                VStack {
                    ProgressView()
                        .progressViewStyle(.linear)
                    Text("Updating post...")
                }
            case .creatingContent:
                VStack {
                    ProgressView()
                        .progressViewStyle(.linear)
                    Text("Creating post...")
                }
            }
        }
    }
}

fileprivate struct BottomStatusModifier<C: View>: ViewModifier {
    @ViewBuilder let body: () -> C
    let bodyHeight: Double
    let gradientPadding: Double
    
    func body(content: Content) -> some View {
        if bodyHeight <= 0 {
            content
        } else {
            GeometryReader { surface in
                content.mask(
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: UnitPoint(x: 0, y: (surface.size.height - gradientPadding - bodyHeight) / surface.size.height),
                        endPoint: UnitPoint(x: 0, y: 1 - bodyHeight / surface.size.height)
                    )
                )
            }
            .overlay(alignment: .bottom) {
                body()
                    .frame(height: bodyHeight)
            }
        }
    }
}

fileprivate extension View {
    func bottomStatus<C : View>(height: Double, padding: Double = 40, body: @escaping () -> C) -> some View {
        self.modifier(BottomStatusModifier(body: body, bodyHeight: height, gradientPadding: padding))
    }
}

#Preview {
    ContentView { _ in }
        .modelContainer(for: CachedUpdatePost.self, inMemory: true)
        .modelContainer(for: CachedGalleryItem.self, inMemory: true)
}
