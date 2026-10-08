import AsyncAlgorithms
import Foundation
import OpenAPIClient
import SDWebImageSwiftUI
import SwiftUI
import Synchronization

struct TranslationSheetContent: View {
    private enum State {
        case start, translating, review
    }

    @State private var path: [State] = []
    @State private var targetLocales = Set<SupportedLocale>()
    @State private var drafts: [Translating] = []
    @State private var translationFinished = false

    @Environment(\.dismiss) var dismiss

    let translating: Translating
    let onSubmit: ([Translating]) -> Void

    var body: some View {
        NavigationStack(path: $path) {
            StartPage(source: translating.rawLocale, target: $targetLocales)
                .toolbar {
                    if path.isEmpty {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close", systemImage: "xmark") {
                                dismiss()
                            }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Next", systemImage: "arrow.forward") {
                            path.append(.translating)
                        }
                        .disabled(targetLocales.isEmpty)
                    }
                }
                .navigationDestination(for: State.self) { state in
                    Group {
                        switch state {
                        case .start:
                            EmptyView()
                        case .translating:
                            TranslatingPage(
                                translating: translating,
                                targetLocales: SupportedLocale.allCases.filter { targetLocales.contains($0) },
                                service: OpenAIService.shared,
                                drafts: $drafts,
                                done: $translationFinished
                            )
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Next", systemImage: "arrow.forward") {
                                        self.path.append(.review)
                                    }
                                    .disabled(!translationFinished)
                                }
                            }
                        case .review:
                            ReviewPage(data: submissions, onEdit: { newDraft in
                                let index = drafts.firstIndex(where: {
                                    switch $0 {
                                    case let .updatePostHeader(.cooked(c), _):
                                        if case let .updatePostHeader(.cooked(c_), _) = newDraft {
                                            return c.after == c_.before
                                        }
                                    default:
                                        break
                                    }
                                    return false
                                })
                                if let index {
                                    drafts[index] = newDraft
                                }
                            })
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Submit", systemImage: "checkmark") {
                                        onSubmit(drafts.compactMap {
                                            switch $0 {
                                            case let .updatePostHeader(.cooked(c), _):
                                                .updatePost(.cooked(c))
                                            default:
                                                nil
                                            }
                                        })
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }
                }
                .animation(.easeInOut, value: path)
                .navigationTitle("Translate")
        }
    }

    var submissions: [Translating] {
        drafts.compactMap { draft in
            // TODO: actually flatten the changelist
            switch draft {
            case let .updatePostHeader(post: .cooked(c), h):
                .updatePostHeader(post: .cooked(.init(before: c.after, after: c.after)), existingHeaders: h)
            default:
                nil
            }
        }
    }
}

struct SubmittingUnsupportedDraftError: LocalizedError {
    var errorDescription: String? {
        String(localized: "Submission unsupported.")
    }
}

private struct StartPage: View {
    let source: SupportedLocale
    @Binding var target: Set<SupportedLocale>

    var body: some View {
        Form {
            Section {
                ForEach(SupportedLocale.allCases) { locale in
                    Toggle(locale.name, isOn: Binding(get: {
                        target.contains(locale) || locale == source
                    }, set: { newValue in
                        if newValue {
                            target.insert(locale)
                        } else {
                            target.remove(locale)
                        }
                    }))
                    .disabled(locale == source)
                    #if os(macOS)
                        .toggleStyle(.checkbox)
                    #else
                        .toggleStyle(.switch)
                    #endif
                }
            } footer: {
                Text("Choose one or more languages to translate to.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct TranslatingPage<Service: ChatCompletion & Sendable>: View {
    let translating: Translating
    let targetLocales: [SupportedLocale]
    let service: Service
    let broadcast: BroadcastChatCompletion<Service>

    init(translating: Translating, targetLocales: [SupportedLocale], service: Service, drafts: Binding<[Translating]>, done: Binding<Bool>) {
        self.translating = translating
        self.targetLocales = targetLocales
        self.service = service
        broadcast = .init(from: service)
        _drafts = drafts
        _done = done
    }

    @Binding var drafts: [Translating]
    @Binding var done: Bool
    @State private var assistantOutput = ""
    @State private var currentTargetLocale = SupportedLocale.en
    @State private var error: (any Error)? = nil
    @State private var retryCounter = 0

    var body: some View {
        Form {
            Section {
                ForEach(drafts) { draft in
                    labelPreferringResult(for: draft, targetLocale: currentTargetLocale)
                }
            } header: {
                if let error {
                    HStack {
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                        Spacer()
                        Button("Retry", systemImage: "arrow.clockwise") {
                            retryCounter += 1
                            self.error = nil
                        }
                    }
                } else if !done {
                    Text(assistantOutput)
                        .fontWeight(.regular)
                        .opacity(0.5)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                } else {
                    Text("Translation steps")
                }
            }
        }
        .formStyle(.grouped)
        .task(id: retryCounter) {
            do {
                try await translate()
                done = true
            } catch {
                self.error = error
            }
        }
        .task {
            while true {
                do {
                    for try await chunk in broadcast.getBroadcastChatResponse() {
                        await Task { @MainActor in
                            switch chunk {
                            case let .reasoning(string):
                                assistantOutput += string
                            case let .text(string):
                                assistantOutput += string
                            }
                            let lines = assistantOutput.split(separator: "\n", maxSplits: 2)
                            if lines.count >= 2 {
                                assistantOutput = String(lines[1])
                            }
                        }
                        .value
                    }
                } catch {
                    print("TranslatingPage, broadcast error: \(error)")
                }
            }
        }
    }

    func translate() async throws {
        for targetLocale in targetLocales {
            if drafts.contains(where: { $0.cookedLocale == targetLocale }) {
                // already translated
                continue
            }
            currentTargetLocale = targetLocale
            if drafts.last?.isCooked != false {
                drafts.append(translating)
            }
            iteration: while true {
                let drafts = self.drafts
                var newDrafts = try await drafts.translateTo(targetLocale, service: broadcast)
                switch drafts.last {
                case .updatePost(.raw):
                    let existingHeaders = try await DefaultAPI.stringsByLocaleLocaleGet(locale: targetLocale.rawValue)
                    if case let .updatePost(.cooked(c)) = newDrafts.last {
                        var post = c.after
                        post.locale = c.before.locale
                        newDrafts.append(.updatePostHeader(post: .raw(post), existingHeaders: existingHeaders))
                    }
                case .updatePostHeader(.raw(_), _):
                    self.drafts = newDrafts
                    break iteration
                default:
                    print("TranslatingPage, translate, illegal draft state, stopping")
                    break iteration
                }
                self.drafts = newDrafts
            }
        }
    }

    private func labelPreferringResult(for translating: Translating, targetLocale: SupportedLocale) -> some View {
        Group {
            let hideProgressCircle = error != nil
            switch translating {
            case let .updatePost(.raw(raw)):
                HStack {
                    UpdatePostTranslationLabel(data: raw, targetLocale: targetLocale)
                    if !hideProgressCircle {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                    }
                }

            case let .updatePostHeader(post: .raw(raw), _):
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HeaderLabel(data: raw.header)
                        Text("Translating to \(targetLocale.name)...")
                            .opacity(0.5)
                    }
                    if !hideProgressCircle {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                    }
                }

            case let .updatePost(.cooked(change)):
                UpdatePostTranslationLabel(data: change.after)

            case let .updatePostHeader(.cooked(change), _):
                HeaderTranslationLabel(before: change.before.header, after: change.after.header)
            }
        }
    }
}

private struct UpdatePostTranslationLabel: View {
    let data: UpdatePost
    let targetLocale: SupportedLocale?

    init(data: UpdatePost, targetLocale: SupportedLocale? = nil) {
        self.data = data
        self.targetLocale = targetLocale
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(data.title)
                    .font(.title3)
                if targetLocale == nil {
                    HeaderLabel(data: data.header)
                }
            }
            if let targetLocale {
                Text("Translating to \(targetLocale.name)...")
                    .opacity(0.5)
            } else {
                Text(data.summary)
            }
        }
    }
}

private struct HeaderLabel: View {
    let data: String

    var body: some View {
        Text(data)
            .colorInvert()
            .padding(.horizontal, 6)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .foregroundStyle(.foreground)
            }
            .layoutPriority(1)
    }
}

private struct HeaderTranslationLabel: View {
    let before: String
    let after: String

    var body: some View {
        HStack(spacing: 6) {
            HeaderLabel(data: before)
            Image(systemName: "arrow.forward")
            HeaderLabel(data: after)
        }
    }
}

private struct ReviewPage: View {
    let data: [Translating]
    let onEdit: (Translating) -> Void
    @State private var editing: Translating? = nil

    var body: some View {
        Form {
            Section("Would you like to create the these \(data.count) posts?") {
                ForEach(data) { post in
                    Button {
                        editing = post
                    } label: {
                        getLabel(for: post)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editing) { draft in
            NavigationStack {
                switch draft {
                case let .updatePost(.cooked(change)):
                    UpdatePostSheetContent(model: change.after, onSave: { newModel in
                        onEdit(.updatePost(.cooked(.init(before: change.before, after: newModel))))
                        editing = nil
                    })
                case let .updatePostHeader(.cooked(change), h):
                    UpdatePostSheetContent(model: change.after, onSave: { newModel in
                        onEdit(.updatePostHeader(post: .cooked(.init(before: change.before, after: newModel)), existingHeaders: h))
                        editing = nil
                    })
                default:
                    Text("Not implemented")
                }
            }
        }
    }

    private func getLabel(for value: Translating) -> some View {
        Group {
            switch value {
            case let .updatePost(.cooked(post)), let .updatePostHeader(.cooked(post), _):
                UpdatePostTranslationLabel(data: post.after, targetLocale: nil)
            default:
                Text("Not supported")
            }
        }
    }

    private struct UpdatePostSheetContent: View {
        let model: UpdatePost
        let onSave: (UpdatePost) -> Void

        @StateObject private var viewModel = UpdatePostViewModel()
        @StateObject private var templateCache = TemplateCache()
        @State var cache: CachedUpdatePost? = nil

        var body: some View {
            Group {
                switch viewModel.state {
                case let .editor(editor):
                    if let cache {
                        UpdatePostEditor(editor: editor, model: cache, takePhoto: viewModel.openCameraForCapture, onSave: {
                            onSave(.init(cache: cache))
                        })
                        .transition(.flipFromTop)
                        .environmentObject(templateCache)
                        .onAppear {
                            editor.copyFrom(model: cache)
                        }
                    } else {
                        ProgressView()
                    }
                case let .camera(onCapture, onCancel):
                    #if os(iOS)
                        CameraView { captured in
                            switch captured {
                            case .none:
                                onCancel()
                            case let .some(image):
                                onCapture(image.cgImage!)
                            }
                        }
                        .ignoresSafeArea()
                        .transition(.flipFromBottom)
                        .navigationBarBackButtonHidden()
                    #else
                        Text("This platform does not support photo captrue")
                    #endif
                }
            }
            .onAppear {
                cache = .init(from: model)
            }
        }
    }
}

#Preview {
    @Previewable @State var targetLocales = Set<SupportedLocale>()
    StartPage(source: .en, target: $targetLocales)
}

#Preview {
    UpdatePostTranslationLabel(data: .init(id: 0, created: .now, header: "Status update", title: "Example title", summary: "Example content here", mask: .clover, locale: .en, trashed: false, cover: .none))
    UpdatePostTranslationLabel(data: .init(id: 0, created: .now, header: "Status update", title: "Example title", summary: "Example content here", mask: .clover, locale: .en, trashed: false, cover: .none), targetLocale: .en)
}

#Preview {
    let raw: UpdatePost = .init(id: 0, created: .now, header: "Status update", title: "Eheh", summary: "Wahaa", mask: .clover, locale: .en, trashed: false, cover: .none)
    TranslatingPage(
        translating: .updatePost(.raw(raw)),
        targetLocales: [.zh, .zhTw], service: WaitingService(), drafts: Binding.constant([
            .updatePost(.cooked(Change(before: raw, after: .init(id: 0, created: .now, header: "状态更新", title: "嘻嘻", summary: "哇哈哈", mask: .clover, locale: .zh, trashed: false, cover: .none)))),
            .updatePost(.raw(raw)),
        ]),
        done: .constant(false)
    )
}

#Preview {
    let raw: UpdatePost = .init(id: 0, created: .now, header: "Status update", title: "Eheh", summary: "Wahaa", mask: .clover, locale: .en, trashed: false, cover: .none)
    TranslatingPage(
        translating: .updatePost(.raw(raw)),
        targetLocales: [.zh, .zhTw],
        service: ThrowingService(), drafts: Binding.constant([
            .updatePost(.raw(raw)),
        ]),
        done: .constant(false)
    )
}

#Preview {
    let raw: UpdatePost = .init(id: 0, created: .now, header: "Status update", title: "Eheh", summary: "Wahaa", mask: .clover, locale: .en, trashed: false, cover: .none)
    let cooked: UpdatePost = .init(id: 0, created: .now, header: "状态更新", title: "嘻嘻", summary: "哇哈哈", mask: .clover, locale: .zh, trashed: false, cover: .none)
    ReviewPage(data: [.updatePost(.cooked(.init(before: raw, after: cooked)))]) { _ in
        print("on update")
    }
}

private class WaitingService: ChatCompletion {
    func getChatResponse(history: some Sequence<ChatMessage>) -> AsyncThrowingStream<AssistantMessagePart, Failure> {
        let count = Atomic(0)
        return AsyncThrowingStream(unfolding: {
            try? await Task.sleep(for: .seconds(1))
            let c = count.wrappingAdd(1, ordering: .acquiringAndReleasing).newValue
            if c % 5 != 0 {
                return .reasoning("thinking... ")
            } else {
                return .reasoning("\n")
            }
        })
    }

    typealias Failure = any Error

    typealias Response = AsyncThrowingStream<AssistantMessagePart, Failure>
}

private class ThrowingService: ChatCompletion {
    func getChatResponse(history: some Sequence<ChatMessage>) -> AsyncThrowingStream<AssistantMessagePart, Failure> {
        return AsyncThrowingStream {
            throw CancellationError()
        }
    }

    typealias Failure = any Error

    typealias Response = AsyncThrowingStream<AssistantMessagePart, Failure>
}
