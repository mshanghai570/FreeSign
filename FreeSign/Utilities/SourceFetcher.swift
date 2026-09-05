import Foundation

// MARK: - SourceFetchResult

struct SourceFetchResult: Identifiable {
    var id: String { url }
    let url: String
    let source: Source?
    let error: String?
    var succeeded: Bool { source != nil }
}

// MARK: - SourceFetcher

/// Actor-based service that downloads and parses IPA repository JSON feeds.
///
/// Supported formats:
///  • AltStore / SideStore   (apps[].versions[].downloadURL)
///  • Legacy AltStore        (apps[].downloadURL directly)
///  • Havoc / Flyinghead     (apps[].versions[] with different key names)
///  • Plain JSON array        ([{ name, bundleIdentifier, downloadURL }])
actor SourceFetcher {

    static let shared = SourceFetcher()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 20
        cfg.timeoutIntervalForResource = 60
        return URLSession(configuration: cfg)
    }()

    // MARK: - Public API

    /// Fetch and parse a single repository URL.
    func fetchSource(urlString: String) async -> SourceFetchResult {
        guard let url = URL(string: urlString),
              url.scheme == "http" || url.scheme == "https"
        else {
            return SourceFetchResult(url: urlString, source: nil, error: "Invalid URL.")
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                return SourceFetchResult(url: urlString, source: nil, error: "HTTP \(code).")
            }
            let source = try parse(data: data, sourceURL: urlString)
            return SourceFetchResult(url: urlString, source: source, error: nil)
        } catch let err as SourceParseError {
            return SourceFetchResult(url: urlString, source: nil, error: err.localizedDescription)
        } catch {
            return SourceFetchResult(url: urlString, source: nil, error: error.localizedDescription)
        }
    }

    /// Fetch multiple URLs concurrently, returning one result per URL in the same order.
    func fetchSources(urlStrings: [String]) async -> [SourceFetchResult] {
        await withTaskGroup(of: (Int, SourceFetchResult).self) { group in
            for (i, url) in urlStrings.enumerated() {
                group.addTask { (i, await self.fetchSource(urlString: url)) }
            }
            var results = Array(repeating: SourceFetchResult(url: "", source: nil, error: nil),
                                count: urlStrings.count)
            for await (i, result) in group { results[i] = result }
            return results
        }
    }

    // MARK: - JSON Parsing

    private func parse(data: Data, sourceURL: String) throws -> Source {
        guard let raw = try? JSONSerialization.jsonObject(with: data) else {
            throw SourceParseError.invalidJSON
        }

        // ── Format A: plain array of apps ──────────────────────────────────
        if let appArray = raw as? [[String: Any]] {
            let apps = parseApps(appArray)
            let host = URL(string: sourceURL)?.host ?? sourceURL
            return Source(
                id: UUID(), name: host, url: sourceURL,
                iconURL: nil, description: nil,
                dateAdded: Date(), lastFetched: Date(),
                apps: apps
            )
        }

        // ── Format B: standard object with "apps" key ──────────────────────
        guard let dict = raw as? [String: Any] else { throw SourceParseError.unsupportedFormat }

        let name        = dict["name"]        as? String ?? dict["identifier"] as? String
                       ?? URL(string: sourceURL)?.host ?? sourceURL
        let description = dict["description"] as? String
        let iconURL     = dict["iconURL"]     as? String

        let rawApps = dict["apps"] as? [[String: Any]] ?? []
        let apps = parseApps(rawApps)

        return Source(
            id: UUID(), name: name, url: sourceURL,
            iconURL: iconURL, description: description,
            dateAdded: Date(), lastFetched: Date(),
            apps: apps
        )
    }

    private func parseApps(_ rawApps: [[String: Any]]) -> [SourceApp] {
        rawApps.compactMap { dict -> SourceApp? in
            // Required fields
            guard let name = dict["name"] as? String else { return nil }
            let bundleID = dict["bundleIdentifier"] as? String
                        ?? dict["bundleID"]         as? String
                        ?? dict["bundle_id"]        as? String
                        ?? ""

            // ── Resolve the latest version ─────────────────────────────────
            let (version, downloadURL, sizeBytes, versionDate, minOS) = resolveVersion(from: dict)

            guard !downloadURL.isEmpty else { return nil }

            let developer   = dict["developerName"]   as? String
                           ?? dict["developer"]        as? String
                           ?? dict["author"]           as? String
                           ?? "Unknown"

            let description = dict["localizedDescription"] as? String
                           ?? dict["description"]          as? String

            let iconURL = dict["iconURL"] as? String ?? dict["icon"] as? String
            let category = dict["category"] as? String

            return SourceApp(
                id:                   UUID(),
                name:                 name,
                bundleID:             bundleID,
                developerName:        developer,
                version:              version,
                versionDate:          versionDate,
                size:                 sizeBytes,
                iconURL:              iconURL,
                downloadURL:          downloadURL,
                localizedDescription: description,
                category:             category,
                minOSVersion:         minOS,
                permissions:          []
            )
        }
    }

    /// Extracts version/URL/size from both legacy (flat) and versioned (array) formats.
    private func resolveVersion(from dict: [String: Any])
        -> (version: String, downloadURL: String, size: Int64?, date: Date?, minOS: String?)
    {
        // ── Versioned format: versions[] ──────────────────────────────────
        if let versions = dict["versions"] as? [[String: Any]], let latest = versions.first {
            let ver  = latest["version"]     as? String ?? dict["version"] as? String ?? "1.0"
            let url  = latest["downloadURL"] as? String
                    ?? latest["download"]    as? String ?? ""
            let size = (latest["size"] as? Int64)
                    ?? (latest["size"] as? Int).map(Int64.init)
            let minOS = latest["minimumOSVersion"] as? String
                     ?? latest["minOSVersion"]      as? String
            let date = parseDate(latest["date"] as? String)
            return (ver, url, size, date, minOS)
        }

        // ── Legacy flat format ────────────────────────────────────────────
        let ver  = dict["version"]     as? String ?? "1.0"
        let url  = dict["downloadURL"] as? String
                ?? dict["download"]    as? String ?? ""
        let size = (dict["size"] as? Int64)
                ?? (dict["size"] as? Int).map(Int64.init)
        let minOS = dict["minimumOSVersion"] as? String
                 ?? dict["minOSVersion"]      as? String
        let date = parseDate(dict["versionDate"] as? String ?? dict["date"] as? String)
        return (ver, url, size, date, minOS)
    }

    // ISO-8601 and "YYYY-MM-DD" formats
    private let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return f
    }()
    private let ymdFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        return iso8601Formatter.date(from: s) ?? ymdFormatter.date(from: s)
    }
}

// MARK: - URL Extraction Helper

extension SourceFetcher {
    /// Extracts all http(s):// URLs from arbitrary text using NSDataDetector.
    static func extractURLs(from text: String) -> [String] {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else { return [] }

        let range = NSRange(text.startIndex..., in: text)
        return detector
            .matches(in: text, range: range)
            .compactMap { match -> String? in
                guard let url = match.url,
                      url.scheme == "http" || url.scheme == "https"
                else { return nil }
                return url.absoluteString
            }
    }
}

// MARK: - Errors

enum SourceParseError: LocalizedError {
    case invalidJSON, unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .invalidJSON:       return "The response is not valid JSON."
        case .unsupportedFormat: return "Unrecognised repository format."
        }
    }
}
