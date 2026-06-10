import SwiftUI
import SIPCore

/// Main screen: editable display + keypad + call button.
struct DialerView: View {
    @Environment(CallStore.self) private var store
    let account: SIPAccount

    @State private var number = ""
    @FocusState private var displayFocused: Bool

    private var trimmedNumber: String {
        number.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canDial: Bool { !trimmedNumber.isEmpty }

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 4)
            display
            KeypadView { number += $0 }
            callButton
            Spacer(minLength: 8)
        }
        .onAppear { displayFocused = true }
    }

    private var display: some View {
        ZStack {
            TextField("Enter a number", text: $number)
                .textFieldStyle(.plain)
                .font(Theme.digitFont)
                .multilineTextAlignment(.center)
                .focused($displayFocused)
                .onSubmit(dial)
                .padding(.horizontal, 56)

            HStack {
                Spacer()
                if !number.isEmpty {
                    Button {
                        number = String(number.dropLast())
                    } label: {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(.secondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScaleStyle())
                    .help("Delete last digit")
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.trailing, 18)
        }
        .frame(height: 52)
        .animation(.spring(duration: 0.25), value: number.isEmpty)
    }

    private var callButton: some View {
        Button(action: dial) {
            Image(systemName: "phone.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(
                    Circle().fill(canDial ? Theme.callGreen : Color.gray.opacity(0.35))
                )
                .shadow(
                    color: Theme.callGreen.opacity(canDial ? 0.45 : 0),
                    radius: 14, y: 5
                )
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!canDial)
        .help("Call")
    }

    private func dial() {
        guard canDial else { return }
        let destination = trimmedNumber
        number = ""
        Task { await store.call(destination, account: account) }
    }
}
