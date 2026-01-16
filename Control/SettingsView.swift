import Foundation
import SwiftUI

struct SettingsView: View {
    @Binding var endpointBaseUrl: String
    @Binding var mainSiteUrl: String
    @Binding var postAuthKey: String
    var body: some View {
        Section("Backend") {
            TextField("Main Site URL", text: $mainSiteUrl)
            TextField("Endpoint Base URL", text: $endpointBaseUrl)
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
