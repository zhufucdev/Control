import Foundation
import OpenAI

class OpenAIService {
    let client: OpenAI
    static var shared = OpenAIService(client: .init(apiToken: ""))

    init(client: OpenAI) {
        self.client = client
    }

    convenience init?(config: OpenAIServiceConfiguration) {
        guard let host = config.baseUrl.host else {
            return nil
        }
        let nilablePort: Int? = if let port = config.baseUrl.port {
            port
        } else if let scheme = config.baseUrl.scheme {
            if scheme == "https" {
                443
            } else if scheme == "http" {
                80
            } else {
                nil
            }
        } else {
            nil
        }
        guard let port = nilablePort else {
            return nil
        }

        let openAIConfig = OpenAI.Configuration(token: config.apiKey, host: host, port: port, scheme: config.baseUrl.scheme!, basePath: config.baseUrl.path())
        self.init(client: OpenAI(configuration: openAIConfig))
    }
}

struct OpenAIServiceConfiguration {
    let baseUrl: URL
    let apiKey: String
    let modelName: String
}
