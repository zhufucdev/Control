import SwiftUI

struct LandingView: View {
    let onSubmit: (PrimeUpdate) -> Void

    @State private var postAuthKeyBuffer = ""
    @State private var endpointBaseUrlBuffer = DefaultAPIEndpoint
    @State private var mainSiteUrlBuffer = DefaultMainSiteUrl

    var body: some View {
        NavigationStack {
            Form {
                SettingsView.BackendSection(
                    endpointBaseUrl: $endpointBaseUrlBuffer,
                    mainSiteUrl: $mainSiteUrlBuffer,
                    postAuthKey: $postAuthKeyBuffer
                )
                Button("Continue") {
                    onSubmit(PrimeUpdate(endpoint: endpointBaseUrlBuffer, postAuthKey: postAuthKeyBuffer, mainSiteUrl: mainSiteUrlBuffer))
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
