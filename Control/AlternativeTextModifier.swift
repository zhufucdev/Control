import AsyncAlgorithms
import Foundation
import SwiftUI

struct AlternativeTextModifier<ImageID: Hashable>: ViewModifier {
    @Binding var captioning: CaptioningImage<ImageID>?
    @State private var buffer = ""
    @State private var isGenerating = false
    let initialText: String
    let updateText: (String) -> Void
    let onCancel: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .sheet(item: $captioning) { captioning in
                NavigationStack {
                    AltTextSheetContent(image: captioning.image, service: OpenAIService.shared, caption: $buffer)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel", systemImage: "xmark") {
                                    onCancel?()
                                    self.captioning = nil
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Submit", systemImage: "checkmark") {
                                    updateText(buffer)
                                    self.captioning = nil
                                }
                                .disabled(buffer.isEmpty)
                            }
                        }
                        .navigationTitle("Add alt text")
                }
            }
            .onChange(of: initialText) { _, _ in
                buffer = initialText
            }
    }
}

struct CaptioningImage<ID: Hashable>: Identifiable<ID> {
    let id: ID
    let image: CIImage
}

private struct AltTextSheetContent<Service: ChatCompletion & Sendable>: View {
    let image: CIImage
    let broadcast: BroadcastChatCompletion<Service>
    @Binding var caption: String

    init(image: CIImage, service: Service, caption: Binding<String>) {
        self.image = image
        broadcast = BroadcastChatCompletion(from: service)
        _caption = caption
    }

    @State private var response = ""
    @State private var isGenerating = false
    @State private var generationError: (any Error)? = nil

    var body: some View {
        ScrollView {
            if !isGenerating {
                TextField("Describe this image in brief", text: $caption, axis: .vertical)
                    .lineLimit(3 ... .max)
                    .padding(16)
            } else {
                Text(response.isEmpty ? String(localized: "Waiting for initial output...") : response)
                    .opacity(0.5)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        isGenerating = false
                        caption = response
                    }
            }
        }
        .alert("Generation failed", item: $generationError) { err in
            Text(err.localizedDescription)
            Button("OK", role: .confirm) {
                generationError = nil
            }
        }
        .toolbar {
            if isGenerating {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                Button("Generate", systemImage: "wand.and.sparkles") {
                    isGenerating = true
                }
            }
        }
        .task {
            while true {
                do {
                    for try await chunk in self.broadcast.getBroadcastChatResponse() {
                        switch chunk {
                        case let .reasoning(string):
                            response += string
                        case let .text(string):
                            response += string
                        }
                    }
                } catch is CancellationError {
                    break
                } catch {
                    print("AltTextSheetContent, broadcast error \(error)")
                }
            }
        }
        .task(id: isGenerating) {
            if !isGenerating {
                return
            }
            do {
                try await generateCaption()
            } catch {
                generationError = error
            }
            isGenerating = false
        }
    }

    private func generateCaption() async throws {
        caption = try await image.getCaption(service: broadcast)
    }
}

extension View {
    func altTextAlert<ImageID: Hashable>(initialText: String, captioning image: Binding<CaptioningImage<ImageID>?>, updateText: @escaping (String) -> Void, onCancel: (() -> Void)? = nil) -> some View {
        modifier(AlternativeTextModifier<ImageID>(captioning: image, initialText: initialText, updateText: updateText, onCancel: onCancel))
    }
}
