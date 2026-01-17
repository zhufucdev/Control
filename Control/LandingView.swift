import SwiftUI

struct LandingView: View {
    let onSubmit: (SettingsUpdate) -> Void

    @State private var postAuthKeyBuffer = ""
    @State private var endpointBaseUrlBuffer = DefaultApiEndpoint
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
                    onSubmit(SettingsUpdate(endpoint: endpointBaseUrlBuffer, postAuthKey: postAuthKeyBuffer, mainSiteUrl: mainSiteUrlBuffer))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                Button("Reset") {
                    postAuthKeyBuffer = ""
                    endpointBaseUrlBuffer = DefaultApiEndpoint
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .disabled(postAuthKeyBuffer == "" && endpointBaseUrlBuffer == DefaultApiEndpoint)
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

struct SettingsUpdate {
    let endpoint: String
    let postAuthKey: String
    let mainSiteUrl: String
}
