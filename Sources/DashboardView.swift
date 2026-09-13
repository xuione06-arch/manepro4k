import SwiftUI

/// Dashboard-i në stilin iBo RTX 4K: 4 qeliza + Skadon + orë + MANE STORE.
struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    @State private var time = ""

    private var daysLeft: Int? {
        guard let ts = store.login?.user_info?.expiryTs else { return nil }
        return Int((ts - Date().timeIntervalSince1970) / 86400)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                header

                if let d = daysLeft, d >= 0, d <= 7 {
                    Text("⚠️ Abonimi skadon pas \(d) ditësh! Kontakto shitësin për rinovim.")
                        .font(.caption.bold())
                        .foregroundColor(.pink)
                }

                NavigationLink { LiveView() } label: { cell("LIVE TV", "tv") }
                NavigationLink { LibraryView(mode: .movies) } label: { cell("MOVIES", "film") }
                NavigationLink { LibraryView(mode: .series) } label: { cell("TV SERIES", "video") }
                NavigationLink { SettingsView() } label: { cell("SETTINGS", "gearshape") }

                Spacer(minLength: 0)
            }
            .padding(.top, 6)
            .background(Color.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task { await tick() }
        }
    }

    private var header: some View {
        HStack {
            Text("Skadon: \(store.login?.user_info?.expiryText ?? "—")")
                .font(.subheadline.bold())
                .foregroundColor(Color(hex: 0xE8C8D8))
            Spacer()
            HStack(spacing: 8) {
                HexLogo(size: 24)
                Text("MANE STORE").font(.headline).foregroundColor(.lav)
            }
            Spacer()
            Text(time).font(.headline).foregroundColor(.lav)
        }
        .padding(.horizontal, 18)
    }

    private func cell(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(.lav)
            Text(title).font(.footnote.bold()).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: 86)
        .background(Color.card)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line))
        .padding(.horizontal, 16)
    }

    @MainActor private func tick() async {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        while !Task.isCancelled {
            time = f.string(from: Date())
            try? await Task.sleep(nanoseconds: 30_000_000_000)
        }
    }
}
