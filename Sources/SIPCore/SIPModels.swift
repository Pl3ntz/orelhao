import Foundation

public struct SIPAccount: Codable, Equatable, Sendable {
    public var id: UUID
    public var displayName: String
    public var username: String
    public var domain: String
    public var port: Int
    public var transport: SIPTransport

    public init(
        id: UUID = UUID(),
        displayName: String,
        username: String,
        domain: String,
        port: Int = 5060,
        transport: SIPTransport = .udp
    ) {
        self.id = id
        self.displayName = displayName
        self.username = username
        self.domain = domain
        self.port = port
        self.transport = transport
    }

    public var uri: String { "sip:\(username)@\(domain)" }
    public var registrarURI: String { "sip:\(domain):\(port)" }
}

public enum SIPTransport: String, Codable, Sendable, CaseIterable {
    case udp, tcp
}

public enum CallState: String, Sendable, Equatable {
    case idle
    case calling      // INVITE enviado, sem resposta provisória
    case incoming     // INVITE recebido
    case early        // 180/183 (tocando)
    case connecting   // 200 OK recebido, ACK em trânsito
    case confirmed    // chamada ativa
    case disconnected
}

public enum CallDirection: String, Sendable, Equatable {
    case outgoing, incoming
}

public struct CallInfo: Identifiable, Sendable, Equatable {
    public let id: Int
    public var remoteURI: String
    public var direction: CallDirection
    public var state: CallState
    public var statusCode: Int
    public var mediaActive: Bool
    public var startedAt: Date?

    public init(
        id: Int,
        remoteURI: String,
        direction: CallDirection,
        state: CallState = .idle,
        statusCode: Int = 0,
        mediaActive: Bool = false,
        startedAt: Date? = nil
    ) {
        self.id = id
        self.remoteURI = remoteURI
        self.direction = direction
        self.state = state
        self.statusCode = statusCode
        self.mediaActive = mediaActive
        self.startedAt = startedAt
    }
}

public enum RegistrationState: Equatable, Sendable {
    case unregistered
    case registering
    case registered
    case failed(code: Int, reason: String)
}

public enum SIPEvent: Sendable, Equatable {
    case registration(RegistrationState)
    case incomingCall(callId: Int, remoteURI: String)
    case callState(callId: Int, state: CallState, statusCode: Int)
    case mediaActive(callId: Int)
    case engineError(String)
}

public enum SIPEngineError: Error, Equatable {
    case notStarted
    case accountFailed(String)
    case callFailed(String)
}
