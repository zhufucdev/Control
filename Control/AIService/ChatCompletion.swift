import AsyncAlgorithms
import Foundation

protocol ChatCompletion {
    associatedtype Failure: Error
    associatedtype Response: AsyncSequence<AssistantMessagePart, Failure>
    func getChatResponse(history: some Sequence<ChatMessage>) -> Response
}

class BroadcastChatCompletion<Service: ChatCompletion & Sendable>: ChatCompletion {
    typealias Failure = any Error
    typealias Response = AsyncThrowingMapSequence<Service.Response, AssistantMessagePart>

    private let inner: Service
    private var channel: AsyncThrowingChannel<AssistantMessagePart, Failure>
    init(from: Service) {
        inner = from
        channel = .init()
    }

    func getBroadcastChatResponse() -> AsyncThrowingChannel<AssistantMessagePart, Failure> {
        channel
    }

    func getChatResponse(history: some Sequence<ChatMessage>) -> Response {
        inner.getChatResponse(history: history)
            .map { chunk in
                await self.channel.send(chunk)
                return chunk
            }
    }
}

enum ChatMessage {
    case user([UserMessagePart])
    case system(String)
    case assistant([AssistantMessagePart])
}

enum UserMessagePart {
    case text(String), imageData(data: Data, mime: String), imageURL(URL)
}

enum AssistantMessagePart {
    case reasoning(String), text(String)
}

enum ReasoningEffort {
    case none, low, medium, high, max
}
