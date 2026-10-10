import Combine
import Foundation
import OpenAI

class OpenAIService: ChatCompletion {
    let client: OpenAI
    let modelName: String
    static var shared = OpenAIService(client: .init(apiToken: ""))

    init(client: OpenAI, modelName: String = "gpt-6-luna") {
        self.client = client
        self.modelName = modelName
    }

    convenience init(config: OpenAIServiceConfiguration) throws(OpenAIServiceConfigurationParseError) {
        guard let host = config.baseUrl.host else {
            throw .invalidBaseURL
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
            throw .unknownPort
        }

        let openAIConfig = OpenAI.Configuration(token: config.apiKey, host: host, port: port, scheme: config.baseUrl.scheme!, basePath: config.baseUrl.path())
        self.init(client: OpenAI(configuration: openAIConfig), modelName: config.modelName)
    }

    typealias Failure = any Error
    typealias Response = AsyncThrowingCompactMapSequence<AsyncThrowingPublisher<AnyPublisher<Result<ChatStreamResult, any Error>, any Error>>, AssistantMessagePart>

    func getChatResponse(history: some Sequence<ChatMessage>) -> Response {
        let query = ChatQuery(messages: history.map(mapToAPIMessage), model: modelName)
        return client.chatsStream(query: query)
            .values
            .compactMap { result in
                switch result {
                case let .success(chunk):
                    return mapToAssistantMessagePart(from: chunk, choiceIndex: 0)
                case let .failure(err):
                    throw err
                }
            }
    }
}

enum OpenAIServiceConfigurationParseError: LocalizedError {
    case invalidBaseURL, unknownPort
    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            String(localized: "Invalid base URL.")
        case .unknownPort:
            String(localized: "Port number is unspecified and cannot be inferred.")
        }
    }
}

private func mapToAPIMessage(from: ChatMessage) -> ChatQuery.ChatCompletionMessageParam {
    switch from {
    case let .user(array):
        return .user(.init(content: .contentParts(array.map {
            switch $0 {
            case let .imageData(data, mime):
                .image(.init(imageUrl: .init(url: "data:\(mime);base64,\(data.base64EncodedString())", detail: .auto)))
            case let .imageURL(url):
                .image(.init(imageUrl: .init(url: url.absoluteString, detail: .auto)))
            case let .text(string):
                .text(.init(text: string))
            }
        })))
    case let .system(string):
        return .system(.init(content: .textContent(string)))
    case let .assistant(array):
        let text = array.compactMap {
            if case let .text(string) = $0 {
                string
            } else {
                nil
            }
        }.joined()
        let reasoning = array.compactMap {
            if case let .reasoning(string) = $0 {
                string
            } else {
                nil
            }
        }.joined()
        return .assistant(.init(content: .textContent(text), reasoningContent: reasoning))
    }
}

private nonisolated func mapToAssistantMessagePart(from: ChatStreamResult, choiceIndex: Int) -> AssistantMessagePart? {
    let delta = from.choices[choiceIndex].delta
    if let content = delta.content {
        return .text(content)
    } else if let reasoning = delta.reasoning {
        return .reasoning(reasoning)
    } else {
        return nil
    }
}

struct OpenAIServiceConfiguration {
    let baseUrl: URL
    let apiKey: String
    let modelName: String
}
