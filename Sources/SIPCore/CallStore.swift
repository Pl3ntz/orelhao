import Foundation
import Observation

/// Sole consumer of the engine's event stream. Source of truth for the GUI.
@Observable
@MainActor
public final class CallStore {
    public private(set) var registration: RegistrationState = .unregistered
    public private(set) var calls: [Int: CallInfo] = [:]
    public private(set) var isMuted = false
    public private(set) var lastError: String?

    /// Call featured in the UI (the most recent non-disconnected one).
    public var activeCall: CallInfo? {
        calls.values
            .filter { $0.state != .disconnected && $0.state != .idle }
            .sorted { $0.id > $1.id }
            .first
    }

    public var incomingCall: CallInfo? {
        calls.values.first { $0.state == .incoming }
    }

    private let engine: any SIPEngine
    private var eventTask: Task<Void, Never>?

    public init(engine: any SIPEngine) {
        self.engine = engine
        eventTask = Task { [weak self] in
            for await event in engine.events {
                self?.apply(event)
            }
        }
    }

    // MARK: - Commands (GUI → engine)

    public func register(account: SIPAccount, password: String) async {
        do {
            try engine.start()
            try await engine.register(account: account, password: password)
        } catch {
            lastError = "Registration failed: \(error.localizedDescription)"
            registration = .failed(code: 0, reason: lastError ?? "")
        }
    }

    public func unregister() async {
        await engine.unregister()
    }

    public func call(_ destination: String, account: SIPAccount?) async {
        let uri = Self.normalizeURI(destination, domain: account?.domain, port: account?.port)
        do {
            let callId = try await engine.call(uri: uri)
            // the real engine emits callState right after; pre-register direction/URI
            if calls[callId] == nil {
                calls[callId] = CallInfo(id: callId, remoteURI: uri, direction: .outgoing, state: .calling)
            }
        } catch {
            lastError = "Call failed: \(error.localizedDescription)"
        }
    }

    public func answer() async {
        guard let call = incomingCall else { return }
        await engine.answer(callId: call.id)
    }

    public func hangup() async {
        guard let call = activeCall else { return }
        await engine.hangup(callId: call.id)
    }

    public func decline() async {
        guard let call = incomingCall else { return }
        await engine.hangup(callId: call.id)
    }

    public func sendDTMF(_ digits: String) async {
        guard let call = activeCall, call.state == .confirmed else { return }
        await engine.sendDTMF(callId: call.id, digits: digits)
    }

    public func toggleMute() async {
        isMuted.toggle()
        await engine.setMuted(isMuted)
    }

    public func clearError() { lastError = nil }

    /// Removes ended calls from state (UI cleanup).
    public func dismissEndedCalls() {
        calls = calls.filter { $0.value.state != .disconnected }
    }

    // MARK: - Events (engine → state)

    private func apply(_ event: SIPEvent) {
        switch event {
        case .registration(let state):
            registration = state

        case .incomingCall(let callId, let remoteURI):
            calls[callId] = CallInfo(id: callId, remoteURI: remoteURI, direction: .incoming, state: .incoming)

        case .callState(let callId, let state, let statusCode):
            guard var call = calls[callId] else {
                // call originated by the engine before the GUI pre-registered it
                calls[callId] = CallInfo(
                    id: callId, remoteURI: "?", direction: .outgoing,
                    state: state, statusCode: statusCode
                )
                return
            }
            call.state = state
            call.statusCode = statusCode
            if state == .confirmed, call.startedAt == nil {
                call.startedAt = Date()
            }
            if state == .disconnected {
                isMuted = false
            }
            calls[callId] = call

        case .mediaActive(let callId):
            guard var call = calls[callId] else { return }
            call.mediaActive = true
            calls[callId] = call

        case .engineError(let message):
            lastError = message
        }
    }

    // MARK: - Helpers

    /// "600" + account 127.0.0.1 → "sip:600@127.0.0.1"; full URIs pass through unchanged.
    public static func normalizeURI(_ input: String, domain: String?, port: Int?) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("sip:") || trimmed.hasPrefix("sips:") { return trimmed }
        guard let domain, !domain.isEmpty else { return "sip:\(trimmed)" }
        let portSuffix = (port ?? 5060) == 5060 ? "" : ":\(port!)"
        return "sip:\(trimmed)@\(domain)\(portSuffix)"
    }
}
