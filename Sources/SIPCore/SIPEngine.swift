import Foundation

/// Contrato CONGELADO entre a GUI e qualquer engine (real ou fake).
/// A GUI só conhece este protocolo — nunca PJSIP diretamente.
public protocol SIPEngine: AnyObject, Sendable {
    /// Stream único de eventos. Consumir de um lugar só (CallStore).
    var events: AsyncStream<SIPEvent> { get }

    func start() throws
    func register(account: SIPAccount, password: String) async throws
    func unregister() async

    /// Origina chamada. Retorna o callId da engine.
    @discardableResult
    func call(uri: String) async throws -> Int
    func answer(callId: Int) async
    func hangup(callId: Int) async
    func sendDTMF(callId: Int, digits: String) async
    func setMuted(_ muted: Bool) async

    func shutdown()
}
