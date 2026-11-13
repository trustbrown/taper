import Foundation
import Combine

struct OfflineEntry: Codable, Identifiable {
    let id: String // variant id
    let concertID: String
    let artist: String
    let concertTitle: String
    let trackTitle: String
    let codec: AudioCodec
    let relativeFile: String
    var state: String
    var bytes: Int64?
    var error: String?
}

@MainActor final class DownloadCoordinator: NSObject, ObservableObject {
    @Published private(set) var entries: [String: OfflineEntry] = [:]
    @Published private(set) var progress: [String: Double] = [:]
    @Published var message: String?
    private let root: URL
    private let manifest: URL
    private var session: URLSession!
    var wifiOnly = true

    override init() {
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Taper/Offline", isDirectory: true)
        manifest = root.appendingPathComponent("manifest.json")
        super.init()
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: manifest), let saved = try? JSONDecoder().decode([String: OfflineEntry].self, from: data) {
            entries = saved
        }
        let config = URLSessionConfiguration.background(withIdentifier: "org.taper.community.offline.v1")
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        Task { await recoverTasks() }
    }
    private func recoverTasks() async {
        let tasks = await session.allTasks
        let running = Set(tasks.compactMap(\.taskDescription))
        for id in entries.keys where entries[id]?.state == "running" && !running.contains(id) {
            entries[id]?.state = "failed"
            entries[id]?.error = "Transfer interrupted. Tap Retry."
        }
        save()
    }
    func localURL(for id: String) -> URL? {
        guard let entry = entries[id], entry.state == "completed" else { return nil }
        let url = root.appendingPathComponent(entry.relativeFile)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    func download(_ concert: Concert, track: Track, codec: AudioCodec) {
        guard concert.downloadable else { message = "The recording is not marked downloadable by this source."; return }
        guard let variant = track.variants.first(where: { $0.codec == codec }) else {
            message = "\(codec.rawValue) is not available for \(track.title)."; return
        }
        guard localURL(for: variant.id) == nil else { return }
        let stableHash = variant.id.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        let filename = String(format: "%016llx", stableHash) + "." + codec.rawValue.lowercased()
        let entry = OfflineEntry(id: variant.id, concertID: concert.id, artist: concert.artist,
                                 concertTitle: concert.title, trackTitle: track.title, codec: codec,
                                 relativeFile: filename, state: "running", bytes: variant.bytes, error: nil)
        entries[variant.id] = entry; save()
        var request = URLRequest(url: variant.url)
        request.allowsCellularAccess = !wifiOnly
        let task = session.downloadTask(with: request)
        task.taskDescription = variant.id
        task.resume()
    }
    func downloadShow(_ concert: Concert, codec: AudioCodec) {
        for track in concert.tracks where track.variants.contains(where: { $0.codec == codec }) {
            download(concert, track: track, codec: codec)
        }
    }
    func delete(_ id: String) {
        guard let entry = entries.removeValue(forKey: id) else { return }
        try? FileManager.default.removeItem(at: root.appendingPathComponent(entry.relativeFile))
        save()
    }
    func retry(_ entry: OfflineEntry, concert: Concert) {
        if let track = concert.tracks.first(where: { $0.variants.contains(where: { $0.id == entry.id }) }) {
            download(concert, track: track, codec: entry.codec)
        }
    }
    var storedBytes: Int64 {
        entries.values.filter { $0.state == "completed" }.reduce(0) { sum, item in
            let url = root.appendingPathComponent(item.relativeFile)
            let length = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + Int64(length)
        }
    }
    private func save() { if let data = try? JSONEncoder().encode(entries) { try? data.write(to: manifest, options: .atomic) } }
    private func finished(task: URLSessionDownloadTask, location: URL) {
        guard let id = task.taskDescription, var entry = entries[id] else { return }
        let destination = root.appendingPathComponent(entry.relativeFile)
        do {
            guard (task.response as? HTTPURLResponse)?.statusCode == 200 ||
                  (task.response as? HTTPURLResponse)?.statusCode == 206 else { throw TaperError.invalidResponse }
            let size = (try location.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard size > 0 else { throw TaperError.invalidResponse }
            if let expected = entry.bytes, expected > 0, Int64(size) != expected {
                throw TaperError.unavailable("Downloaded file size does not match archive metadata.")
            }
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            entry.state = "completed"; entry.error = nil
        } catch {
            entry.state = "failed"; entry.error = error.localizedDescription
        }
        entries[id] = entry; progress.removeValue(forKey: id); save()
    }
    private func failed(task: URLSessionTask, error: Error) {
        guard let id = task.taskDescription, var entry = entries[id], entry.state != "completed" else { return }
        entry.state = "failed"; entry.error = error.localizedDescription
        entries[id] = entry; save()
    }
}

extension DownloadCoordinator: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Temporary files can be deleted after this delegate callback; move before returning to the queue.
        guard let id = downloadTask.taskDescription else { return }
        let holding = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: location, to: holding)
            Task { @MainActor in self.finished(task: downloadTask, location: holding) }
        } catch {
            Task { @MainActor in self.failed(task: downloadTask, error: error) }
        }
        _ = id
    }
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                               didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                               totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription, totalBytesExpectedToWrite > 0 else { return }
        Task { @MainActor in self.progress[id] = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) }
    }
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        Task { @MainActor in self.failed(task: task, error: error) }
    }
}
