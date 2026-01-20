import Foundation
import SwiftUI

struct AlternativeTextModifier: ViewModifier {
    @Binding var isPresented: Bool
    @State private var buffer = ""
    let initialText: String
    let updateText: (String) -> Void
    let onCancel: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .alert("Alternative text", isPresented: $isPresented) {
                TextField("Describe this image in brief", text: $buffer)
                Button(role: .cancel) {
                    isPresented = false
                    onCancel?()
                }
                Button(role: .confirm) {
                    isPresented = false
                    updateText(buffer)
                }
                .disabled(buffer.isEmpty)
            }
            .onChange(of: initialText) { _, newValue in
                buffer = initialText
            }
    }
}

extension View {
    func altTextAlert(isPresented: Binding<Bool>, initialText: String, updateText: @escaping (String) -> Void, onCancel: (() -> Void)? = nil) -> some View {
        self.modifier(AlternativeTextModifier(isPresented: isPresented, initialText: initialText, updateText: updateText, onCancel: onCancel))
    }
}
