import Foundation

nonisolated struct FileContent: Sendable {
    let path: String
    let data: Data
    let metadata: FileMetadata

    var text: String {
        String(decoding: data, as: UTF8.self)
    }
}

actor SilverBulletClient {
    private let config: SilverBulletConfig
    private let session: URLSession
    private var cachedServerConfiguration: ServerConfiguration?

    init(config: SilverBulletConfig, session: URLSession? = nil) {
        self.config = config
        self.session = session ?? Self.makeDefaultSession()
    }

    nonisolated static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    func ping() async throws -> Bool {
        let request = try makeRequest(path: "/.ping", method: "GET")
        let (data, response) = try await perform(request)
        let body = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return response.statusCode == 200 && body == "OK"
    }

    func serverConfiguration(forceRefresh: Bool = false) async throws -> ServerConfiguration {
        if !forceRefresh, let cachedServerConfiguration {
            return cachedServerConfiguration
        }

        let request = try makeRequest(path: "/.config", method: "GET")
        let (data, _) = try await perform(request)

        do {
            let serverConfiguration = try JSONDecoder().decode(
                ServerConfiguration.self,
                from: data
            )
            cachedServerConfiguration = serverConfiguration
            return serverConfiguration
        } catch {
            throw SilverBulletError.decoding(
                message: "Failed to decode /.config: \(error.localizedDescription)"
            )
        }
    }

    func list() async throws -> [SpaceFile] {
        let serverConfiguration = try await serverConfiguration()
        let request = try makeRequest(path: "/.fs", method: "GET")
        let (data, _) = try await perform(request)

        do {
            let files = try JSONDecoder().decode([SpaceFile].self, from: data)
            guard serverConfiguration.readOnly else {
                return files
            }

            return files.map {
                SpaceFile(
                    path: $0.path,
                    lastModified: $0.lastModified,
                    permission: .readOnly,
                    size: $0.size
                )
            }
        } catch {
            throw SilverBulletError.decoding(
                message: "Failed to decode /.fs listing: \(error.localizedDescription)"
            )
        }
    }

    func read(path: String) async throws -> FileContent {
        let serverConfiguration = try await serverConfiguration()
        let request = try makeRequest(path: fsPath(for: path), method: "GET")
        let (data, response) = try await perform(request)
        let metadata = FileMetadata.parse(from: response)
            .applyingServerReadOnly(serverConfiguration.readOnly)
        return FileContent(path: path, data: data, metadata: metadata)
    }

    func readMeta(path: String) async throws -> FileMetadata {
        let serverConfiguration = try await serverConfiguration()
        var request = try makeRequest(path: fsPath(for: path), method: "GET")
        request.setValue("true", forHTTPHeaderField: "X-Get-Meta")
        let (_, response) = try await perform(request)
        return FileMetadata.parse(from: response)
            .applyingServerReadOnly(serverConfiguration.readOnly)
    }

    @discardableResult
    func write(path: String, content: Data) async throws -> FileMetadata {
        let serverConfiguration = try await serverConfiguration()
        guard !serverConfiguration.readOnly else {
            throw SilverBulletError.readOnly(path: path)
        }

        var request = try makeRequest(path: fsPath(for: path), method: "PUT")
        request.httpBody = content
        request.setValue("text/markdown", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await perform(request)
        return FileMetadata.parse(from: response)
    }

    @discardableResult
    func write(path: String, content: String) async throws -> FileMetadata {
        try await write(path: path, content: Data(content.utf8))
    }

    func delete(path: String) async throws {
        let serverConfiguration = try await serverConfiguration()
        guard !serverConfiguration.readOnly else {
            throw SilverBulletError.readOnly(path: path)
        }

        let request = try makeRequest(path: fsPath(for: path), method: "DELETE")
        _ = try await perform(request)
    }

    private func fsPath(for filePath: String) -> String {
        let normalized = filePath.hasPrefix("/") ? String(filePath.dropFirst()) : filePath
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/%?#")

        let encodedSegments = normalized
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { segment -> String in
                String(segment).addingPercentEncoding(withAllowedCharacters: allowed)
                    ?? String(segment)
            }

        return "/.fs/" + encodedSegments.joined(separator: "/")
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard var components = URLComponents(
            url: config.baseURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw SilverBulletError.invalidURL(path: path)
        }

        components.percentEncodedPath = components.percentEncodedPath
            .appendingPathPreservingEncoding(path)

        guard let url = components.url else {
            throw SilverBulletError.invalidURL(path: path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("true", forHTTPHeaderField: "X-Sync-Mode")
        if !config.token.isEmpty {
            request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw SilverBulletError.transport(message: error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SilverBulletError.transport(message: "Non-HTTP response.")
        }

        if http.url?.path.contains("/.auth") == true {
            throw SilverBulletError.unauthorized
        }

        switch http.statusCode {
        case 200...299:
            return (data, http)
        case 401, 403:
            throw SilverBulletError.unauthorized
        case 404:
            throw SilverBulletError.notFound(path: request.url?.path ?? "")
        case 405:
            throw SilverBulletError.readOnly(path: request.url?.path ?? "")
        case 500...599:
            throw SilverBulletError.serverUnavailable(status: http.statusCode)
        default:
            let snippet = String(decoding: data.prefix(512), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw SilverBulletError.http(status: http.statusCode, body: snippet)
        }
    }
}

private extension String {
    nonisolated func appendingPathPreservingEncoding(_ encodedPath: String) -> String {
        var base = self
        while base.hasSuffix("/") {
            base.removeLast()
        }
        return base + encodedPath
    }
}
