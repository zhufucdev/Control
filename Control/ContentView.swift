import OpenAPIClient
import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var pullTrialId = 0
    @State private var selection = Set<PersistentIdentifier>()
    @State private var errorAlertContent: String? = nil

    let onSettingsUpdated: (SettingsUpdate?) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CachedUpdatePost.created, order: .reverse)
    private var items: [CachedUpdatePost]

    var body: some View {
        NavigationSplitView {
            PostsList(selection: $selection, onSettingsUpdated: onSettingsUpdated)
                .toolbar {
                    #if os(iOS)
                        ToolbarItem(placement: .navigationBarTrailing) {
                            EditButton()
                        }
                    #endif
                }
        } detail: {
            if selection.count <= 0 {
                Text("Select an item")
            } else if let item = items.first(where: { selection.contains($0.persistentModelID) }) {
                UpdatePostView(model: item) {
                }
            } else {
                Text("This item is delete. Recover it first.")
            }
        }
        .task(id: pullTrialId) {
            do {
                let posts = Set((try await DefaultAPI.updateListGet()).map(CachedUpdatePost.init))
                let diff = Diff(old: Set(items), new: posts)
                DispatchQueue.main.async {
                    for removal in diff.removal {
                        if removal.id >= 0 {
                            modelContext.delete(removal)
                        }
                    }
                    for addition in diff.addition {
                        modelContext.insert(addition)
                    }
                }
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
                    NavigationLink {
                        UpdatePostView(model: item) {
                        }
                    } label: {
                        Text(item.title)
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

#Preview {
    ContentView { _ in }
        .modelContainer(for: CachedUpdatePost.self, inMemory: true)
        .modelContainer(for: CachedGalleryItem.self, inMemory: true)
}
