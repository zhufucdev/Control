import OpenAPIClient
import SwiftData
import SwiftUI
import Combine

struct PullStateView: View {
    let state: PullState
    let onRetry: () -> Void
    @State private var error: (any Error)?
    var body: some View {
        switch state {
        case .pulling:
            VStack {
                ProgressView()
                    .progressViewStyle(.linear)
                Text("Pulling posts...")
            }
        case let .error(error):
            HStack {
                Text("Failed to pull...")
                    .alert("Could not pull posts from server", isPresented: Binding(get: {
                        self.error != nil
                    }, set: { show in
                        if !show {
                            self.error = nil
                        }
                    }), actions: {
                        Button(role: .cancel) {
                            self.error = nil
                        }
                        Button("Retry") {
                            self.error = nil
                            onRetry()
                        }
                    }, message: {
                        if let error = self.error as? ErrorResponse,
                           case let .error(_, body, response, _) = error,
                           let body, response?.mimeType == "plain/text" {
                            Text(String(data: body, encoding: .utf8)!)
                        } else {
                            Text(error.localizedDescription)
                        }
                    })
                Button("details") {
                    self.error = error
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
    }
}

enum PullState {
    case pulling
    case error(any Error)
}

struct PushStateView: View {
    let state: PushSynchronizeState
    var body: some View {
        Group {
            switch state {
            case let .uploadingImage(progress):
                VStack {
                    ProgressViewForNSProgress(value: progress)
                    Text("Uploading image...")
                }
            case .updatingContent:
                VStack {
                    ProgressView()
                        .progressViewStyle(.linear)
                    Text("Updating post...")
                }
            case .creatingContent:
                VStack {
                    ProgressView()
                        .progressViewStyle(.linear)
                    Text("Creating post...")
                }
            }
        }
    }
}

fileprivate struct ProgressViewForNSProgress: View {
    let value: Progress
    @State private var fractionCompleted: Double = 0
    @State private var subscription: NSKeyValueObservation? = nil
    var body: some View {
        ProgressView(value: fractionCompleted)
            .onAppear {
                fractionCompleted = value.fractionCompleted
                subscription = value.observe(\.fractionCompleted) { _, change in
                    if let newValue = change.newValue {
                        DispatchQueue.main.async {
                            fractionCompleted = newValue
                        }
                    }
                }
            }
            .onDisappear {
                subscription?.invalidate()
            }
    }
}
