import Foundation
import CryptoKit

struct UpdateService {
    struct Release: Decodable {
        let version: String
        let archiveURL: URL
        let checksumURL: URL
        let releaseURL: URL
        let notes: String

        private enum ReleaseCodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case body
            case assets
        }

        private struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL

            private enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: ReleaseCodingKeys.self)
            let tag = try container.decode(String.self, forKey: .tagName)
            let assets = try container.decode([Asset].self, forKey: .assets)
            guard let archive = assets.first(where: { $0.name.hasSuffix("-macOS.zip") }) else {
                throw UpdateError.archiveNotFound
            }
            guard let checksum = assets.first(where: { $0.name == "\(archive.name).sha256" }) else {
                throw UpdateError.checksumNotFound
            }
            version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            archiveURL = archive.browserDownloadURL
            checksumURL = checksum.browserDownloadURL
            releaseURL = try container.decode(URL.self, forKey: .htmlURL)
            notes = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        }
    }

    enum UpdateError: LocalizedError {
        case invalidResponse
        case archiveNotFound
        case checksumNotFound
        case checksumMismatch
        case downloadsFolderUnavailable

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                "GitHub returned an invalid response."
            case .archiveNotFound:
                "The latest release does not contain a macOS ZIP archive."
            case .checksumNotFound:
                "The latest release does not include a SHA-256 checksum."
            case .checksumMismatch:
                "The downloaded archive did not pass its SHA-256 check."
            case .downloadsFolderUnavailable:
                "The Downloads folder could not be found."
            }
        }
    }

    func latestRelease() async throws -> Release {
        let url = URL(string: "https://api.github.com/repos/dmo-code/CommitJet/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CommitJet", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw UpdateError.invalidResponse
        }
        return try JSONDecoder().decode(Release.self, from: data)
    }

    func download(
        _ release: Release,
        progress: @MainActor @Sendable (Double?) -> Void
    ) async throws -> URL {
        var archiveRequest = URLRequest(url: release.archiveURL)
        archiveRequest.setValue("CommitJet", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.bytes(for: archiveRequest)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw UpdateError.invalidResponse
        }

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CommitJet-\(UUID().uuidString).zip")
        guard FileManager.default.createFile(atPath: temporaryURL.path, contents: nil) else {
            throw UpdateError.invalidResponse
        }
        let fileHandle = try FileHandle(forWritingTo: temporaryURL)
        defer {
            try? fileHandle.close()
            try? FileManager.default.removeItem(at: temporaryURL)
        }

        let expectedLength = response.expectedContentLength > 0 ? response.expectedContentLength : nil
        var received: Int64 = 0
        var chunk = Data()
        chunk.reserveCapacity(64 * 1024)
        for try await byte in bytes {
            chunk.append(byte)
            received += 1
            if chunk.count >= 64 * 1024 {
                try fileHandle.write(contentsOf: chunk)
                chunk.removeAll(keepingCapacity: true)
                await progress(expectedLength.map { min(Double(received) / Double($0), 1) })
            }
        }
        if !chunk.isEmpty { try fileHandle.write(contentsOf: chunk) }
        try fileHandle.synchronize()
        await progress(1)

        let (checksumData, checksumResponse) = try await URLSession.shared.data(from: release.checksumURL)
        guard let checksumResponse = checksumResponse as? HTTPURLResponse,
              (200..<300).contains(checksumResponse.statusCode),
              let expectedChecksum = String(data: checksumData, encoding: .utf8)?.split(whereSeparator: \.isWhitespace).first?.lowercased() else {
            throw UpdateError.invalidResponse
        }
        guard try sha256(of: temporaryURL) == expectedChecksum else {
            throw UpdateError.checksumMismatch
        }

        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            throw UpdateError.downloadsFolderUnavailable
        }

        let baseName = "CommitJet-\(release.version)-macOS"
        var destinationURL = downloadsURL.appendingPathComponent("\(baseName).zip")
        var suffix = 2
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            destinationURL = downloadsURL.appendingPathComponent("\(baseName) (\(suffix)).zip")
            suffix += 1
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    private func sha256(of fileURL: URL) throws -> String {
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }
        var hasher = SHA256()
        while let data = try fileHandle.read(upToCount: 1024 * 1024), !data.isEmpty {
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        func components(_ version: String) -> [Int]? {
            let numbers = version.split(separator: ".").compactMap { Int($0) }
            guard !numbers.isEmpty, numbers.count == version.split(separator: ".").count else { return nil }
            return numbers
        }

        guard var candidateParts = components(candidate), var currentParts = components(current) else { return false }
        let count = max(candidateParts.count, currentParts.count)
        candidateParts += Array(repeating: 0, count: count - candidateParts.count)
        currentParts += Array(repeating: 0, count: count - currentParts.count)
        for (new, installed) in zip(candidateParts, currentParts) where new != installed {
            return new > installed
        }
        return false
    }
}
