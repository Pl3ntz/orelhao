import Foundation

/// FROZEN contract between the GUI and any engine (real or fake).
/// The GUI only knows this protocol — never PJSIP directly.
public protocol SIPEngine: AnyObject, Sendable {
    /// Single event stream. Consume from exactly one place (CallStore).
    var events: AsyncStream<SIPEvent> { get }

    func start() throws
    func register(account: SIPAccount, password: String) async throws
    func unregister() async

    /// Originates a call. Returns the engine's callId.
    @discardableResult
    func call(uri: String) async throws -> Int
    func answer(callId: Int) async
    func hangup(callId: Int) async
    func sendDTMF(callId: Int, digits: String) async
    func setMuted(_ muted: Bool) async

    func shutdown()
}
