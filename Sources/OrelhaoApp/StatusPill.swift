import SwiftUI
import SIPCore

/// Registration status pill: gray / pulsing amber / green / red.
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
        case .unregistered: "offline"
        case .registering: "registering…"
        case .registered: "registered"
        case .failed(let code, _): "failed (\(code))"
        }
    }

    private var helpText: String {
        switch state {
        case .failed(let code, let reason): "Registration failed — \(code): \(reason)"
        case .registered: "Account registered with the SIP server"
        case .registering: "Registering with the SIP server…"
        case .unregistered: "No active registration"
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
