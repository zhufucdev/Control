import Combine
import Foundation
import SwiftUI

fileprivate let GarbageData = "Ijwa0213LAjkd"

struct SettingsView: View {
    @AppStorage(UserDefaultKeyEndpointBaseUrl) private var endpointBaseUrl = DefaultAPIEndpoint
    @AppStorage(UserDefaultMainSiteUrl) private var mainSiteUrl = DefaultMainSiteUrl
    @StateObject private var postAuthKeyBuffer = DebouncedStringObservable(content: GarbageData)

    @AppStorage(UserDefaultClientSideImageService) private var imageServiceName = ClientSideImageService.backend.rawValue
    @AppStorage(UserDefaultCloudinaryAPIBaseUrl) private var cloudinaryAPIBaseUrl = DefaultCloudinaryAPIEndpoint
    @AppStorage(UserDefaultCloudName) private var cloudinaryCloudName = ""
    @AppStorage(UserDefaultPresetName) private var cloudinaryPresetName = ""
    
    let onUpdate: (SettingsUpdate) -> Void

    var body: some View {
        Form {
            BackendSection(endpointBaseUrl: $endpointBaseUrl, mainSiteUrl: $mainSiteUrl, postAuthKey: $postAuthKeyBuffer.content)
                .onChange(of: endpointBaseUrl) { _, _ in
                    onUpdate(.prime(primeUpdate(key: postAuthKeyBuffer.content)))
                }
                .onChange(of: mainSiteUrl) { _, _ in
                    onUpdate(.prime(primeUpdate(key: postAuthKeyBuffer.content)))
                }
            ClientSideImageUploadSection(service: Binding(get: {
                ClientSideImageService(rawValue: imageServiceName)!
            }, set: { newValue in
                imageServiceName = newValue.rawValue
            }), endpointBaseUrl: $cloudinaryAPIBaseUrl, cloudName: $cloudinaryCloudName, presetName: $cloudinaryPresetName)
            .onChange(of: imageServiceName) { oldValue, newValue in
                onUpdate(.imageService(ClientSideImageService(rawValue: newValue)!))
            }
            .onChange(of: cloudinaryAPIBaseUrl) { oldValue, newValue in
                if let newConfig = imageUploadConfiguration() {
                    onUpdate(.imageUploadConfig(newConfig))
                }
            }
            .onChange(of: cloudinaryCloudName) { oldValue, newValue in
                if let newConfig = imageUploadConfiguration() {
                    onUpdate(.imageUploadConfig(newConfig))
                }
            }
            .onChange(of: cloudinaryPresetName) { oldValue, newValue in
                if let newConfig = imageUploadConfiguration() {
                    onUpdate(.imageUploadConfig(newConfig))
                }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: postAuthKeyBuffer.debounced) { _, newValue in
            Task {
                let key = newValue.isEmpty ? nil : newValue
                try? await Credentials.default.setPostAuthKey(newValue: key)
                onUpdate(.prime(primeUpdate(key: newValue)))
            }
        }
    }
    
    private func primeUpdate(key: String) -> PrimeUpdate {
        .init(endpoint: endpointBaseUrl, postAuthKey: key, mainSiteUrl: mainSiteUrl)
    }
    
    private func imageUploadConfiguration() -> ClientSideImageUploadConfiguration? {
        if let url = URL(string: cloudinaryAPIBaseUrl) {
            .init(baseURL: url, cloudName: cloudinaryCloudName, presetName: cloudinaryPresetName)
        } else {
            nil
        }
    }

    struct BackendSection: View {
        @Binding var endpointBaseUrl: String
        @Binding var mainSiteUrl: String
        @Binding var postAuthKey: String
        var body: some View {
            Section("Backend") {
                TextField("Main site URL", text: $mainSiteUrl)
                    .autocorrectionDisabled()
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
                TextField("Endpoint base URL", text: $endpointBaseUrl)
                    .autocorrectionDisabled()
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
                    .onChange(of: mainSiteUrl) { oldValue, newValue in
                        if !endpointBaseUrl.starts(with: oldValue) {
                            return
                        }
                        endpointBaseUrl = newValue + endpointBaseUrl.trimmingPrefix(oldValue)
                    }
                SecureField("Post authentication key", text: $postAuthKey)
            }
        }
    }

    struct ClientSideImageUploadSection: View {
        @Binding var service: ClientSideImageService
        @Binding var endpointBaseUrl: String
        @Binding var cloudName: String
        @Binding var presetName: String
        var body: some View {
            Section("Image upload") {
                Picker("Service", selection: $service) {
                    ForEach(ClientSideImageService.allCases, id: \.rawValue) { service in
                        Text(service.name).tag(service)
                    }
                }
                switch service {
                case .backend:
                    EmptyView()
                case .cloudinary:
                    TextField("Cloudinary API endpoint", text: $endpointBaseUrl)
                        .autocorrectionDisabled()
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                    #endif
                    TextField("Cloud name", text: $cloudName)
                        .autocorrectionDisabled()
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                    #endif
                    TextField("Preset name", text: $presetName)
                        .autocorrectionDisabled()
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                    #endif
                }
            }
        }
    }
}

enum SettingsUpdate {
    case prime(PrimeUpdate)
    case imageService(ClientSideImageService)
    case imageUploadConfig(ClientSideImageUploadConfiguration)
}

fileprivate final class DebouncedStringObservable: ObservableObject {
    @Published var content: String
    @Published var debounced: String
    private var subscriptions = Set<AnyCancellable>()

    init(content: String) {
        self.content = content
        debounced = content

        $content
            .debounce(for: .seconds(1), scheduler: RunLoop.current)
            .sink { [weak self] value in
                self?.debounced = value
            }
            .store(in: &subscriptions)
    }
}

enum ClientSideImageService: String, CaseIterable {
    case backend
    case cloudinary
}

extension ClientSideImageService {
    var name: String {
        switch self {
        case .backend:
            String(localized: "Backend")
        case .cloudinary:
            String(localized: "Cloudinary")
        }
    }
}
