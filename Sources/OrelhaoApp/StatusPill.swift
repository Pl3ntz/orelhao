import SwiftUI
import SIPCore

/// Pill de status de registro: cinza/amarelo pulsante/verde/vermelho.
struct StatusPill: View {
    let state: RegistrationState
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .opacity(isRegistering && pulsing ? 0.25 : 1)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.35)))
        .help(helpText)
        .onAppear { startPulseIfNeeded() }
        .onChange(of: state) { startPulseIfNeeded() }
    }

    private var isRegistering: Bool { state == .registering }

    private var color: Color {
        switch state {
        case .unregistered: .gray
        case .registering: Theme.warningAmber
        case .registered: Theme.callGreen
        case .failed: Theme.dangerRed
        }
    }

    private var label: String {
        switch state {
        case .unregistered: "desconectado"
        case .registering: "registrando…"
        case .registered: "registrado"
        case .failed(let code, _): "falhou (\(code))"
        }
    }

    private var helpText: String {
        switch state {
        case .failed(let code, let reason): "Registro falhou — \(code): \(reason)"
        case .registered: "Conta registrada no servidor SIP"
        case .registering: "Registrando no servidor SIP…"
        case .unregistered: "Sem registro ativo"
        }
    }

    private func startPulseIfNeeded() {
        guard isRegistering else {
            pulsing = false
            return
        }
        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
            pulsing = true
        }
    }
}
