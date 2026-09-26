import Foundation

extension ClientSideImageUploadConfiguration {
    convenience init(credentials: Credentials) throws {
        let apiEndpoint = try credentials.cloudinaryAPIBaseUrl ?? DefaultCloudinaryAPIEndpoint
        guard let baseURL = URL(string: apiEndpoint) else { throw URLError(.badURL) }
        let cloudName = try credentials.cloudName ?? ""
        let presetName = try credentials.presetName ?? ""
        self.init(baseURL: baseURL, cloudName: cloudName, presetName: presetName)
    }
}
