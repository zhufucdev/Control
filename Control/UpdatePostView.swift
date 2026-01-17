import Combine
import Foundation
import ImageIO
import OpenAPIClient
import PhotosUI
import SDWebImageSwiftUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct UpdatePostView: View {
    let model: CachedUpdatePost
    let onSave: () -> Void

    @StateObject private var viewModel = UpdatePostViewModel()
    @StateObject private var templateCache = TemplateCache()

    var body: some View {
        Group {
            switch viewModel.state {
            case let .editor(editor):
                Editor(editor: editor, model: model, takePhoto: viewModel.openCameraForCapture, onSave: onSave)
                    .transition(.flipFromTop)
                    .environmentObject(templateCache)
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
            viewModel.editor.copyFrom(model: model)
        }
        .onChange(of: model, { _, newValue in
            viewModel.editor.copyFrom(model: newValue)
        })
    }
}

fileprivate final class UpdatePostViewModel: ObservableObject {
    @Published private(set) var state: ViewState
    @Published var editor: EditorViewModel

    init() {
        let editor = EditorViewModel()
        self.editor = editor
        state = .editor(model: editor)
    }

    func openCameraForCapture() {
        withAnimation {
            state = .camera(onCapture: { image in
                do {
                    let data = try Data(cgImage: image)
                    try self.editor.attachImage(filename: "IMG_\(Int.random(in: 10000 ... 99999)).jpeg", data: data)
                } catch {
                    print("Failed to attach cover image: \(error)")
                }
                self.state = .editor(model: self.editor)
            }, onCancel: {
                self.state = .editor(model: self.editor)
            })
        }
    }
}

fileprivate enum ViewState {
    case editor(model: EditorViewModel)
    case camera(onCapture: (CGImage) -> Void, onCancel: () -> Void)
}

fileprivate struct Editor: View {
    @StateObject var editor: EditorViewModel
    let model: CachedUpdatePost
    let takePhoto: () -> Void
    let onSave: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ShapeSelect(shape: $editor.mask)
                #if os(macOS)
                    .padding(.top)
                #endif
                TextField("Header", text: $editor.header)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                TextField("Tweet", text: $editor.summary)
                    .textFieldStyle(.plain)
                    .frame(minHeight: 100, alignment: .top)
                    .padding(.horizontal)
                UpdatePostPreview(editor: editor)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .onAppear {
            editor.copyFrom(model: model)
        }
        .onChange(of: model, { _, newValue in
            editor.copyFrom(model: newValue)
        })
        .toolbar {
            #if os(macOS)
                ToolbarItem(placement: .navigation) {
                    TextField("New post", text: $editor.title)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .background()
                        .padding(.leading, 8)
                }
                .sharedBackgroundVisibility(.hidden)
            #endif
            #if os(macOS)
                ToolbarItemGroup(placement: .primaryAction) {
                    attacheImageToolbarItems
                }
            #else
                ToolbarItemGroup(placement: .bottomBar) {
                    attacheImageToolbarItems
                }
            #endif

            if editor.isEditing {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        #if os(iOS)
                            // hide keyboard
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        #endif
                        editor.commit(to: model)
                        onSave()
                        withAnimation {
                            editor.isEditing = false
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .toolbar(removing: .title)
        .toolbar {
            Spacer().frame(maxWidth: .infinity) // weird that macOS has it
        }
        #elseif os(iOS)
        .navigationTitle($editor.title)
        .toolbarTitleDisplayMode(.inline)
        #endif
        .photosPicker(
            isPresented: $editor.isPickingPhotos,
            selection: $editor.photoSelection,
            matching: .images,
            preferredItemEncoding: .current,
            photoLibrary: .shared()
        )
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var attacheImageToolbarItems: some View {
        Group {
            Button("From Photos", systemImage: "photo.on.rectangle.angled") {
                editor.isPickingPhotos = true
            }

            #if os(iOS)
                Button("Take photos", systemImage: "camera", action: takePhoto)
            #endif

            if editor.cover != nil {
                Button("Clear image attachement", systemImage: "clear") {
                    editor.cover = nil
                }
            }
        }
    }
}

fileprivate final class EditorViewModel: ObservableObject {
    private var isCopying = false

    @Published var isEditing = false
    @Published var edition = 0

    @Published var header = "" {
        didSet {
            notifyEditing()
        }
    }

    @Published var title = "" {
        didSet {
            notifyEditing()
        }
    }

    @Published var summary = "" {
        didSet {
            notifyEditing()
        }
    }

    @Published var mask: OpenAPIClient.Shape = .clover {
        didSet {
            notifyEditing()
        }
    }

    @Published var isPickingPhotos: Bool = false

    @Published var photoSelection: PhotosPickerItem? = nil {
        didSet {
            notifyEditing()
            if let photoSelection {
                Task {
                    do {
                        if let image = try await photoSelection.loadTransferable(type: DataUrl.self) {
                            try attachImage(filename: image.url.lastPathComponent, data: try Data(contentsOf: image.url))
                        } else {
                            print("No suitable conversion found from PhotosPickerItem to DataUrl")
                        }
                    } catch {
                        print("Error loading photo selection: \(error)")
                    }
                }
            }
        }
    }

    @Published var cover: URL? = nil {
        didSet {
            notifyEditing()
        }
    }

    @Published var alt: String = "" {
        didSet {
            notifyEditing()
        }
    }

    func notifyEditing() {
        if !isCopying {
            isEditing = true
            edition += 1
        }
    }

    func copyFrom(model: CachedUpdatePost) {
        isCopying = true
        header = model.header
        title = model.title
        summary = model.summary
        mask = model.mask
        if let cover = model.cover {
            self.cover = URL(string: cover.image)
            alt = cover.alt
        } else {
            cover = nil
            alt = ""
        }
        isCopying = false
        isEditing = false
        edition += 1
    }

    func commit(to: CachedUpdatePost) {
        to.header = header
        to.title = title
        to.summary = summary
        to.mask = mask
        if let originalCover = to.cover, cover == nil {
            // remove garbage
            if let url = URL(string: originalCover.image), url.isFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        to.cover = .init(image: cover?.absoluteString ?? "", alt: alt)
    }

    func attachImage(filename: String, data: Data) throws {
        let container = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appending(component: UUID().uuidString, directoryHint: .isDirectory)
        let resultingFile = container.appending(component: filename, directoryHint: .notDirectory)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        try data.write(to: resultingFile)
        cover = resultingFile
    }
}

struct DataUrl: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .data) { data in
            SentTransferredFile(data.url)
        } importing: { received in
            Self(url: received.file)
        }
    }
}

fileprivate struct ShapeSelect: View {
    @Binding var shape: OpenAPIClient.Shape
    @Environment(\.mainSiteUrl) var mainSiteUrl
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(OpenAPIClient.Shape.allCases, id: \.rawValue) { shape in
                    Button {
                        self.shape = shape
                    } label: {
                        HStack {
                            if self.shape == shape {
                                Image(systemName: "checkmark")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 14)
                                    .padding(5)
                            } else {
                                WebImage(url: URL(string: mainSiteUrl)?.appending(components: "shape", shape.rawValue)) { image in
                                    image.resizable().aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 24, height: 24)
                            }
                            Text(shape.rawValue)
                        }
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.foreground)
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
    }
}

fileprivate struct UpdatePostPreview: View {
    @Environment(\.mainSiteUrl) var mainSiteUrl
    @EnvironmentObject var templateCahce: TemplateCache

    @StateObject var editor: EditorViewModel
    @State private var state: Result<WebPage, any Error>? = nil

    var body: some View {
        Group {
            switch state {
            case let .success(page):
                WebView(page)
                    .frame(maxWidth: .infinity, minHeight: 400) // FIXME: adaptative height
                    .disabled(true)
            case let .failure(failure):
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(Image(systemName: "photo.trianglebadge.exclamationmark")) Failed to load preview")
                        .font(.title2)
                    Text(failure.localizedDescription)
                }
                .padding()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: .init(lineWidth: 1)).foregroundStyle(.separator))
            case nil:
                VStack {
                    ProgressView()
                    Text("Loading preview...")
                }
                .padding(36)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: .init(lineWidth: 1)).foregroundStyle(.separator))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(.horizontal)
        .task(id: editor.edition) {
            do {
                let data = if let t = templateCahce.source { t } else { try await DefaultAPI.updateTemplateGet() }
                templateCahce.source = data

                let processedData = try preprocessHtml(content: data)
                let page = if let p = templateCahce.webPage { p } else {
                    {
                        var webpageConfig = WebPage.Configuration()
                        webpageConfig.websiteDataStore = .init(forIdentifier: UUID(uuidString: "8C885417-C368-463C-9154-43DB2B83CAB0")!)
                        webpageConfig.urlSchemeHandlers = [
                            URLScheme("kfile")!: FileURLSchemaHandler(),
                        ]
                        return WebPage(configuration: webpageConfig)
                    }()
                }
                templateCahce.webPage = page

                page.load(Data(processedData.utf8), mimeType: "text/html", characterEncoding: .utf8, baseURL: URL(string: "\(OpenAPIClientAPIConfiguration.shared.basePath)/api/update/template")!)
                #if DEBUG
                    page.isInspectable = true
                #endif
                state = .success(page)
            } catch {
                state = .failure(error)
            }
        }
    }

    private func preprocessHtml(content: String) throws -> String {
        let maskUrl = URL(string: mainSiteUrl)!.appending(components: "shape", editor.mask.rawValue).absoluteString
        let coverUrl = editor.cover?.absoluteString.replacingOccurrences(of: "file://", with: "kfile://") ?? ""

        return content.replacingOccurrences(of: "${header.leading}", with: editor.header)
            .replacingOccurrences(of: "${header.tailing}", with: "Jan. 17th")
            .replacingOccurrences(of: "${title}", with: editor.title)
            .replacingOccurrences(of: "${summary}", with: editor.summary)
            .replacingOccurrences(of: "${cover.alt}", with: editor.alt)
            .replacingOccurrences(of: "${cover.src}", with: coverUrl)
            .replacingOccurrences(of: "${mask}", with: "url(\(maskUrl))")
    }
}

fileprivate class TemplateCache: ObservableObject {
    var source: String?
    var webPage: WebPage?
}

#Preview {
    NavigationStack {
        UpdatePostView(model: .init()) {
        }
    }
}
