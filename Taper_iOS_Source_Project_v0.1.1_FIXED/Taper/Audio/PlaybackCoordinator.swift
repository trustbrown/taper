import AVFoundation
import MediaPlayer
import Combine

@MainActor final class PlaybackCoordinator: ObservableObject {
    @Published private(set) var concert: Concert?
    @Published private(set) var track: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var error: String?
    @Published private(set) var activeCodec: AudioCodec = .mp3
    private var queue: [Track] = []
    private var index = 0
    private var player: AVPlayer?
    private var observer: Any?
    private var endObserver: NSObjectProtocol?
    weak var library: LibraryStore?
    weak var downloads: DownloadCoordinator?

    init() {
        do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default) }
        catch { self.error = error.localizedDescription }
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.play() }; return .success }
        center.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success }
        center.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.next() }; return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.previous() }; return .success }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }; return .success
        }
    }
    func start(_ concert: Concert, at trackIndex: Int = 0, codec: AudioCodec = .mp3) {
        guard !concert.tracks.isEmpty else { error = TaperError.noAudio.localizedDescription; return }
        self.concert = concert; queue = concert.tracks; index = min(max(0, trackIndex), queue.count - 1)
        activeCodec = codec; library?.heard(concert.id); loadCurrent(resume: true)
    }
    private func loadCurrent(resume: Bool = false) {
        guard queue.indices.contains(index), let concert else { return }
        let selected = queue[index]
        guard let variant = selected.preferred(activeCodec) else { error = TaperError.noAudio.localizedDescription; next(); return }
        if activeCodec == .flac && variant.codec != .flac {
            error = "FLAC is not available for this track; using MP3."
        } else { error = nil }
        track = selected
        let file = downloads?.localURL(for: variant.id)
        let item = AVPlayerItem(url: file ?? variant.url)
        teardown()
        let p = AVPlayer(playerItem: item); player = p
        duration = selected.duration ?? 0; position = 0
        observer = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.position = time.seconds.isFinite ? time.seconds : 0
                let seconds = p.currentItem?.duration.seconds ?? 0
                if seconds.isFinite && seconds > 0 { self.duration = seconds }
                if Int(self.position) % 5 == 0 { self.library?.remember(selected.id, self.position) }
                self.updateNowPlaying()
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.next() }
        }
        let saved = resume ? (library?.resume[selected.id] ?? 0) : 0
        if saved > 0 { p.seek(to: CMTime(seconds: saved, preferredTimescale: 600)) }
        p.play(); isPlaying = true; updateNowPlaying()
    }
    func play() { player?.play(); isPlaying = true; updateNowPlaying() }
    func pause() { player?.pause(); isPlaying = false; updateNowPlaying() }
    func toggle() { isPlaying ? pause() : play() }
    func next() { if index + 1 < queue.count { index += 1; loadCurrent() } else { pause(); seek(to: 0) } }
    func previous() { if position > 4 { seek(to: 0) } else if index > 0 { index -= 1; loadCurrent() } }
    func seek(to seconds: Double) { player?.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600)); position = seconds }
    private func teardown() {
        if let observer, let player { player.removeTimeObserver(observer) }; observer = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }; endObserver = nil
        player?.pause(); player = nil
    }
    private func updateNowPlaying() {
        guard let track, let concert else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: track.title, MPMediaItemPropertyArtist: concert.artist,
            MPMediaItemPropertyAlbumTitle: concert.title, MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }
}
