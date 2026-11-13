import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol RecordingSource: Sendable {
    func search(_ query: String, page: Int) async throws -> [CatalogHit]
    func recent() async throws -> [CatalogHit]
    func recording(id: String) async throws -> Concert
}

struct InternetArchiveSource: RecordingSource {
    private let session: URLSession = .shared

    func search(_ query: String, page: Int = 1) async throws -> [CatalogHit] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return try await recent() }
        let escaped = cleaned.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return try await lookup(q: "mediatype:etree AND (title:\"\(escaped)\" OR creator:\"\(escaped)\" OR venue:\"\(escaped)\")", page: page, sort: "downloads desc")
    }

    func recent() async throws -> [CatalogHit] {
        try await lookup(q: "mediatype:etree", page: 1, sort: "publicdate desc")
    }

    func onThisDay(monthDay: String) async throws -> [CatalogHit] {
        // Date is the performance date, never the upload date; response still filtered locally.
        let response = try await lookup(q: "mediatype:etree AND date:*\(monthDay)*", page: 1, sort: "downloads desc")
        return response.filter { $0.date?.contains(monthDay) == true }
    }

    private func lookup(q: String, page: Int, sort: String) async throws -> [CatalogHit] {
        var url = URLComponents(string: "https://archive.org/advancedsearch.php")!
        url.queryItems = [
            .init(name: "q", value: q), .init(name: "output", value: "json"),
            .init(name: "rows", value: "40"), .init(name: "page", value: String(max(1, page))),
            .init(name: "sort[]", value: sort),
            .init(name: "fl[]", value: "identifier"), .init(name: "fl[]", value: "title"),
            .init(name: "fl[]", value: "creator"), .init(name: "fl[]", value: "date"),
            .init(name: "fl[]", value: "venue")
        ]
        guard let endpoint = url.url else { throw TaperError.invalidURL }
        let (data, response) = try await session.data(from: endpoint)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw TaperError.invalidResponse }
        let result = try JSONDecoder().decode(SearchResponse.self, from: data)
        return result.response.docs.map { doc in
            CatalogHit(id: doc.identifier, title: doc.title?.text ?? doc.identifier,
                       artist: doc.creator?.text ?? "Unknown artist", date: doc.date?.text,
                       venue: doc.venue?.text)
        }
    }

    func recording(id: String) async throws -> Concert {
        guard let safe = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://archive.org/metadata/\(safe)") else { throw TaperError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw TaperError.invalidResponse }
        let item = try JSONDecoder().decode(ArchiveItem.self, from: data)
        let meta = item.metadata
        let valid = item.files.filter { file in
            let name = file.name.lowercased()
            return name.hasSuffix(".mp3") || name.hasSuffix(".flac")
        }.filter { $0.privateFlag?.text.lowercased() != "true" && $0.source?.lowercased() != "metadata" }
        var groups: [String: [AudioVariant]] = [:]
        var names: [String: String] = [:]
        var durations: [String: TimeInterval] = [:]
        var insertion: [String] = []
        for file in valid {
            let codec: AudioCodec = file.name.lowercased().hasSuffix(".flac") ? .flac : .mp3
            guard let escapedName = file.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let fileURL = URL(string: "https://archive.org/download/\(safe)/\(escapedName)") else { continue }
            // Archive derivatives vary by suffix; keep full filename by default to avoid wrongly merging different recordings.
            let base = file.name.replacingOccurrences(of: "(?i)(\\.vbr|_64kb|_128kb|_256kb|_320kb)?\\.(mp3|flac)$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "(?i)\\.flac$", with: "", options: .regularExpression)
            let key = base.lowercased()
            if groups[key] == nil { insertion.append(key) }
            let variant = AudioVariant(id: "\(id)|\(file.name)", codec: codec, url: fileURL,
                                       bytes: Int64(file.size ?? ""), trackKey: key)
            groups[key, default: []].append(variant)
            if names[key] == nil { names[key] = file.title?.text ?? base }
            if let duration = TimeInterval(file.length ?? "") { durations[key] = duration }
        }
        let tracks = insertion.enumerated().map { index, key in
            Track(id: "\(id)|\(key)", title: names[key] ?? "Track \(index + 1)",
                  sequence: index + 1, duration: durations[key], variants: groups[key] ?? [])
        }
        let restriction = meta.rights?.text ?? meta.licenseurl?.text
        let noDownload = item.isDark == true || meta.noDownload?.text == "true"
        return Concert(id: id, artist: meta.creator?.text ?? "Unknown artist",
                       title: meta.title?.text ?? id, performanceDate: meta.date?.text,
                       venue: meta.venue?.text, location: meta.coverage?.text,
                       taper: meta.taper?.text, source: meta.source?.text,
                       rights: restriction, downloadable: !noDownload && !tracks.isEmpty, tracks: tracks)
    }
}

private struct SearchResponse: Decodable { let response: Body; struct Body: Decodable { let docs: [Document] } }
private struct Document: Decodable {
    let identifier: String
    let title, creator, date, venue: StringOrArray?
}
private struct ArchiveItem: Decodable {
    let metadata: Metadata
    let files: [ArchiveFile]
    let isDark: Bool?
    enum CodingKeys: String, CodingKey { case metadata, files, isDark = "is_dark" }
}
private struct Metadata: Decodable {
    let creator, title, date, venue, coverage, taper, source, rights, licenseurl: StringOrArray?
    let noDownload: StringOrArray?
    enum CodingKeys: String, CodingKey {
        case creator, title, date, venue, coverage, taper, source, rights, licenseurl
        case noDownload = "no-download"
    }
}
private struct ArchiveFile: Decodable {
    let name: String
    let size, length, source: String?
    let title: StringOrArray?
    let privateFlag: StringOrArray?
    enum CodingKeys: String, CodingKey { case name, size, length, source, title; case privateFlag = "private" }
}
private struct StringOrArray: Decodable {
    let text: String
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { text = s }
        else if let strings = try? c.decode([String].self) { text = strings.first ?? "" }
        else if let n = try? c.decode(Int.self) { text = String(n) }
        else { text = "" }
    }
}
