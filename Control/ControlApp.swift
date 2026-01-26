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

    @AppStorage(UserDefaultKeyEndpointBaseUrl) private var endpointBaseUrl = DefaultAPIEndpoint
    @AppStorage(UserDefaultMainSiteUrl) private var mainSiteUrl = DefaultMainSiteUrl
    @AppStorage(UserDefaultClientSideImageService) private var imageServiceName = ClientSideImageService.backend.rawValue
    @State var appState: ControlAppState = .locked

    func onInitialzie() {
        switch ClientSideImageService(rawValue: imageServiceName)! {
        case .cloudinary:
            if let config = try? ClientSideImageUploadConfiguration(userDefaults: .standard) {
                ClientSideImageUploadConfiguration.shared = config
                SynchronizeConfiguration.shared.useClientSideImageUpload = ClientSideImageUploadConfiguration.shared
            } else {
                print("Illegal user defaults for client side image upload found")
            }
        case .backend:
            SynchronizeConfiguration.shared.useClientSideImageUpload = nil
        }
        
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

    func onLandingSubmitted(submission: PrimeUpdate) {
        if submission.postAuthKey.isEmpty {
            appState = .uninitialized
        }

        Task(priority: .high) {
            try? await Credentials.default.setPostAuthKey(newValue: submission.postAuthKey)
            OpenAPIClientAPIConfiguration.shared.alternate(basePath: submission.endpoint, postAuthKey: submission.postAuthKey)
            appState = .ready(endpointBaseUrl: submission.endpoint, postAuthKey: submission.postAuthKey, mainSiteUrl: submission.mainSiteUrl)
        }
    }

    func onSettingsUpdated(_ update: SettingsUpdate) {
        switch update {
        case let .prime(prime):
            Task {
                await withDebounce(key: "onPrimarySettingsUpdate", for: .seconds(1)) {
                    onLandingSubmitted(submission: prime)
                }
            }
        case let .imageService(service):
            SynchronizeConfiguration.shared.useClientSideImageUpload = if service == .backend { nil } else { .shared }
        case let .imageUploadConfig(configuration):
            ClientSideImageUploadConfiguration.shared = configuration
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
                TabView {
                    Tab("Updates", systemImage: "text.rectangle.page.fill") {
                        UpdateTabView(onSettingsUpdated: onSettingsUpdated)
                    }
                    Tab("Gallery", systemImage: "photo.on.rectangle.angled") {
                        GalleryTabView()
                    }
                }
                .environment(\.postAuthKey, postAuthKey)
                .environment(\.endpointBaseUrl, endpoint)
                .environment(\.mainSiteUrl, mainSite)
                .modelContainer(sharedModelContainer)
            }
        }

        #if os(macOS)
            Settings {
                SettingsView(onUpdate: onSettingsUpdated)
                    .formStyle(.grouped)
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
