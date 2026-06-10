import Foundation

/// Engine simulada — permite desenvolver e demonstrar a GUI inteira sem PJSIP/rede.
/// Comportamento: registro responde em 0.4s; chamada progride calling → early → confirmed;
/// digitar "fail" no URI simula 404.
public final class FakeSIPEngine: SIPEngine, @unchecked Sendable {
    public let events: AsyncStream<SIPEvent>
    private let continuation: AsyncStream<SIPEvent>.Continuation
    private let lock = NSLock()
    private var nextCallId = 1
    private var activeCallIds: Set<Int> = []

    public init() {
        var cont: AsyncStream<SIPEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    public func start() throws {}

    public func register(account: SIPAccount, password: String) async throws {
        continuation.yield(.registration(.registering))
        try? await Task.sleep(for: .milliseconds(400))
        if password.isEmpty {
            continuation.yield(.registration(.failed(code: 401, reason: "Unauthorized")))
        } else {
            continuation.yield(.registration(.registered))
        }
    }

    public func unregister() async {
        continuation.yield(.registration(.unregistered))
    }

    @discardableResult
    public func call(uri: String) async throws -> Int {
        let callId = allocateCallId()
        continuation.yield(.callState(callId: callId, state: .calling, statusCode: 0))
        Task { [continuation] in
            try? await Task.sleep(for: .milliseconds(600))
            guard self.isActive(callId) else { return }
            if uri.contains("fail") {
                continuation.yield(.callState(callId: callId, state: .disconnected, statusCode: 404))
                self.deactivate(callId)
                return
            }
            continuation.yield(.callState(callId: callId, state: .early, statusCode: 180))
            try? await Task.sleep(for: .seconds(2))
            guard self.isActive(callId) else { return }
            continuation.yield(.callState(callId: callId, state: .connecting, statusCode: 200))
            continuation.yield(.callState(callId: callId, state: .confirmed, statusCode: 200))
            continuation.yield(.mediaActive(callId: callId))
        }
        return callId
    }

    public func answer(callId: Int) async {
        continuation.yield(.callState(callId: callId, state: .connecting, statusCode: 200))
        continuation.yield(.callState(callId: callId, state: .confirmed, statusCode: 200))
        continuation.yield(.mediaActive(callId: callId))
    }

    public func hangup(callId: Int) async {
        deactivate(callId)
        continuation.yield(.callState(callId: callId, state: .disconnected, statusCode: 200))
    }

    public func sendDTMF(callId: Int, digits: String) async {}

    public func setMuted(_ muted: Bool) async {}

    public func shutdown() {
        continuation.finish()
    }

    /// Dispara uma chamada entrante simulada (menu de dev / previews).
    public func simulateIncomingCall(from uri: String = "sip:6002@127.0.0.1") {
        let callId = allocateCallId()
        continuation.yield(.incomingCall(callId: callId, remoteURI: uri))
        continuation.yield(.callState(callId: callId, state: .incoming, statusCode: 0))
    }

    private func allocateCallId() -> Int {
        lock.lock(); defer { lock.unlock() }
        let id = nextCallId
        nextCallId += 1
        activeCallIds.insert(id)
        return id
    }

    private func isActive(_ id: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return activeCallIds.contains(id)
    }

    private func deactivate(_ id: Int) {
        lock.lock(); defer { lock.unlock() }
        activeCallIds.remove(id)
    }
}
