import SwiftUI

@Observable
class SettingsViewModel {
    var endpointBaseUrl: String
    var mainSiteUrl: String
    var imageService: ClientSideImageService
    var cloudinaryAPIBaseUrl: String
    var cloudinaryCloudName: String
    var cloudinaryPresetName: String

    init(credentials: Credentials) {
        endpointBaseUrl = (try? credentials.endpointBaseUrl) ?? DefaultAPIEndpoint
        mainSiteUrl = (try? credentials.mainSiteUrl) ?? DefaultMainSiteUrl
        imageService = (try? credentials.clientSideImageService) ?? ClientSideImageService.backend
        cloudinaryAPIBaseUrl = (try? credentials.cloudinaryAPIBaseUrl) ?? DefaultCloudinaryAPIEndpoint
        cloudinaryCloudName = (try? credentials.cloudName) ?? ""
        cloudinaryPresetName = (try? credentials.presetName) ?? ""
    }
}
