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

    @State private var isErrorDialogShown = false
    @State private var dialogError: (any Error)? = nil

    let onUpdate: (SettingsUpdate) async throws -> Void

    var body: some View {
        Form {
            BackendSection(endpointBaseUrl: $endpointBaseUrl, mainSiteUrl: $mainSiteUrl, postAuthKey: $postAuthKeyBuffer.content)
                .onChange(of: endpointBaseUrl) { _, newValue in
                    onUpdateErrorHandled(.backend(.init(endpoint: newValue, mainSiteUrl: mainSiteUrl)))
                }
                .onChange(of: mainSiteUrl) { _, newValue in
                    onUpdateErrorHandled(.backend(.init(endpoint: endpointBaseUrl, mainSiteUrl: newValue)))
                }
            ClientSideImageUploadSection(service: Binding(get: {
                ClientSideImageService(rawValue: imageServiceName)!
            }, set: { newValue in
                imageServiceName = newValue.rawValue
            }), endpointBaseUrl: $cloudinaryAPIBaseUrl, cloudName: $cloudinaryCloudName, presetName: $cloudinaryPresetName)
                .onChange(of: imageServiceName) { _, newValue in
                    onUpdateErrorHandled(.imageService(ClientSideImageService(rawValue: newValue)!))
                }
                .onChange(of: cloudinaryAPIBaseUrl) { _, _ in
                    if let newConfig = imageUploadConfiguration() {
                        onUpdateErrorHandled(.imageUploadConfig(newConfig))
                    }
                }
                .onChange(of: cloudinaryCloudName) { _, _ in
                    if let newConfig = imageUploadConfiguration() {
                        onUpdateErrorHandled(.imageUploadConfig(newConfig))
                    }
                }
                .onChange(of: cloudinaryPresetName) { _, _ in
                    if let newConfig = imageUploadConfiguration() {
                        onUpdateErrorHandled(.imageUploadConfig(newConfig))
                    }
                }
        }
        .navigationTitle("Settings")
        .onChange(of: postAuthKeyBuffer.debounced) { _, newValue in
            Task {
                let key = newValue.isEmpty ? nil : newValue
                try? await Credentials.default.setPostAuthKey(newValue: key)
                onUpdateErrorHandled(.key(newValue))
            }
        }
        .alert("Invalid configuration", isPresented: $isErrorDialogShown, presenting: dialogError) { _ in
            Button(role: .cancel) {
                isErrorDialogShown = false
            }
        } message: { error in
            Text("\(error.localizedDescription) Please adjust the fields and try again")
        }
    }

    private func onUpdateErrorHandled(_ update: SettingsUpdate) {
        Task {
            do {
                try await onUpdate(update)
            } catch {
                dialogError = error
                isErrorDialogShown = true
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
    case key(String)
    case backend(BackendUpdate)
    case imageService(ClientSideImageService)
    case imageUploadConfig(ClientSideImageUploadConfiguration)
}

struct BackendUpdate {
    let endpoint: String
    let mainSiteUrl: String
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
