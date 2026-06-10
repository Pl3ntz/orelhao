import Foundation
import SIPCore
import SIPCoreReal

// PE ZONE — GUI agents must NOT edit this file.
// Composition root: the GUI obtains the engine here and never instantiates one directly.
enum EngineProvider {
    @MainActor
    static func makeEngine() -> any SIPEngine {
        if ProcessInfo.processInfo.environment["ORELHAO_FAKE_ENGINE"] == "1" {
            return FakeSIPEngine()
        }
        return RealSIPEngine()
    }
}
