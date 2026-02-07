import SwiftUI

struct LandingView: View {
    let onSubmit: (PrimeUpdate) async throws -> Void

    @State private var postAuthKeyBuffer = ""
    @State private var endpointBaseUrlBuffer = DefaultAPIEndpoint
    @State private var mainSiteUrlBuffer = DefaultMainSiteUrl
    @State private var isInvalidConfigDialogShown = false
    @State private var configError: (any Error)? = nil

    var body: some View {
        NavigationStack {
            Form {
                SettingsView.BackendSection(
                    endpointBaseUrl: $endpointBaseUrlBuffer,
                    mainSiteUrl: $mainSiteUrlBuffer,
                    postAuthKey: $postAuthKeyBuffer
                )
                Button("Continue") {
                    Task {
                        do {
                            try await onSubmit(PrimeUpdate(endpoint: endpointBaseUrlBuffer, postAuthKey: postAuthKeyBuffer, mainSiteUrl: mainSiteUrlBuffer))
                        } catch {
                            configError = error
                            isInvalidConfigDialogShown = true
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                Button("Reset") {
                    postAuthKeyBuffer = ""
                    endpointBaseUrlBuffer = DefaultAPIEndpoint
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .disabled(postAuthKeyBuffer == "" && endpointBaseUrlBuffer == DefaultAPIEndpoint)
            }
            .formStyle(.grouped)
            .navigationTitle("Configurations")
        }
        .alert("Invalid configuration", isPresented: $isInvalidConfigDialogShown, presenting: configError) { _ in
            Button(role: .cancel) {
                isInvalidConfigDialogShown = false
            }
        } message: { error in
            Text("\(error.localizedDescription) Please adjust the fields and try again")
        }
    }
}

#Preview {
    LandingView { _ in
        // noop
    }
}

struct PrimeUpdate {
    let endpoint: String
    let postAuthKey: String
    let mainSiteUrl: String
}
