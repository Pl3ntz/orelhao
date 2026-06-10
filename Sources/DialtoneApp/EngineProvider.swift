import Foundation
import SIPCore
import SIPCoreReal

// ZONA DO PE — agentes de GUI NÃO editam este arquivo.
// Composition root: a GUI pede a engine aqui e nunca instancia uma diretamente.
enum EngineProvider {
    @MainActor
    static func makeEngine() -> any SIPEngine {
        if ProcessInfo.processInfo.environment["DIALTONE_FAKE_ENGINE"] == "1" {
            return FakeSIPEngine()
        }
        return RealSIPEngine()
    }
}
