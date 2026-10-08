import Foundation
import OpenAPIClient
import SWXMLHash

protocol Translatable {
    func translateTo(_ targetLocale: SupportedLocale, service: some ChatCompletion) async throws -> Self
}

private func getTranslateTitleSummaryRequestTemplate(sourceLocale: SupportedLocale, targetLocale: SupportedLocale, title: some StringProtocol, summary: some StringProtocol) -> String {
    let b = String(promptBoundary: .random())
    return """
    You are tasked with translating the following social media tweet from \(sourceLocale.name) to \(targetLocale.name), wrapped in prompt boundary \(b).
    Output the translated data in XML. Do not include the prompt boundary wrapper.
    \(String(withPromptBoundary: getTranslateTitleSummaryTemplate(title: title, summary: summary)))
    """
}

private func getTranslateTitleSummaryTemplate(title: some StringProtocol, summary: some StringProtocol) -> String {
    """
    <tweet>
    <title>\(title)</title>
    <summary>\(summary)</summary>
    </tweet> 
    """
}

private func getTranslateHeaderRequestTemplateWithDictionary(sourceLocale: SupportedLocale, targetLocale: SupportedLocale, header: some StringProtocol, dictionary: some Sequence<String>) -> String {
    """
    You are tasked with translating the following text from \(sourceLocale.name) to \(targetLocale.name). Choose from the dictionary if possible.
    <text>
    \(String(withPromptBoundary: header))
    </text>

    <dictionary>
    \(String(withPromptBoundary: dictionary.joined(separator: "\n\n")))
    </dictionary>

    If there's no viable translation, use a custom one. Keep the translation short and clean. Either case, output in plain text. Do not include the prompt boundary wrapper nor XML tag.
    """
}

enum Translating: Equatable, Hashable {
    case updatePost(MaybeCooked<UpdatePost, Change<UpdatePost>>),
         updatePostHeader(post: MaybeCooked<UpdatePost, Change<UpdatePost>>, existingHeaders: [String])
}

nonisolated struct Change<V> {
    let before: V
    let after: V
}

enum MaybeCooked<Raw, Cooked> {
    case raw(Raw), cooked(Cooked)
}

extension [Translating]: Translatable {
    func translateTo(_ targetLocale: OpenAPIClient.SupportedLocale, service: some ChatCompletion) async throws -> Self {
        iteration: for _ in 0 ... 5 {
            var prompt: [ChatMessage] =
                [.system(PromptBoundary.instructions)] + flatMap {
                    switch $0 {
                    case let .updatePost(.cooked(change)):
                        return [
                            ChatMessage.user([.text(getTranslateTitleSummaryRequestTemplate(sourceLocale: change.before.locale, targetLocale: change.after.locale, title: change.before.title, summary: change.before.summary))]),
                            ChatMessage.assistant([.text(getTranslateTitleSummaryTemplate(title: change.after.title, summary: change.after.summary))]),
                        ]
                    case let .updatePost(.raw(p)):
                        return [
                            ChatMessage.user([.text(getTranslateTitleSummaryRequestTemplate(sourceLocale: p.locale, targetLocale: targetLocale, title: p.title, summary: p.summary))]),
                        ]
                    case let .updatePostHeader(.raw(p), h):
                        return [
                            ChatMessage.user([.text(getTranslateHeaderRequestTemplateWithDictionary(sourceLocale: p.locale, targetLocale: targetLocale, header: p.header, dictionary: h))]),
                        ]
                    case let .updatePostHeader(.cooked(c), h):
                        return [
                            ChatMessage.user([.text(getTranslateHeaderRequestTemplateWithDictionary(sourceLocale: c.before.locale, targetLocale: c.after.locale, header: c.before.header, dictionary: h))]),
                            ChatMessage.assistant([.text(c.after.header)]),
                        ]
                    }
                }

            var response = ""
            for try await chunk in service.getChatResponse(history: prompt) {
                switch chunk {
                case let .text(string):
                    response += string
                default:
                    continue
                }
            }

            switch last {
            case let .updatePost(.raw(translating)):
                #if DEBUG
                    print("translating, updatePost, model response: \(response)")
                #endif
                let structured = XMLHash.parse(response)
                guard let summary = structured["tweet"]["summary"].element?.text,
                      let title = structured["tweet"]["title"].element?.text
                else {
                    prompt.append(contentsOf: [
                        .assistant([.text(response)]),
                        .user([.text("Your response is invalid. Pay attention to the XML structure and retry.")]),
                    ])
                    continue iteration
                }

                var translated = translating
                translated.locale = targetLocale
                translated.created = .now
                translated.summary = summary
                translated.title = title
                return dropLast() + [.updatePost(.cooked(Change(before: translating, after: translated)))]

            case let .updatePostHeader(post: .raw(translating), existingHeaders):
                #if DEBUG
                    print("translating, updatePostHeader, model response: \(response)")
                #endif
                let header = response.trimmingCharacters(in: .whitespacesAndNewlines)
                if header.isEmpty {
                    prompt.append(contentsOf: [
                        .assistant([.text(response)]),
                        .user([.text("Empty response. Retry.")]),
                    ])
                    continue iteration
                }
                var translated = translating
                translated.header = header
                translated.locale = targetLocale
                return dropLast() + [.updatePostHeader(post: .cooked(Change(before: translating, after: translated)), existingHeaders: existingHeaders)]

            default:
                print("translateTo, nothing to translate, ignoring")
                return self
            }
        }
        throw TranslationError.maxRetryReached
    }
}

enum TranslationError: LocalizedError {
    case maxRetryReached
    
    var errorDescription: String? {
        switch self {
        case .maxRetryReached:
            String(localized: "Reached max retrials.")
        }
    }
}

extension UpdatePost: Translatable {
    func translateTo(_ targetLocale: OpenAPIClient.SupportedLocale, service: some ChatCompletion) async throws -> Self {
        switch try await [.updatePost(.raw(self))].translateTo(targetLocale, service: service)[0] {
        case let .updatePost(.cooked(change)):
            return change.after
        default:
            assertionFailure("translation got ignored")
            return self
        }
    }
}

extension Change: Equatable, Hashable where V: Hashable {}

extension MaybeCooked: Equatable, Hashable where Raw: Hashable, Cooked: Hashable {}

extension Translating {
    nonisolated var rawLocale: SupportedLocale {
        switch self {
        case let .updatePost(.raw(raw)):
            raw.locale
        case let .updatePost(.cooked(change)):
            change.before.locale
        case let .updatePostHeader(post: .raw(raw), _):
            raw.locale
        case let .updatePostHeader(post: .cooked(change), _):
            change.before.locale
        }
    }

    nonisolated var cookedLocale: SupportedLocale? {
        switch self {
        case let .updatePost(.cooked(change)):
            change.after.locale
        case let .updatePostHeader(post: .cooked(change), _):
            change.after.locale
        default:
            nil
        }
    }

    nonisolated var isCooked: Bool {
        switch self {
        case .updatePost(.cooked(_)), .updatePostHeader(post: .cooked(_), _):
            true
        default:
            false
        }
    }
}

extension Translating: Identifiable {
    var id: Int {
        hashValue
    }
}
