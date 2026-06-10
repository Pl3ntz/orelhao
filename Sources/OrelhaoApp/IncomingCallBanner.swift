import SwiftUI
import SIPCore

/// Banner destacado de chamada entrante: atender (verde) / recusar (vermelho).
struct IncomingCallBanner: View {
    @Environment(CallStore.self) private var store
    let call: CallInfo

    private var remoteName: String {
        SIPFormatting.displayName(from: call.remoteURI)
    }

    var body: some View {
        HStack(spacing: 14) {
            CallAvatar(name: remoteName, size: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(remoteName)
                    .font(.headline)
                    .lineLimit(1)
                Text("Chamada recebida")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            CircleControlButton(
                systemImage: "phone.down.fill",
                size: 44,
                fill: Theme.dangerRed,
                iconColor: .white
            ) {
                Task { await store.decline() }
            }
            .help("Recusar")

            CircleControlButton(
                systemImage: "phone.fill",
                size: 44,
                fill: Theme.callGreen,
                iconColor: .white
            ) {
                Task { await store.answer() }
            }
            .help("Atender")
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Theme.callGreen.opacity(0.35))
        )
        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
        .padding(.horizontal, 18)
    }
}
