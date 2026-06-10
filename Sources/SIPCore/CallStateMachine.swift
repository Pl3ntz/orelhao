import Foundation

/// Transições válidas de uma chamada SIP. Função pura — transição ilegal retorna nil
/// e NUNCA é aplicada (o chamador loga e descarta).
public enum CallStateMachine {
    public static func transition(from state: CallState, on event: CallTransitionEvent) -> CallState? {
        switch (state, event) {
        case (.idle, .dialed): return .calling
        case (.idle, .invited): return .incoming

        case (.calling, .provisional): return .early
        case (.calling, .accepted): return .connecting
        case (.calling, .ended): return .disconnected

        case (.incoming, .provisional): return .incoming
        case (.incoming, .accepted): return .connecting
        case (.incoming, .ended): return .disconnected

        case (.early, .accepted): return .connecting
        case (.early, .ended): return .disconnected

        case (.connecting, .established): return .confirmed
        case (.connecting, .ended): return .disconnected

        case (.confirmed, .ended): return .disconnected

        default: return nil
        }
    }
}

public enum CallTransitionEvent: Sendable, Equatable {
    case dialed       // usuário originou
    case invited      // INVITE entrou
    case provisional  // 180/183
    case accepted     // 200 OK
    case established  // ACK / mídia confirmada
    case ended        // BYE / CANCEL / erro
}
