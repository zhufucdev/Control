import Foundation
import OpenAPIClient

extension OpenAPIClientAPIConfiguration {
    func alternate(basePath: String, postAuthKey: String) {
        self.basePath = basePath
        self.customHeaders = [
            "X-Post-Auth-Key": postAuthKey
        ]
    }
}
