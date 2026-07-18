import Foundation
import SwiftUI
#if os(macOS)
    import QuickLook
#elseif os(iOS)
    import WebKit
#endif

struct PreviewImageModifier: ViewModifier {
    @Binding var url: URL?
    let altText: String

    func body(content: Content) -> some View {
        content
        #if os(macOS)
        .quickLookPreview($url)
        #elseif os(iOS)
        .fullScreenCover(isPresented: Binding(get: {
            url != nil
        }, set: { present in
            if !present {
                url = nil
            }
        })) {
            webviewPreview
                .statusBarHidden()
        }
        #endif
    }

    #if os(iOS)
        @State var webPage = WebPage()
        var webviewPreview: some View {
            NavigationStack {
                Group {
                    WebView(webPage)
                        .webViewContentBackground(.hidden)
                }.toolbar {
                    Button(role: .close) {
                        url = nil
                    }
                }
                .ignoresSafeArea(.all)
            }
            .task(id: url) {
                guard let url else {
                    print("preview: url is nil")
                    return
                }
                webPage.load(html: """
                <html>
                <body>
                <img src="\(url.absoluteString)" />
                </body>
                <style>
                body {
                    display: flex;
                    align-items: center;
                }
                img {
                    width: 100%;
                }
                </style>
                </html>
                """)
            }
        }
    #endif
}

extension View {
    func previewingImage(_ url: Binding<URL?>, altText: String) -> some View {
        modifier(PreviewImageModifier(url: url, altText: altText))
    }
}
