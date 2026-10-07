import SwiftUI

@Observable
class SettingsViewModel {
    var endpointBaseUrl: String
    var mainSiteUrl: String
    var imageService: ClientSideImageService
    var cloudinaryAPIBaseUrl: String
    var cloudinaryCloudName: String
    var cloudinaryPresetName: String
    var openAIBaseUrl: String
    var openAIApiKey: String
    var openAIModelName: String

    init(credentials: Credentials) {
        endpointBaseUrl = (try? credentials.endpointBaseUrl) ?? DefaultAPIEndpoint
        mainSiteUrl = (try? credentials.mainSiteUrl) ?? DefaultMainSiteUrl
        imageService = (try? credentials.clientSideImageService) ?? ClientSideImageService.backend
        cloudinaryAPIBaseUrl = (try? credentials.cloudinaryAPIBaseUrl) ?? DefaultCloudinaryAPIEndpoint
        cloudinaryCloudName = (try? credentials.cloudName) ?? ""
        cloudinaryPresetName = (try? credentials.presetName) ?? ""
        openAIBaseUrl = (try? credentials.openAIBaseUrl) ?? DefaultOpenAIBaseUrl
        openAIApiKey = (try? credentials.openAIApiKey) ?? ""
        openAIModelName = (try? credentials.openAIModelName) ?? DefaultOpenAIModelName
    }
}
