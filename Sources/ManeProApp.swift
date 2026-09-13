import SwiftUI

@main
struct ManeProApp: App {
    @StateObject private var store = AppStore()
    @State private var route: Route = .splash

    enum Route { case splash, activation, main }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.bg.ignoresSafeArea()
                switch route {
                case .splash:     SplashView { go() }
                case .activation: ActivationView { go() }
                case .main:       DashboardView()
                }
            }
            .preferredColorScheme(.dark)
            .environmentObject(store)
            .task { await startPanelGuard() }
        }
    }

    @MainActor private func go() {
        let ready = store.line != nil && store.login != nil
        withAnimation { route = ready ? .main : .activation }
    }

    /// Roja e panelit (njësoj si Android v1.9.0): çdo 20 minuta verifikon
    /// pajisjen në panel; fshirë/skaduar → kthehet te ekrani i aktivizimit.
    @MainActor private func startPanelGuard() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 20 * 60 * 1_000_000_000)
            guard store.line != nil else { continue }
            if await PanelApi.enforce(store: store) {
                withAnimation { route = .activation }
            }
        }
    }
}

struct SplashView: View {
    var onDone: () -> Void
    @State private var showWelcome = false

    var body: some View {
        VStack(spacing: 14) {
            HexLogo(size: 110)
            Text("MANE PRO 4K")
                .font(.title.bold())
                .foregroundColor(.brand)
            Text("Welcome To The Best IPTV Player Mane Pro 4K")
                .font(.headline)
                .foregroundColor(.lav)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .opacity(showWelcome ? 1 : 0)
                .animation(.easeIn(duration: 1.2).delay(0.5), value: showWelcome)
            ProgressView()
                .tint(.brand)
                .padding(.top, 24)
        }
        .onAppear {
            showWelcome = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) { onDone() }
        }
    }
}
