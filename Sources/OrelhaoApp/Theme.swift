import SwiftUI

/// Identidade visual do Orelhao — dark-first, adaptativa.
enum Theme {
    static let windowSize = CGSize(width: 420, height: 720)

    static let callGreen = Color(red: 0.16, green: 0.74, blue: 0.42)
    static let dangerRed = Color(red: 0.93, green: 0.28, blue: 0.31)
    static let warningAmber = Color(red: 0.95, green: 0.72, blue: 0.20)

    static let digitFont = Font.system(size: 34, weight: .light, design: .rounded)
    static let keyFont = Font.system(size: 26, weight: .regular, design: .rounded)
    static let keyLettersFont = Font.system(size: 9, weight: .semibold, design: .rounded)
}

/// Fundo da janela: gradiente sutil que respeita light/dark.
struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .underPageBackgroundColor)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            RadialGradient(
                colors: [Theme.callGreen.opacity(0.10), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
        )
        .ignoresSafeArea()
    }
}

/// Estilo de botão com spring discreto ao pressionar.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}
