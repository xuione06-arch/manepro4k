import SwiftUI
import AVKit
import MobileVLCKit

/// Player me MOTOR DUBL si Android v1.9.0:
///   1. VLC (MobileVLCKit) — luan TË GJITHA formatet si VLC në desktop
///   2. AVPlayer (Apple) — rezervë automatike brenda 14s
/// Motori zgjidhet: Settings → "mane_engine" = auto | vlc | av
struct PlayerView: View {
    enum Kind {
        case live(channel: LiveChannel, list: [LiveChannel])
        case movie(VodItem)
        case episode(Episode, title: String)
    }

    let kind: Kind
    @EnvironmentObject var store: AppStore

    @StateObject private var vlc = VLCBox()
    @State private var avPlayer = AVPlayer()

    @State private var useVLC = true
    @State private var engineSwitched = false
    @State private var urls: [String] = []
    @State private var tryIdx = 0
    @State private var failed = false
    @State private var timer: Timer?
    @State private var curId = 0
    @State private var curName = ""
    @State private var liveList: [LiveChannel] = []

    private var enginePref: String {
        UserDefaults.standard.string(forKey: "mane_engine") ?? "auto"
    }

    private var isLive: Bool {
        if case .live = kind { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if isLive {
                    Button { zap(-1) } label: {
                        Label("PARA", systemImage: "backward.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.brand)

                    Button { zap(1) } label: {
                        Label("PAS", systemImage: "forward.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.brand)
                }
                Text(curName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .foregroundColor(.lav)
                Spacer()
                Text(useVLC ? "VLC" : "AV")
                    .font(.caption2.bold())
                    .foregroundColor(.txt2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.card)
                    .cornerRadius(6)
            }
            .padding(8)

            ZStack {
                if useVLC {
                    VLCVideoView(box: vlc)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    VideoPlayer(player: avPlayer)
                        .ignoresSafeArea(edges: .bottom)
                }
                if failed {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.pink)
                        Text("Kanali nuk po hapet.\nProvo një kanal tjetër ose kontrollo VPN-në.")
                            .font(.subheadline)
                            .foregroundColor(.txt2)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(curName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vlc.onVlcError = {
                DispatchQueue.main.async {
                    tryIdx += 1
                    attempt()
                }
            }
            start()
        }
        .onDisappear {
            timer?.invalidate()
            vlc.stop()
            avPlayer.pause()
            avPlayer.replaceCurrentItem(with: nil)
        }
    }

    // MARK: - Rrjedha e ndërtesës (si Android: URL kandidate + motor kandidues)

    private func start() {
        switch kind {
        case .live(let ch, let list):
            liveList = list
            curId = ch.id
            curName = ch.name
            urls = store.liveUrls(id: ch.id)
        case .movie(let v):
            curName = v.name
            urls = [store.movieUrl(v)]
        case .episode(let e, let t):
            curName = t
            urls = [store.episodeUrl(e)]
        }
        tryIdx = 0
        failed = false
        engineSwitched = false
        useVLC = enginePref != "av"
        attempt()
    }

    private func attempt() {
        timer?.invalidate()
        vlc.stop()
        avPlayer.pause()

        if tryIdx >= urls.count {
            // MBARUAN URL-at me këtë motor → kalo te motori rezervë (vetëm në modalitetin auto)
            if useVLC && enginePref == "auto" && !engineSwitched {
                useVLC = false
                engineSwitched = true
                tryIdx = 0
                attempt()
                return
            }
            failed = true
            return
        }

        guard let u = URL(string: urls[tryIdx]) else {
            tryIdx += 1
            attempt()
            return
        }

        if useVLC {
            vlc.play(u)
        } else {
            avPlayer.replaceCurrentItem(with: AVPlayerItem(url: u))
            avPlayer.play()
        }

        // Roja 14s: nëse s'luhet, provo URL-në/ motorin tjetër
        timer = Timer.scheduledTimer(withTimeInterval: 14, repeats: false) { _ in
            let playing = useVLC ? vlc.player.isPlaying : avPlayer.timeControlStatus == .playing
            if !playing {
                tryIdx += 1
                attempt()
            }
        }
    }

    /// Kalimi në kanalin para/pas (auto-zap si në Android).
    private func zap(_ dir: Int) {
        guard !liveList.isEmpty,
              let idx = liveList.firstIndex(where: { $0.id == curId }) else { return }
        let n = idx + dir
        guard n >= 0, n < liveList.count else { return }
        let ch = liveList[n]
        curId = ch.id
        curName = ch.name
        urls = store.liveUrls(id: ch.id)
        tryIdx = 0
        failed = false
        engineSwitched = false
        attempt()
    }
}

// MARK: - VLC (motori kryesor — të gjitha formatet)

final class VLCBox: NSObject, ObservableObject {
    let player = VLCMediaPlayer()
    var onVlcError: (() -> Void)?

    override init() {
        super.init()
        player.delegate = self
    }

    func play(_ url: URL) {
        player.media = VLCMedia(url: url)
        player.play()
    }

    func stop() {
        player.stop()
    }
}

extension VLCBox: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        if player.state == .error {
            onVlcError?()
        }
    }
}

struct VLCVideoView: UIViewRepresentable {
    let box: VLCBox

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .black
        box.player.drawable = v
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        box.player.drawable = uiView
    }
}
