import Foundation

/// Presentation helpers for SIP URIs/identities (no domain logic).
enum SIPFormatting {
    /// `"Alice" <sip:600@host>` → `Alice`; `sip:600@host` → `600`.
    static func displayName(from remoteURI: String) -> String {
        let trimmed = remoteURI.trimmingCharacters(in: .whitespaces)

        if let lt = trimmed.firstIndex(of: "<") {
            let name = trimmed[..<lt]
                .trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
            if !name.isEmpty { return name }
        }

        var core = trimmed
        if let lt = trimmed.firstIndex(of: "<"),
           let gt = trimmed.firstIndex(of: ">"),
           lt < gt {
            core = String(trimmed[trimmed.index(after: lt)..<gt])
        }
        for prefix in ["sips:", "sip:"] where core.hasPrefix(prefix) {
            core = String(core.dropFirst(prefix.count))
        }
        if let at = core.firstIndex(of: "@") {
            core = String(core[..<at])
        }
        return core.isEmpty ? "?" : core
    }

    /// Avatar initials: "Alice Braga" → "AB"; "600" → "60".
    static func initials(from name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        if parts.count >= 2, let a = parts.first?.first, let b = parts.last?.first {
            return (String(a) + String(b)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    /// mm:ss duration from `start` to `now`.
    static func elapsed(since start: Date, now: Date) -> String {
        let secs = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", secs / 60, secs % 60)
    }
}
