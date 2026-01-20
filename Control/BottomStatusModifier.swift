import SwiftUI

struct BottomStatusModifier<C: View>: ViewModifier {
    @ViewBuilder let body: () -> C
    let bodyHeight: Double
    let gradientPadding: Double

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                body()
                    .frame(height: bodyHeight)
            }
    }
}

extension View {
    func bottomStatus<C: View>(height: Double, padding: Double = 40, body: @escaping () -> C) -> some View {
        modifier(BottomStatusModifier(body: body, bodyHeight: height, gradientPadding: padding))
    }
}

