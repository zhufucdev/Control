import Foundation
import OpenAPIClient
import SwiftData
import SwiftUI

struct PostsList: View {
    @Binding var selection: Set<PersistentIdentifier>
    let onSettingsUpdated: (SettingsUpdate) async throws -> Void
    let onTrashItem: (CachedUpdatePost) -> Void
    let onDeleteItem: (CachedUpdatePost) -> Void
    let onTranslate: (CachedUpdatePost) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.settingsViewModel) private var settings
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
                    .contextMenu {
                        Button("Translate", systemImage: "translate") {
                            onTranslate(item)
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
                            if let settings {
                                SettingsView(onUpdate: onSettingsUpdated, vm: settings)
                            } else {
                                ProgressView()
                            }
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
            try? modelContext.save()
        }
    }

    private func trashItems<S: Sequence>(_ items: S) where S.Element == CachedUpdatePost {
        withAnimation {
            for item in items {
                item.trashed = true
                onTrashItem(item)
            }
        }
    }

    private func recoverItems<S: Sequence>(_ items: S) where S.Element == CachedUpdatePost {
        withAnimation {
            for item in items {
                item.trashed = false
                onTrashItem(item)
            }
        }
    }

    private func deleteItems<S: Sequence>(_ items: S) where S.Element == CachedUpdatePost {
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
            try? modelContext.save()
        }
    }
}
