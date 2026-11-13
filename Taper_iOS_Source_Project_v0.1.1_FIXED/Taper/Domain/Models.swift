import Foundation

enum AudioCodec: String, Codable, CaseIterable, Identifiable {
    case mp3 = "MP3"
    case flac = "FLAC"
    var id: String { rawValue }
}

struct AudioVariant: Codable, Hashable, Identifiable {
    let id: String
    let codec: AudioCodec
    let url: URL
    let bytes: Int64?
    let trackKey: String
}

struct Track: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let sequence: Int
    let duration: TimeInterval?
    let variants: [AudioVariant]
    func preferred(_ codec: AudioCodec) -> AudioVariant? {
        variants.first(where: { $0.codec == codec }) ?? variants.first(where: { $0.codec == .mp3 }) ?? variants.first
    }
}

struct Concert: Codable, Hashable, Identifiable {
    let id: String                     // Archive item ID = unique recording, never combined with other tapers
    let artist: String
    let title: String
    let performanceDate: String?
    let venue: String?
    let location: String?
    let taper: String?
    let source: String?
    let rights: String?
    let downloadable: Bool
    var tracks: [Track]
    var archiveURL: URL { URL(string: "https://archive.org/details/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)")! }
    var subtitle: String { [performanceDate, venue, location].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ") }
}

struct CatalogHit: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let artist: String
    let date: String?
    let venue: String?
    var subtitle: String { [date, venue].compactMap { $0 }.joined(separator: " · ") }
}

enum TaperError: LocalizedError {
    case invalidURL, invalidResponse, noAudio, unavailable(String)
    var errorDescription: String? {
        switch self {
        case .invalidURL: "The provider returned an invalid URL."
        case .invalidResponse: "The archive sent a response Taper could not read."
        case .noAudio: "No supported MP3 or FLAC files were found for this recording."
        case .unavailable(let message): message
        }
    }
}
