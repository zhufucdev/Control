import Foundation
import OpenAPIClient

protocol TranslateService {
    func translatePlainText(document: String, sourceLocale: SupportedLocale, targetLocale: SupportedLocale) async throws -> String
}

extension TranslateService where Self: ChatCompletion {
    func translatePlainText(document: String, target: SupportedLocale, source: SupportedLocale? = nil) async throws -> String {
        try (await getChatResponse(history: [])).map {
            switch $0 {
            case let .text(text):
                text
            }
        }.joined(separator: " ")
    }
}
