import Foundation
import Combine

@MainActor final class LibraryStore: ObservableObject {
    @Published private(set) var favorites: Set<String> = []
    @Published private(set) var history: [String] = []
    @Published private(set) var cached: [String: Concert] = [:]
    @Published private(set) var resume: [String: Double] = [:]
    @Published var preferredCodec: AudioCodec = .mp3 { didSet { save() } }
    @Published var wifiOnly = true { didSet { save() } }

    private let file: URL
    private struct Snapshot: Codable {
        let favorites: Set<String>
        let history: [String]
        let cached: [String: Concert]
        let resume: [String: Double]
        let preferredCodec: AudioCodec
        let wifiOnly: Bool
    }
    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Taper", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        file = folder.appendingPathComponent("library.json")
        if let data = try? Data(contentsOf: file), let s = try? JSONDecoder().decode(Snapshot.self, from: data) {
            favorites = s.favorites; history = s.history; cached = s.cached; resume = s.resume
            preferredCodec = s.preferredCodec; wifiOnly = s.wifiOnly
        }
    }
    func put(_ concert: Concert) { cached[concert.id] = concert; save() }
    func toggle(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        save()
    }
    func heard(_ id: String) { history.removeAll { $0 == id }; history.insert(id, at: 0); history = Array(history.prefix(100)); save() }
    func remember(_ key: String, _ time: Double) { resume[key] = time; save() }
    func localMatches(_ text: String) -> [Concert] {
        let term = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let values = Array(cached.values)
        guard !term.isEmpty else { return values.sorted { $0.id > $1.id } }
        return values.filter { [$0.artist, $0.title, $0.performanceDate ?? "", $0.venue ?? "", $0.location ?? ""]
            .joined(separator: " ").localizedCaseInsensitiveContains(term) }
    }
    private func save() {
        let s = Snapshot(favorites: favorites, history: history, cached: cached, resume: resume,
                         preferredCodec: preferredCodec, wifiOnly: wifiOnly)
        guard let data = try? JSONEncoder().encode(s) else { return }
        try? data.write(to: file, options: .atomic)
    }
}
