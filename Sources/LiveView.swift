import SwiftUI

/// LIVE TV: kategoritë e panelit në renditjen e tyre + kërkim + favorites.
struct LiveView: View {
    @EnvironmentObject var store: AppStore
    @State private var cat = "__all__"
    @State private var query = ""
    @State private var favorites: Set<Int> = []

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 2) {
                    catRow("__all__", "🌐 Të gjitha")
                    catRow("__fav__", "❤️ Favorites")
                    ForEach(store.liveCats) { c in
                        catRow(c.id, c.name)
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(width: 168)
            .background(Color.card)

            VStack(spacing: 8) {
                TextField("Kërko kanale…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 10)

                List(filtered) { ch in
                    NavigationLink {
                        PlayerView(kind: .live(channel: ch, list: filtered))
                    } label: {
                        HStack(spacing: 10) {
                            Text(String(ch.num))
                                .font(.caption.bold())
                                .foregroundColor(.brand)
                                .frame(width: 38, alignment: .trailing)
                            logo(ch)
                            Text(ch.name)
                                .font(.subheadline.bold())
                                .lineLimit(2)
                            Spacer(minLength: 4)
                            Button {
                                toggleFav(ch.id)
                            } label: {
                                Image(systemName: favorites.contains(ch.id) ? "heart.fill" : "heart")
                                    .foregroundColor(favorites.contains(ch.id) ? .pink : .txt2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("LIVE TV")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            favorites = Set(UserDefaults.standard.integerArray(forKey: "mane_fav"))
            if store.live.isEmpty { Task { await load() } }
        }
    }

    private func logo(_ ch: LiveChannel) -> some View {
        Group {
            if let s = ch.icon, !s.isEmpty, let u = URL(string: s) {
                AsyncImage(url: u) { img in
                    img.resizable().scaledToFit()
                } placeholder: {
                    hexM
                }
            } else {
                hexM
            }
        }
        .frame(width: 46, height: 34)
        .background(Color.card2)
        .cornerRadius(6)
    }

    private var hexM: some View {
        Text("M").font(.caption.bold()).foregroundColor(.brand)
    }

    @MainActor private func load() async {
        guard let line = store.line else { return }
        let api = XtreamApi(base: store.streamBase(), user: line.username, pass: line.password)
        if let l = try? await api.loadAll() { store.applyLists(l) }
    }

    private var filtered: [LiveChannel] {
        var l = store.live
        if cat == "__fav__" {
            l = l.filter { favorites.contains($0.id) }
        } else if cat != "__all__" {
            l = l.filter { $0.categories.contains(cat) }
        }
        if !query.isEmpty {
            let q = query.lowercased()
            l = l.filter { $0.name.lowercased().contains(q) }
        }
        return l
    }

    private func toggleFav(_ id: Int) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        UserDefaults.standard.set(Array(favorites), forKey: "mane_fav")
    }

    private func catRow(_ id: String, _ name: String) -> some View {
        Button {
            cat = id
        } label: {
            Text(name)
                .font(.footnote.bold())
                .foregroundColor(cat == id ? .brand : .txt2)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(cat == id ? Color.card2 : Color.clear)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 5)
    }
}
