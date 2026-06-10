import SwiftUI
import SIPCore

/// GUI root: fixed header + dialer/call with transition + overlays (banner/error).
struct ContentView: View {
    @Environment(CallStore.self) private var store

    @State private var account: SIPAccount = AccountManager.localTestAccount
    @State private var password: String = AccountManager.localTestPassword
    @State private var showSettings = false

    /// Call shown in the main area: the active one (except an incoming call not
    /// yet answered, which lives in the banner) or the just-ended one ("ended" state).
    private var presentedCall: CallInfo? {
        if let active = store.activeCall, active.state != .incoming {
            return active
        }
        return store.calls.values
            .filter { $0.state == .disconnected }
            .sorted { $0.id > $1.id }
            .first
    }

    private var headerName: String {
        account.displayName.isEmpty ? account.uri : account.displayName
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                HeaderView(accountName: headerName) { showSettings = true }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                ZStack {
                    if let call = presentedCall {
                        ActiveCallView(call: call)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                    } else {
                        DialerView(account: account)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay(alignment: .top) {
            if let incoming = store.incomingCall {
                IncomingCallBanner(call: incoming)
                    .padding(.top, 70)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if let error = store.lastError {
                ErrorBanner(message: error) { store.clearError() }
                    .padding(16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: presentedCall?.id)
        .animation(.spring(duration: 0.3), value: store.incomingCall?.id)
        .animation(.easeInOut(duration: 0.25), value: store.lastError)
        .frame(width: Theme.windowSize.width, height: Theme.windowSize.height)
        .sheet(isPresented: $showSettings) {
            SettingsSheet(
                initialAccount: account,
                initialPassword: password
            ) { savedAccount, savedPassword in
                account = savedAccount
                password = savedPassword
                Task { await store.register(account: savedAccount, password: savedPassword) }
            }
        }
        .task { await bootstrap() }
        .onChange(of: presentedCall?.state) { _, newState in
            if newState == .disconnected { scheduleEndedDismiss() }
        }
    }

    /// Loads the saved account (or falls back to the local test default) and auto-registers.
    private func bootstrap() async {
        let manager = AccountManager()
        if let saved = manager.load() {
            account = saved
            password = manager.loadPassword(for: saved) ?? ""
        }
        await store.register(account: account, password: password)
    }

    /// Briefly shows "ended", then returns to the dialer.
    private func scheduleEndedDismiss() {
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            store.dismissEndedCalls()
        }
    }
}
