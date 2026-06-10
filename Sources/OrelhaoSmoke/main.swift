import Foundation
import SIPCore
import SIPCoreReal

// F2 smoke test: registers with the local Asterisk (docker compose up -d) and calls
// the echo test (600) with null audio. Exits 0 = PASS, 1 = FAIL.

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
    print("engine started")
} catch {
    fail("start: \(error.localizedDescription)")
}

do {
    try await engine.register(account: account, password: password)
    print("→ REGISTER sent to \(account.registrarURI)")
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
                print("✅ registered with Asterisk")
                do {
                    activeCallId = try await engine.call(uri: "sip:600@127.0.0.1")
                    print("→ calling sip:600 (echo), callId=\(activeCallId!)")
                } catch {
                    print("❌ call: \(error)")
                    return false
                }
            case .registration(.failed(let code, let reason)):
                print("❌ registration failed: \(code) \(reason)")
                return false
            case .callState(_, .confirmed, _):
                sawConfirmed = true
                print("✅ call CONFIRMED")
            case .mediaActive(let callId):
                print("✅ media active — holding 8s of RTP")
                try? await Task.sleep(for: .seconds(8))
                await engine.hangup(callId: callId)
            case .callState(_, .disconnected, let code):
                print("call ended (status \(code))")
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

await Task { @MainActor in }.value  // drain pending main-queue callbacks
engine.shutdown()

if outcome {
    print("✅ SMOKE PASS — registration + call + media + hangup OK")
    exit(0)
}
fail("flow did not complete (see events above)")
