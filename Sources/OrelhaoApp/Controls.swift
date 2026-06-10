import SwiftUI

/// Circular call-control button (mute, DTMF, hangup, answer…).
struct CircleControlButton: View {
    let systemImage: String
    var label: String? = nil
    var size: CGFloat = 60
    var fill: Color? = nil
    var iconColor: Color = .primary
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.34, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: size, height: size)
                    .background {
                        if let fill {
                            Circle().fill(fill)
                                .shadow(color: fill.opacity(0.45), radius: 10, y: 4)
                        } else {
                            Circle().fill(.ultraThinMaterial)
                        }
                    }
                    .overlay(Circle().strokeBorder(.white.opacity(0.08)))
                    .contentShape(Circle())
            }
            .buttonStyle(PressScaleStyle())
            .disabled(isDisabled)

            if let label {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(isDisabled ? 0.35 : 1)
    }
}

/// Circular avatar with initials over a gradient.
struct CallAvatar: View {
    let name: String
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [Theme.callGreen.opacity(0.75), Color.teal.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            Text(SIPFormatting.initials(from: name))
                .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
    }
}
