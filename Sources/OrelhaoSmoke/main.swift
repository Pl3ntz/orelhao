import Foundation
import SIPCore
import SIPCoreReal

// Smoke test F2: registra no Asterisk local (docker compose up -d) e liga pro
// echo test (600) com null-audio. Sai 0 = PASS, 1 = FAIL.

let engine = RealSIPEngine(useNullAudio: true)
let account = AccountManager.localTestAccount
let password = AccountManager.localTestPassword

func fail(_ message: String) -> Never {
    print("❌ FAIL: \(message)")
    engine.shutdown()
    exit(1)
}

do {
    try engine.start()
    print("engine iniciada")
} catch {
    fail("start: \(error.localizedDescription)")
}

do {
    try await engine.register(account: account, password: password)
    print("→ REGISTER enviado para \(account.registrarURI)")
} catch {
    fail("register: \(error.localizedDescription)")
}

let outcome = await withTaskGroup(of: Bool.self) { group -> Bool in
    group.addTask {
        var activeCallId: Int?
        var sawConfirmed = false
        for await event in engine.events {
            switch event {
            case .registration(.registered):
                print("✅ registrado no Asterisk")
                do {
                    activeCallId = try await engine.call(uri: "sip:600@127.0.0.1")
                    print("→ chamando sip:600 (echo), callId=\(activeCallId!)")
                } catch {
                    print("❌ call: \(error)")
                    return false
                }
            case .registration(.failed(let code, let reason)):
                print("❌ registro falhou: \(code) \(reason)")
                return false
            case .callState(_, .confirmed, _):
                sawConfirmed = true
                print("✅ chamada CONFIRMED")
            case .mediaActive(let callId):
                print("✅ mídia ativa — segurando 8s de RTP")
                try? await Task.sleep(for: .seconds(8))
                await engine.hangup(callId: callId)
            case .callState(_, .disconnected, let code):
                print("chamada encerrada (status \(code))")
                return sawConfirmed
            default:
                break
            }
        }
        return false
    }
    group.addTask {
        try? await Task.sleep(for: .seconds(40))
        return false  // timeout
    }
    guard let first = await group.next() else { return false }
    group.cancelAll()
    return first
}

await Task { @MainActor in }.value  // drena callbacks pendentes da main queue
engine.shutdown()

if outcome {
    print("✅ SMOKE PASS — registro + chamada + mídia + hangup OK")
    exit(0)
}
fail("fluxo não completou (veja eventos acima)")
