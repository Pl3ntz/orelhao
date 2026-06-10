import SwiftUI
import SIPCore

/// Sheet com keypad DTMF: cada tecla envia o dígito imediatamente.
struct DTMFSheet: View {
    @Environment(CallStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var sentDigits = ""

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Teclado DTMF")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Fechar")
            }

            Text(sentDigits.isEmpty ? " " : sentDigits)
                .font(.system(size: 24, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity)
                .frame(height: 32)

            KeypadView(keySize: 62) { digit in
                sentDigits += digit
                Task { await store.sendDTMF(digit) }
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}
