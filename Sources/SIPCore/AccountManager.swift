import Foundation

/// Persiste a conta SIP em Application Support (JSON sem senha; senha no Keychain).
public struct AccountManager: Sendable {
    private let fileURL: URL

    public init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("Orelhao", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("account.json")
    }

    public func load() -> SIPAccount? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(SIPAccount.self, from: data)
    }

    public func save(_ account: SIPAccount, password: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(account).write(to: fileURL, options: .atomic)
        try KeychainStore.savePassword(password, accountId: account.id)
    }

    public func loadPassword(for account: SIPAccount) -> String? {
        KeychainStore.loadPassword(accountId: account.id)
    }

    public func delete(_ account: SIPAccount) {
        try? FileManager.default.removeItem(at: fileURL)
        KeychainStore.deletePassword(accountId: account.id)
    }

    /// Conta default apontando pro Asterisk de teste local (docker compose do repo).
    public static var localTestAccount: SIPAccount {
        SIPAccount(displayName: "Asterisk local", username: "6001", domain: "127.0.0.1")
    }

    public static let localTestPassword = "test6001"
}
