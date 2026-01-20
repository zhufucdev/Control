import Combine
import Foundation
import SwiftUI

fileprivate let GarbageData = "Ijwa0213LAjkd"

struct SettingsView: View {
    @AppStorage(UserDefaultsKeyEndpointBaseUrl) private var endpointBaseUrl = DefaultApiEndpoint
    @AppStorage(UserDefaultMainSiteUrl) private var mainSiteUrl = DefaultMainSiteUrl
    @StateObject private var postAuthKeyBuffer = DebouncedStringObservable(content: GarbageData)

    let onModification: (SettingsUpdate?) -> Void

    var body: some View {
        Group {
            Form {
                BackendSection(endpointBaseUrl: $endpointBaseUrl, mainSiteUrl: $mainSiteUrl, postAuthKey: $postAuthKeyBuffer.content)
                    .onChange(of: endpointBaseUrl) { _, _ in
                        onModification(nil)
                    }
                    .onChange(of: mainSiteUrl) { _, _ in
                        onModification(nil)
                    }
            }
            .navigationTitle("Settings")
            .onChange(of: postAuthKeyBuffer.debounced) { _, newValue in
                Task {
                    let key = newValue
                    try? await Credentials.default.setPostAuthKey(newValue: key.isEmpty ? nil : key)
                    onModification(.init(endpoint: endpointBaseUrl, postAuthKey: key, mainSiteUrl: mainSiteUrl))
                }
            }
        }
    }

    struct BackendSection: View {
        @Binding var endpointBaseUrl: String
        @Binding var mainSiteUrl: String
        @Binding var postAuthKey: String
        var body: some View {
            Section("Backend") {
                TextField("Main Site URL", text: $mainSiteUrl)
                    .autocorrectionDisabled()
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
                TextField("Endpoint Base URL", text: $endpointBaseUrl)
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
                SecureField("Post Authentication Key", text: $postAuthKey)
            }
        }
    }
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
