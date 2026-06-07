import Foundation

nonisolated enum SilverBulletError: Error, Equatable, Sendable {
    case invalidURL(path: String)
    case transport(message: String)
    case serverUnavailable(status: Int)
    case http(status: Int, body: String?)
    case unauthorized
    case notFound(path: String)
    case decoding(message: String)
    case readOnly(path: String)

    var userMessage: String {
        switch self {
        case .invalidURL(let path):
            return "Couldn't build a valid URL for “\(path)”. Check the server address."
        case .transport(let message):
            return "Network error: \(message)"
        case .serverUnavailable(let status):
            return "The SilverBullet server is temporarily unavailable (HTTP \(status))."
        case .http(let status, let body):
            if let body, !body.isEmpty {
                return "Server returned HTTP \(status): \(body)"
            }
            return "Server returned HTTP \(status)."
        case .unauthorized:
            return "Authentication failed. Check your auth token."
        case .notFound(let path):
            return "Not found: \(path)"
        case .decoding(let message):
            return "Couldn't read the server response: \(message)"
        case .readOnly(let path):
            return "“\(path)” is read-only and can't be saved."
        }
    }

    var isRetryableOfflineFailure: Bool {
        switch self {
        case .transport, .serverUnavailable:
            true
        default:
            false
        }
    }
}

extension SilverBulletError: LocalizedError {
    var errorDescription: String? {
        userMessage
    }
}
