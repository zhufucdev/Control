import Foundation

extension ClientSideImageUploadConfiguration {
    convenience init(userDefaults: UserDefaults) throws {
        let apiEndpoint = userDefaults.string(forKey: UserDefaultCloudinaryAPIBaseUrl) ?? DefaultCloudinaryAPIEndpoint
        guard let baseURL = URL(string: apiEndpoint) else { throw URLError(.badURL) }
        let cloudName = userDefaults.string(forKey: UserDefaultCloudName) ?? ""
        let presetName = userDefaults.string(forKey: UserDefaultPresetName) ?? ""
        self.init(baseURL: URL(string: apiEndpoint)!, cloudName: cloudName, presetName: presetName)
    }
}
