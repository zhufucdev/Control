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
    @State private var translating: CachedUpdatePost? = nil

    let onSettingsUpdated: (SettingsUpdate) async throws -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CachedUpdatePost.created, order: .reverse)
    private var items: [CachedUpdatePost]

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            PostsList(selection: $selection, onSettingsUpdated: onSettingsUpdated) { item in
                if item.draft {
                    return
                }
                Task {
                    await pushSync(targetItem: item)
                }
            } onDeleteItem: { item in
                if item.draft {
                    return
                }
                Task {
                    await pushDelete(id: item.id)
                }
            } onTranslate: { item in
                translating = item
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
            } catch let ErrorResponse.error(_, _, _, error) {
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
        .sheet(item: $translating, content: translationSheet)
    }

    private func pushSync(targetItem: CachedUpdatePost) async {
        do {
            for try await state in targetItem.pushToBackend() {
                pushState = state
            }
            syncId += 1
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
    }

    private func pushDelete(id: Int) async {
        do {
            _ = try await DefaultAPI.updateIdDelete(id: id)
        } catch {
            pushErrorAlertContent = error.localizedDescription
            print("Backend delete failed: \(error)")
            pullTrialId += 1
        }
    }

    private func translationSheet(for translating: CachedUpdatePost) -> some View {
        TranslationSheetContent(
            translating: .updatePost(.raw(UpdatePost(cache: translating))),
            onSubmit: { translations in
                for translation in translations {
                    switch translation {
                    case let .updatePost(.cooked(c)):
                        let cache = CachedUpdatePost(from: c.after)
                        cache.id = -1
                        Task {
                            await pushSync(targetItem: cache)
                            pullTrialId += 1
                        }
                    default:
                        break
                    }
                }
                do {
                    try modelContext.save()
                } catch {
                    print("UpdateTabView, translationSheet, onSubmit, modelContext.save, \(error)")
                }
            }
        )
    }
}

#Preview {
    UpdateTabView { _ in }
        .modelContainer(for: CachedUpdatePost.self, inMemory: true)
        .modelContainer(for: CachedGalleryItem.self, inMemory: true)
}
