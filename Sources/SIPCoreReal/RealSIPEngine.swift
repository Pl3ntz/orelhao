import Foundation
import PJSIPBridge
import SIPCore

/// Real engine: SIPEngine (Swift) → PSEngine (Obj-C/PJSUA2).
/// Bridge delegate callbacks arrive on the main queue; yielding into the AsyncStream is thread-safe.
public final class RealSIPEngine: NSObject, SIPEngine, @unchecked Sendable {
    public let events: AsyncStream<SIPEvent>
    private let continuation: AsyncStream<SIPEvent>.Continuation
    private let bridge: PSEngine

    public init(useNullAudio: Bool = false) {
        var streamContinuation: AsyncStream<SIPEvent>.Continuation!
        self.events = AsyncStream { streamContinuation = $0 }
        self.continuation = streamContinuation
        self.bridge = PSEngine(nullAudio: useNullAudio)
        super.init()
        self.bridge.delegate = self
    }

    public func start() throws {
        try bridge.start()
    }

    public func register(account: SIPAccount, password: String) async throws {
        continuation.yield(.registration(.registering))
        do {
            try bridge.registerAccount(
                withURI: account.uri,
                registrar: account.registrarURI,
                username: account.username,
                password: password,
                useTCP: account.transport == .tcp
            )
        } catch {
            continuation.yield(.registration(.failed(code: 0, reason: error.localizedDescription)))
            throw SIPEngineError.accountFailed(error.localizedDescription)
        }
    }

    public func unregister() async {
        bridge.unregisterAccount()
        continuation.yield(.registration(.unregistered))
    }

    @discardableResult
    public func call(uri: String) async throws -> Int {
        var failure: NSError?
        let callId = bridge.makeCall(to: uri, error: &failure)
        if callId < 0 {
            throw SIPEngineError.callFailed(failure?.localizedDescription ?? "makeCall failed")
        }
        return callId
    }

    public func answer(callId: Int) async {
        bridge.answerCall(callId)
    }

    public func hangup(callId: Int) async {
        bridge.hangupCall(callId)
    }

    public func sendDTMF(callId: Int, digits: String) async {
        bridge.sendDTMF(digits, toCall: callId)
    }

    public func setMuted(_ muted: Bool) async {
        bridge.setMuted(muted)
    }

    public func shutdown() {
        bridge.shutdown()
        continuation.finish()
    }
}

extension RealSIPEngine: PSEngineDelegate {
    public func engineRegistrationChanged(withActive active: Bool, statusCode: Int, reason: String) {
        if active {
            continuation.yield(.registration(.registered))
        } else if statusCode >= 300 {
            continuation.yield(.registration(.failed(code: statusCode, reason: reason)))
        } else {
            continuation.yield(.registration(.unregistered))
        }
    }

    public func engineIncomingCall(_ event: PSCallEvent) {
        continuation.yield(.incomingCall(callId: event.callId, remoteURI: event.remoteURI))
    }

    public func engineCallChanged(_ event: PSCallEvent) {
        continuation.yield(.callState(
            callId: event.callId,
            state: Self.callState(from: event.state),
            statusCode: event.statusCode
        ))
    }

    public func engineMediaActive(forCall callId: Int) {
        continuation.yield(.mediaActive(callId: callId))
    }

    private static func callState(from state: PSCallState) -> CallState {
        switch state {
        case .idle: return .idle
        case .calling: return .calling
        case .incoming: return .incoming
        case .early: return .early
        case .connecting: return .connecting
        case .confirmed: return .confirmed
        case .disconnected: return .disconnected
        @unknown default: return .idle
        }
    }
}
