import OpenAI
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

    @State private var settings = SettingsViewModel(credentials: .default)
    @State private var initialized = (try? Credentials.default.initialized) ?? false
    @State private var appState: ControlAppState = .locked

    func onInitialzie() {
        switch settings.imageService {
        case .cloudinary:
            if let config = try? ClientSideImageUploadConfiguration(credentials: .default) {
                ClientSideImageUploadConfiguration.shared = config
                SynchronizeConfiguration.shared.useClientSideImageUpload = ClientSideImageUploadConfiguration.shared
            } else {
                print("Illegal user defaults for client side image upload found")
            }
        case .backend:
            SynchronizeConfiguration.shared.useClientSideImageUpload = nil
        }

        do {
            if let baseUrl = URL(string: settings.openAIBaseUrl) {
                OpenAIService.shared = try OpenAIService(config: .init(baseUrl: baseUrl, apiKey: settings.openAIApiKey, modelName: settings.openAIModelName))
            }
        } catch {
            print("onInitialize, OpenAI service error: \(error)")
        }

        Task {
            do {
                try Credentials.default.ensureUserPresence()
                let key = try Credentials.default.postAuthKey ?? ""
                let endpoint = settings.endpointBaseUrl
                if initialized {
                    try? OpenAPIClientAPIConfiguration.shared.alternate(basePath: endpoint, postAuthKey: key)
                    withAnimation {
                        appState = .ready(endpointBaseUrl: endpoint, postAuthKey: key, mainSiteUrl: settings.mainSiteUrl)
                    }
                } else {
                    appState = .uninitialized
                }
            } catch is CredentialAccessDenialError {
                appState = .locked
            } catch {
                print("onInitialize, unknown error: \(error)")
            }
        }
    }

    func onLandingSubmitted(submission: PrimeUpdate) async throws {
        try Credentials.default.setPostAuthKey(newValue: submission.postAuthKey)
        try OpenAPIClientAPIConfiguration.shared.alternate(basePath: submission.endpoint, postAuthKey: submission.postAuthKey)
        appState = .ready(endpointBaseUrl: submission.endpoint, postAuthKey: submission.postAuthKey, mainSiteUrl: submission.mainSiteUrl)
        initialized = true
        try Credentials.default.setInitialized(newValue: true)
    }

    func onSettingsUpdated(_ update: SettingsUpdate) async throws {
        switch update {
        case let .key(key):
            _ = try await withDebounce(key: "onKeyUpdate", for: .seconds(1)) {
                try Credentials.default.setPostAuthKey(newValue: key.isEmpty ? nil : key)
                try OpenAPIClientAPIConfiguration.shared.alternate(basePath: settings.endpointBaseUrl, postAuthKey: key)
                appState = .ready(endpointBaseUrl: settings.endpointBaseUrl, postAuthKey: key, mainSiteUrl: settings.mainSiteUrl)
            }
        case let .backend(backend):
            _ = try await withDebounce(key: "onBackendUpdate", for: .seconds(1)) {
                do {
                    try Credentials.default.setEndpointBaseUrl(newValue: backend.endpoint)
                    try Credentials.default.setMainSiteUrl(newValue: backend.mainSiteUrl)
                    settings.endpointBaseUrl = backend.endpoint
                    settings.mainSiteUrl = backend.mainSiteUrl
                    let key = if case let .ready(_, postAuthKey, _) = appState {
                        postAuthKey
                    } else {
                        try Credentials.default.postAuthKey ?? ""
                    }
                    try OpenAPIClientAPIConfiguration.shared.alternate(
                        basePath: backend.endpoint,
                        postAuthKey: key
                    )
                } catch is CredentialAccessDenialError {
                    appState = .locked
                }
            }
        case let .imageService(service):
            try Credentials.default.setClientSideImageService(newValue: service)
            settings.imageService = service
            SynchronizeConfiguration.shared.useClientSideImageUpload = if service == .backend { nil } else { .shared }
        case let .imageUploadConfig(configuration):
            _ = try await withDebounce(key: "onImageUploadConfigUpdate", for: .seconds(1)) {
                try Credentials.default.setCloudName(newValue: configuration.cloudName)
                try Credentials.default.setPresetName(newValue: configuration.presetName)
                settings.cloudinaryCloudName = configuration.cloudName
                settings.cloudinaryPresetName = configuration.presetName
                ClientSideImageUploadConfiguration.shared = configuration
                SynchronizeConfiguration.shared.useClientSideImageUpload = .shared
            }
        case let .openAIServiceConfig(config):
            _ = try await withDebounce(key: "openAIService", for: .seconds(1)) {
                try Credentials.default.setOpenAIBaseUrl(newValue: config.baseUrl.absoluteString)
                try Credentials.default.setOpenAIApiKey(newValue: config.apiKey)
                try Credentials.default.setOpenAIModelName(newValue: config.modelName)
                OpenAIService.shared = try OpenAIService(config: config)
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
                .environment(\.settingsViewModel, $settings)
                .modelContainer(sharedModelContainer)
            }
        }

        #if os(macOS)
            Settings {
                SettingsView(onUpdate: onSettingsUpdated, vm: $settings)
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
