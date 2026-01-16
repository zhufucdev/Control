import Foundation
import SwiftUI

extension EnvironmentValues {
    @Entry var postAuthKey: String = ""
    @Entry var endpointBaseUrl: String = DefaultApiEndpoint
    @Entry var mainSiteUrl: String = DefaultMainSiteUrl
}

let DefaultMainSiteUrl = "https://zhufucdev.com"
let DefaultApiEndpoint = "\(DefaultMainSiteUrl)/api"
