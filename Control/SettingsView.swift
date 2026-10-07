import Combine
import Foundation
import SwiftUI

private let GarbageData = "Ijwa0213LAjkd"

struct SettingsView: View {
    @StateObject private var postAuthKeyBuffer = DebouncedStringObservable(content: GarbageData)

    @State private var isErrorDialogShown = false
    @State private var dialogError: (any Error)? = nil

    let onUpdate: (SettingsUpdate) async throws -> Void
    @Binding var vm: SettingsViewModel

    var body: some View {
        Form {
            BackendSection(endpointBaseUrl: $vm.endpointBaseUrl, mainSiteUrl: $vm.mainSiteUrl, postAuthKey: $postAuthKeyBuffer.content)
                .onChange(of: vm.endpointBaseUrl) { _, newValue in
                    onUpdateErrorHandled(.backend(.init(endpoint: newValue, mainSiteUrl: vm.mainSiteUrl)))
                }
                .onChange(of: vm.mainSiteUrl) { _, newValue in
                    onUpdateErrorHandled(.backend(.init(endpoint: vm.endpointBaseUrl, mainSiteUrl: newValue)))
                }
            ClientSideImageUploadSection(service: $vm.imageService, endpointBaseUrl: $vm.cloudinaryAPIBaseUrl, cloudName: $vm.cloudinaryCloudName, presetName: $vm.cloudinaryPresetName)
                .onChange(of: vm.imageService) { _, newValue in
                    onUpdateErrorHandled(.imageService(newValue))
                }
                .onChange(of: vm.cloudinaryAPIBaseUrl) { _, _ in
                    if let newConfig = imageUploadConfiguration() {
                        onUpdateErrorHandled(.imageUploadConfig(newConfig))
                    }
                }
                .onChange(of: vm.cloudinaryCloudName) { _, _ in
                    if let newConfig = imageUploadConfiguration() {
                        onUpdateErrorHandled(.imageUploadConfig(newConfig))
                    }
                }
                .onChange(of: vm.cloudinaryPresetName) { _, _ in
                    if let newConfig = imageUploadConfiguration() {
                        onUpdateErrorHandled(.imageUploadConfig(newConfig))
                    }
                }
            AIServiceSection(openAIBaseUrl: $vm.openAIBaseUrl, openAIAPIKey: $vm.openAIApiKey, openAIModelName: $vm.openAIModelName)
                .onChange(of: vm.openAIApiKey) { _, _ in
                    if let newConfig = openAIServiceConfiguration() {
                        onUpdateErrorHandled(.openAIServiceConfig(newConfig))
                    }
                }
                .onChange(of: vm.openAIBaseUrl) { _, _ in
                    if let newConfig = openAIServiceConfiguration() {
                        onUpdateErrorHandled(.openAIServiceConfig(newConfig))
                    }
                }
                .onChange(of: vm.openAIModelName) { _, _ in
                    if let newConfig = openAIServiceConfiguration() {
                        onUpdateErrorHandled(.openAIServiceConfig(newConfig))
                    }
                }
        }
        .navigationTitle("Settings")
        .onChange(of: postAuthKeyBuffer.debounced) { _, newValue in
            Task {
                let key = newValue.isEmpty ? nil : newValue
                try? Credentials.default.setPostAuthKey(newValue: key)
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
        .init(endpoint: vm.endpointBaseUrl, postAuthKey: key, mainSiteUrl: vm.mainSiteUrl)
    }

    private func imageUploadConfiguration() -> ClientSideImageUploadConfiguration? {
        if let url = URL(string: vm.cloudinaryAPIBaseUrl) {
            .init(baseURL: url, cloudName: vm.cloudinaryCloudName, presetName: vm.cloudinaryPresetName)
        } else {
            nil
        }
    }

    private func openAIServiceConfiguration() -> OpenAIServiceConfiguration? {
        if let url = URL(string: vm.openAIBaseUrl) {
            OpenAIServiceConfiguration(baseUrl: url, apiKey: vm.openAIApiKey, modelName: vm.openAIModelName)
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

    struct AIServiceSection: View {
        @Binding var openAIBaseUrl: String
        @Binding var openAIAPIKey: String
        @Binding var openAIModelName: String

        var body: some View {
            Section("AI Service") {
                TextField("OpenAI API endpoint", text: $openAIBaseUrl)
                TextField("Authorization token", text: $openAIAPIKey)
                TextField("Model name", text: $openAIModelName)
            }
        }
    }
}

enum SettingsUpdate {
    case key(String)
    case backend(BackendUpdate)
    case imageService(ClientSideImageService)
    case imageUploadConfig(ClientSideImageUploadConfiguration)
    case openAIServiceConfig(OpenAIServiceConfiguration)
}

struct BackendUpdate {
    let endpoint: String
    let mainSiteUrl: String
}

private final class DebouncedStringObservable: ObservableObject {
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
