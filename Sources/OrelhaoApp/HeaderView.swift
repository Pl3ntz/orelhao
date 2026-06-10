import SwiftUI
import SIPCore

/// Header: nome da conta + pill de status + engrenagem de settings.
struct HeaderView: View {
    @Environment(CallStore.self) private var store
    let accountName: String
    let onSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(accountName)
                    .font(.headline)
                    .lineLimit(1)
                StatusPill(state: store.registration)
            }

            Spacer()

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.06)))
                    .contentShape(Circle())
            }
            .buttonStyle(PressScaleStyle())
            .help("Configurações da conta")
        }
    }
}
