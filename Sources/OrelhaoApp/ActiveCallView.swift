import SwiftUI
import SIPCore

/// Substitui o dialer durante uma chamada: avatar, estado/timer e controles.
struct ActiveCallView: View {
    @Environment(CallStore.self) private var store
    let call: CallInfo

    @State private var showDTMF = false

    private var remoteName: String {
        SIPFormatting.displayName(from: call.remoteURI)
    }

    private var isEnded: Bool { call.state == .disconnected }
    private var isConfirmed: Bool { call.state == .confirmed }

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 20)

            CallAvatar(name: remoteName, size: 104)
                .scaleEffect(isEnded ? 0.9 : 1)
                .opacity(isEnded ? 0.6 : 1)
                .animation(.spring(duration: 0.35), value: isEnded)

            VStack(spacing: 4) {
                Text(remoteName)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                Text(call.remoteURI)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 28)

            statusLine
                .frame(height: 30)

            Spacer()

            controls
                .opacity(isEnded ? 0 : 1)
                .animation(.easeOut(duration: 0.2), value: isEnded)

            Spacer(minLength: 28)
        }
        .sheet(isPresented: $showDTMF) {
            DTMFSheet()
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch call.state {
        case .calling:
            statusText("chamando…")
        case .early:
            statusText("tocando…")
        case .connecting:
            statusText("conectando…")
        case .incoming:
            statusText("chamada recebida…")
        case .confirmed:
            HStack(spacing: 8) {
                if call.mediaActive {
                    Image(systemName: "waveform")
                        .font(.callout)
                        .foregroundStyle(Theme.callGreen)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                }
                if let start = call.startedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(SIPFormatting.elapsed(since: start, now: context.date))
                            .font(.system(.title3, design: .rounded).weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                } else {
                    statusText("em chamada")
                }
            }
        case .disconnected:
            Text("chamada encerrada")
                .font(.callout.weight(.medium))
                .foregroundStyle(Theme.dangerRed)
        case .idle:
            statusText(" ")
        }
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    private var controls: some View {
        HStack(spacing: 32) {
            CircleControlButton(
                systemImage: store.isMuted ? "mic.slash.fill" : "mic.fill",
                label: "mudo",
                fill: store.isMuted ? .white : nil,
                iconColor: store.isMuted ? .black : .primary,
                isDisabled: !isConfirmed
            ) {
                Task { await store.toggleMute() }
            }

            CircleControlButton(
                systemImage: "circle.grid.3x3.fill",
                label: "teclado",
                isDisabled: !isConfirmed
            ) {
                showDTMF = true
            }

            CircleControlButton(
                systemImage: "phone.down.fill",
                label: "encerrar",
                fill: Theme.dangerRed,
                iconColor: .white
            ) {
                Task { await store.hangup() }
            }
        }
    }
}
