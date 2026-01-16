import Foundation
import OpenAPIClient
import SDWebImageSwiftUI
import SwiftData
import SwiftUI

struct UpdatePostView: View {
    @State private var titleBuffer = ""
    @State private var summaryBuffer = ""
    @State private var maskBuffer: OpenAPIClient.Shape = .clover
    @State private var isEditing = false

    let model: CachedUpdatePost
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ShapeSelect(shape: $maskBuffer)
            #if os(macOS)
            .padding(.top)
            #endif
            TextField("Tweet", text: $summaryBuffer)
                .textFieldStyle(.plain)
                .frame(minHeight: 200, alignment: .top)
                .padding(.horizontal)
        }
        .task(id: model) {
            titleBuffer = model.title
            summaryBuffer = model.summary
            maskBuffer = model.mask
            isEditing = false
        }
        .task {
            await withTaskGroup { tg in
                OpenAPIClient.Shape.allCases.forEach { _ in
                    tg.addTask {
                    }
                }
            }
        }
        .onChange(of: titleBuffer, { _, newValue in
            if newValue != model.title {
                isEditing = true
            }
        })
        .onChange(of: summaryBuffer, { _, newValue in
            if newValue != model.summary {
                isEditing = true
            }
        })
        .onChange(of: maskBuffer, { _, newValue in
            if newValue != model.mask {
                isEditing = true
            }
        })
        .toolbar {
            #if os(macOS)
                ToolbarItem(placement: .navigation) {
                    TextField("New post", text: $titleBuffer)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .background()
                        .padding(.leading, 8)
                }
                .sharedBackgroundVisibility(.hidden)
            #endif
            if isEditing {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        model.title = titleBuffer
                        model.summary = summaryBuffer
                        onSave()
                        isEditing = false
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
        .navigationTitle($titleBuffer)
        .toolbarTitleDisplayMode(.inline)
        #endif
        .frame(maxHeight: .infinity, alignment: .top)
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
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    NavigationStack {
        UpdatePostView(model: .init()) {
        }
    }
}
