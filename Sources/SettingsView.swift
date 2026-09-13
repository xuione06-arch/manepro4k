import SwiftUI

/// Settings: info + rifreskim listash (PA Logout — si në Android).
struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @State private var refreshing = false
    @State private var refreshed = false

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 0) {
                row("MAC e pajisjes", DeviceIdentity.macAddress())
                row("Skadon", store.login?.user_info?.expiryText ?? "—")
                row("Serveri", store.line?.server ?? "—")
                row("Përdoruesi", store.line?.username ?? "—")
                row("Statusi", store.login?.user_info?.status ?? "—")
                row("Versioni", "Mane Pro 4K 1.9.0 (iOS)")
            }
            .background(Color.card)
            .cornerRadius(14)
            .padding(.horizontal, 16)

            Button {
                Task { await refresh() }
            } label: {
                Text(refreshing ? "DUKE RIFRESHUAR…" : "⟳  RIFRESKO LISTAT")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brand))
            }
            .tint(.brand)
            .padding(.horizontal, 16)
            .disabled(refreshing)

            if refreshed {
                Text("✓ Listat u rifreskuan!")
                    .font(.caption)
                    .foregroundColor(.brand)
            }

            Text("Aktivizimi bëhet vetëm nga paneli MANE STORE. Kur pajisja fshihet ose i skadon afati në panel, aplikacioni bllokohet automatikisht dhe kthehet te ekrani i aktivizimit.")
                .font(.caption2)
                .foregroundColor(.txt2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("SETTINGS")
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor private func refresh() async {
        refreshing = true
        defer { refreshing = false }
        guard let line = store.line else { return }
        let api = XtreamApi(base: store.streamBase(), user: line.username, pass: line.password)
        if let l = try? await api.loadAll() {
            store.applyLists(l)
            refreshed = true
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundColor(.txt2)
            Spacer()
            Text(v)
                .bold()
                .foregroundColor(.lav)
                .lineLimit(1)
                .textSelection(.enabled)
        }
        .font(.subheadline)
        .padding(12)
        .overlay(Divider(), alignment: .bottom)
    }
}
