import Foundation

protocol ChatCompletion {
    func getChatResponse(history: some Sequence<Message>) async throws -> [AssistantMessagePart]
}

enum Message {
    case user([UserMessagePart])
    case system(String)
    case assistant([AssistantMessagePart])
}

enum UserMessagePart {
    case text(String), image(data: Data, mime: String)
}

enum AssistantMessagePart {
    case text(String)
}

enum ReasoningEffort {
    case none, low, medium, high, max
}
