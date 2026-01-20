import OpenAPIClient
import SwiftData
import SwiftUI

struct UpdateTabView: View {
    @State private var pullTrialId = 0
    @State private var selection = Set<PersistentIdentifier>()
    @State private var pushErrorAlertContent: String? = nil
    @State private var pushState: PushSynchronizeState? = nil
    @State private var pullState: PullState? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var syncId = 0

    let onSettingsUpdated: (SettingsUpdate?) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CachedUpdatePost.created, order: .reverse)
    private var items: [CachedUpdatePost]

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            PostsList(selection: $selection, onSettingsUpdated: onSettingsUpdated) { item in
                Task {
                    await pushSync(targetItem: item)
                }
            } onDeleteItem: { item in
                Task {
                    await pushDelete(id: item.id)
                }
            }
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .bottomStatus(height: pushState != nil || pullState != nil ? 50 : 0) {
                Group {
                    if let pullState {
                        PullStateView(state: pullState) {
                            pullTrialId += 1
                        }
                    } else if let pushState { // only display one of them, which is a design choice
                        PushStateView(state: pushState)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .frame(maxWidth: 280)
            }
        } detail: {
            if selection.isEmpty {
                Text("Select an item")
            } else if let targetItem = items.first(where: { $0.persistentModelID == selection.first! }) {
                UpdatePostView(model: targetItem, id: syncId) {
                    Task {
                        await pushSync(targetItem: targetItem)
                    }
                }
                .bottomStatus(height: 50) {
                    Group {
                        if let pushState, columnVisibility == .detailOnly {
                            PushStateView(state: pushState)
                                .padding(.horizontal)
                                .padding(.bottom)
                                .frame(maxWidth: 280)
                        }
                    }
                }
            } else {
                Text("Item was removed. Select another one")
            }
        }
        .task(id: pullTrialId) {
            do {
                pullState = .pulling
                let diff = try await items.pullFromBackend()
                try modelContext.apply(diffPosts: diff)
                pullState = nil
            } catch let ErrorResponse.error(status, _, _, error) {
                if error is CancellationError {
                    pullState = nil
                    return
                }
                print("Update post pulling encountered an error: \(error)")
                pullState = .error(error)
            } catch {
                pullState = .error(error)
            }
        }
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

    private func pushSync(targetItem: CachedUpdatePost) async {
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
        } catch {
            pushErrorAlertContent = error.localizedDescription
        }
        pushState = nil
        syncId += 1
    }

    private func pushDelete(id: Int) async {
        do {
            _ = try await DefaultAPI.updateIdDelete(id: id)
        } catch {
            pushErrorAlertContent = error.localizedDescription
            print("Backend delete failed: \(error)")
        }
    }
}

struct PostsList: View {
    @Binding var selection: Set<PersistentIdentifier>
    let onSettingsUpdated: (SettingsUpdate?) -> Void
    let onTrashItem: (CachedUpdatePost) -> Void
    let onDeleteItem: (CachedUpdatePost) -> Void

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
                buildListItem(for: item)
                    .swipeActions {
                        Button(role: .destructive) {
                            trashItems([item])
                        }
                    }
            }
            Section("Deleted", isExpanded: $isDeletedExpanded) {
                ForEach(trashedItems, id: \.persistentModelID) { item in
                    buildListItem(for: item)
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

    private func buildListItem(for: CachedUpdatePost) -> some View {
        LabeledContent(`for`.title) {
            if !`for`.draft {
                Text(`for`.summary)
            } else {
                Text("Draft")
            }
        }
        .contextMenu {
            Button("Duplicate", systemImage: "plus.square.on.square") {
                duplicateItem(item: `for`)
            }
        }
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
                onTrashItem(item)
            }
        }
    }

    private func recoverItems<S>(_ items: S) where S: Sequence, S.Element == CachedUpdatePost {
        withAnimation {
            for item in items {
                item.trashed = false
                onTrashItem(item)
            }
        }
    }

    private func deleteItems<S>(_ items: S) where S: Sequence, S.Element == CachedUpdatePost {
        withAnimation {
            for item in items {
                onDeleteItem(item)
                modelContext.delete(item)
            }
        }
    }

    private func duplicateItem(item: CachedUpdatePost) {
        withAnimation {
            var post = UpdatePost(cache: item)
            post.id = -1
            modelContext.insert(CachedUpdatePost(from: post))
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

#Preview {
    UpdateTabView { _ in }
        .modelContainer(for: CachedUpdatePost.self, inMemory: true)
        .modelContainer(for: CachedGalleryItem.self, inMemory: true)
}
