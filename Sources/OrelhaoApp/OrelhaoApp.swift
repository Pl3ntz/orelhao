import SwiftUI
import SIPCore

@main
struct OrelhaoApp: App {
    @State private var store = CallStore(engine: EngineProvider.makeEngine())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .windowResizability(.contentSize)
    }
}
