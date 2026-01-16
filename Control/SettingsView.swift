import Foundation
import SwiftUI

struct SettingsView: View {
    @Binding var endpointBaseUrl: String
    @Binding var mainSiteUrl: String
    @Binding var postAuthKey: String
    var body: some View {
        Section("Backend") {
            TextField("Endpoint Base URL", text: $endpointBaseUrl)
            TextField("Main Site URL", text: $mainSiteUrl)
            SecureField("Post Authentication Key", text: $postAuthKey)
        }
    }
}
