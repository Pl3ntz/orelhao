import SwiftUI

/// Phone keypad key (digit + ABC letters).
struct KeypadKey: Identifiable {
    let digit: String
    let letters: String
    var id: String { digit }
}

/// Reusable 4×3 keypad (dialer and DTMF). Holds no state of its own.
struct KeypadView: View {
    var keySize: CGFloat = 72
    let onKey: (String) -> Void

    private static let keys: [KeypadKey] = [
        KeypadKey(digit: "1", letters: ""),
        KeypadKey(digit: "2", letters: "ABC"),
        KeypadKey(digit: "3", letters: "DEF"),
        KeypadKey(digit: "4", letters: "GHI"),
        KeypadKey(digit: "5", letters: "JKL"),
        KeypadKey(digit: "6", letters: "MNO"),
        KeypadKey(digit: "7", letters: "PQRS"),
        KeypadKey(digit: "8", letters: "TUV"),
        KeypadKey(digit: "9", letters: "WXYZ"),
        KeypadKey(digit: "*", letters: ""),
        KeypadKey(digit: "0", letters: "+"),
        KeypadKey(digit: "#", letters: "")
    ]

    var body: some View {
        let columns = Array(
            repeating: GridItem(.fixed(keySize), spacing: 20),
            count: 3
        )
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Self.keys) { key in
                KeypadButton(key: key, size: keySize) { onKey(key.digit) }
            }
        }
    }
}

private struct KeypadButton: View {
    let key: KeypadKey
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(key.digit)
                    .font(Theme.keyFont)
                    .foregroundStyle(.primary)
                Text(key.letters.isEmpty ? " " : key.letters)
                    .font(Theme.keyLettersFont)
                    .foregroundStyle(.secondary)
                    .kerning(1.2)
            }
            .frame(width: size, height: size)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.06)))
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
    }
}
