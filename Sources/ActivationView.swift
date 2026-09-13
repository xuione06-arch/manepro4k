import SwiftUI
import UIKit

/// Ekrani i aktivizimit: MAC e madhe + kopjim + kontroll automatik çdo 10s.
struct ActivationView: View {
    var onReady: () -> Void
    @EnvironmentObject var store: AppStore
    @State private var statusText = "Duke kontaktuar panelin MANE…"
    @State private var busy = false
    @State private var copied = false

    var body: some View {
        VStack(spacing: 10) {
            HexLogo(size: 70)
            Text("MANE PRO 4K")
                .font(.title2.bold())
                .foregroundColor(.brand)
            Text("Aktivizimi bëhet vetëm nga shitësi i MANE STORE")
                .font(.footnote)
                .foregroundColor(.txt2)

            VStack(spacing: 8) {
                Text("MAC E PAJISJES")
                    .font(.caption.bold())
                    .foregroundColor(.txt2)
                Text(DeviceIdentity.macAddress())
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .foregroundColor(.brand)
                    .textSelection(.enabled)

                Button {
                    UIPasteboard.general.string = DeviceIdentity.macAddress()
                    copied = true
                } label: {
                    Label(copied ? "U KOPIUA!" : "KOPIO MAC-IN", systemImage: "doc.on.doc")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(.brand)

                HStack(alignment: .top, spacing: 10) {
                    if busy { ProgressView().tint(.brand) }
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(.lav)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .padding(10)
                .background(Color.card2)
                .cornerRadius(12)

                Button {
                    Task { await check() }
                } label: {
                    Text(busy ? "DUKE KONTROLLUAR…" : "KONTROLLO TANI")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brand))
                }
                .tint(.brand)
            }
            .padding(18)
            .background(Color.card)
            .cornerRadius(18)
            .padding(.horizontal, 26)

            Text("Dërgoje MAC-in shitësit për aktivizim. Kontrollohet automatikisht çdo 10 sekonda.")
                .font(.caption2)
                .foregroundColor(.txt2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .task { await poll() }
    }

    @MainActor private func poll() async {
        while !Task.isCancelled {
            await check()
            try? await Task.sleep(nanoseconds: 10_000_000_000)
        }
    }

    @MainActor private func check() async {
        busy = true
        defer { busy = false }

        guard let r = await PanelApi.check() else {
            statusText = "Paneli i paarritshëm — kontrollo internetin. Provojmë sërish…"
            return
        }

        if PanelApi.allowed(r) {
            if r.line != store.line { store.saveLine(r.line!) }
        } else {
            statusText = statusMessage(r)
        }

        guard let line = store.line else { return }
        do {
            let (login, base) = try await XtreamApi.login(
                server: line.server, user: line.username, pass: line.password)
            store.saveLogin(login, base: base)
            onReady()
        } catch {
            if PanelApi.allowed(r) {
                statusText = "Pajisja është AKTIVE, por linja nuk u ngarkua (\(error.localizedDescription)). Provojmë sërish…"
            }
        }
    }

    private func statusMessage(_ r: PanelResponse) -> String {
        switch r.status {
        case "pending":         return "MAC u regjistrua në panel. Prit aktivizimin nga shitësi…"
        case "disabled":        return "Kjo pajisje është bllokuar nga paneli. Kontakto shitësin."
        case "expired":         return "Aktivizimi ka skaduar. Kontakto shitësin për rinovim."
        case "device_mismatch": return "Ky MAC është i lidhur me një instalim tjetër. Kërko nga shitësi RESET LIDHJEN në panel."
        default:                return r.message ?? "Status i panjohur nga paneli."
        }
    }
}
