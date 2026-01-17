import OpenAPIClient
import SDWebImage
import SDWebImageSVGCoder
import SwiftData
import SwiftUI

@main
struct ControlApp: App {
    init() {
        SDImageCodersManager.shared.addCoder(SDImageSVGCoder.shared)
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CachedGalleryItem.self,
            CachedUpdatePost.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @AppStorage(UserDefaultsKeyEndpointBaseUrl) private var endpointBaseUrl = DefaultApiEndpoint
    @AppStorage(UserDefaultMainSiteUrl) private var mainSiteUrl = DefaultMainSiteUrl
    @State var appState: ControlAppState = .locked

    func onInitialzie() {
        Task {
            do {
                let key = try await Credentials.default.postAuthKey
                let endpoint = endpointBaseUrl
                if let key {
                    OpenAPIClientAPIConfiguration.shared.alternate(basePath: endpoint, postAuthKey: key)
                    withAnimation {
                        appState = .ready(endpointBaseUrl: endpoint, postAuthKey: key, mainSiteUrl: mainSiteUrl)
                    }
                } else {
                    appState = .uninitialized
                }
            } catch is CredentialAccessDenialError {
                appState = .locked
            }
        }
    }

    func onLandingSubmitted(submission: SettingsUpdate) {
        if submission.postAuthKey.isEmpty {
            appState = .uninitialized
        }

        Task(priority: .high) {
            try? await Credentials.default.setPostAuthKey(newValue: submission.postAuthKey)
            OpenAPIClientAPIConfiguration.shared.alternate(basePath: submission.endpoint, postAuthKey: submission.postAuthKey)
            await withTaskGroup { tg in
                tg.addTask {
                    do {
                        let gallery = try await DefaultAPI.galleryListGet()
                        DispatchQueue.main.async {
                            for item in gallery {
                                sharedModelContainer.mainContext.insert(CachedGalleryItem(from: item))
                            }
                        }
                    } catch {
                        // TODO: show a message
                    }
                }
                tg.addTask {
                    do {
                        let posts = try await DefaultAPI.updateListGet()
                        DispatchQueue.main.async {
                            for post in posts {
                                sharedModelContainer.mainContext.insert(CachedUpdatePost(from: post))
                            }
                        }
                    } catch {
                        // TODO: show a message
                    }
                }

                await tg.waitForAll()
            }
            appState = .ready(endpointBaseUrl: submission.endpoint, postAuthKey: submission.postAuthKey, mainSiteUrl: submission.mainSiteUrl)
        }
    }

    func onSettingsUpdated(update: SettingsUpdate?) {
        Task {
            await withDebounce(key: "onSettingsUpdate", for: .seconds(3)) {
                if let update {
                    onLandingSubmitted(submission: update)
                } else if case let .ready(_, postAuthKey, _) = appState {
                    onLandingSubmitted(submission: .init(endpoint: endpointBaseUrl, postAuthKey: postAuthKey, mainSiteUrl: mainSiteUrl))
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            switch appState {
            case .locked:
                LockedView(unlock: {
                    onInitialzie()
                })
                .onAppear {
                    onInitialzie()
                }
            case .uninitialized:
                LandingView(onSubmit: onLandingSubmitted)
            case let .ready(endpoint, postAuthKey, mainSite):
                ContentView(onSettingsUpdated: { update in
                    onSettingsUpdated(update: update)
                })
                .environment(\.postAuthKey, postAuthKey)
                .environment(\.endpointBaseUrl, endpoint)
                .environment(\.mainSiteUrl, mainSite)
                .modelContainer(sharedModelContainer)
            }
        }

        #if os(macOS)
            Settings {
                SettingsView { update in
                    onSettingsUpdated(update: update)
                }
                .frame(maxWidth: 600)
                .padding()
            }
        #endif
    }
}

enum ControlAppState {
    case locked
    case uninitialized
    case ready(endpointBaseUrl: String, postAuthKey: String, mainSiteUrl: String)
}
