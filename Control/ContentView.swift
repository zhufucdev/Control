import OpenAPIClient
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CachedUpdatePost.created, order: .reverse) private var items: [CachedUpdatePost]

    @State private var pullTrialId = 0
    @State private var errorAlertContent: String? = nil

    let onSettingsUpdated: (SettingsUpdate?) -> Void

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        UpdatePostView(model: item) {
                        }
                    } label: {
                        Text(item.title)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            #endif
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
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
        } detail: {
            Text("Select an item")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = CachedUpdatePost()
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

fileprivate enum DetailSplitRoute {
    case placeholder
    case edit(CachedUpdatePost)
    case settings
}

#Preview {
    ContentView { _ in }
        .modelContainer(for: CachedUpdatePost.self, inMemory: true)
        .modelContainer(for: CachedGalleryItem.self, inMemory: true)
}
