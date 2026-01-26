import Foundation
import SwiftUI

extension EnvironmentValues {
    @Entry var postAuthKey: String = ""
    @Entry var endpointBaseUrl: String = DefaultAPIEndpoint
    @Entry var mainSiteUrl: String = DefaultMainSiteUrl
}

let DefaultMainSiteUrl = "https://zhufucdev.com"
let DefaultAPIEndpoint = "\(DefaultMainSiteUrl)/api"
let DefaultCloudinaryAPIEndpoint = "https://api.cloudinary.com"
