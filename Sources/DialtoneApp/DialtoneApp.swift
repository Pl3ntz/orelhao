import SwiftUI
import SIPCore

@main
struct DialtoneApp: App {
    @State private var store = CallStore(engine: EngineProvider.makeEngine())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .windowResizability(.contentSize)
    }
}
