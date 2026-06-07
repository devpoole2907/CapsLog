import Foundation
import Observation

@MainActor
@Observable
final class ConnectionViewModel {
    enum Status: Equatable {
        case unknown
        case checking
        case reachable
        case reachableWithWarning(String)
        case unreachable(String)
    }

    var urlString = ""
    var token = ""

    private(set) var status: Status = .unknown
    private(set) var activeConfig: SilverBulletConfig?
    private(set) var configurationID = UUID()
    private var validationTask: Task<Void, Never>?

    var isConfigured: Bool {
        activeConfig != nil
    }

    var serverDescription: String {
        activeConfig?.baseURL.absoluteString
            ?? "Add your self-hosted notes server"
    }

    private let defaultsURLKey = "capslog.serverURL"

    func makeClient() -> SilverBulletClient {
        guard let activeConfig else {
            fatalError("A SilverBullet client was requested before configuration.")
        }
        return SilverBulletClient(config: activeConfig)
    }

    func loadSavedConfiguration() {
        if let savedURL = UserDefaults.standard.string(forKey: defaultsURLKey) {
            urlString = savedURL
        }
        if let savedToken = KeychainStore.loadToken() {
            token = savedToken
        }

        activeConfig = SilverBulletConfig(rawURL: urlString, token: token)
    }

    func validateAndSave() async {
        guard let validConfig = SilverBulletConfig(rawURL: urlString, token: token) else {
            status = .unreachable("Enter a valid HTTP or HTTPS URL including the host.")
            return
        }

        status = .checking
        let client = SilverBulletClient(config: validConfig)

        do {
            guard try await client.ping() else {
                status = .unreachable("Server did not respond with OK to /.ping.")
                return
            }

            // Unlike /.ping, /.config is authenticated and verifies the token.
            _ = try await client.serverConfiguration()

            guard !Task.isCancelled else {
                status = .unknown
                return
            }

            let warning = persist(validConfig)
            activeConfig = validConfig
            configurationID = UUID()

            if let warning {
                status = .reachableWithWarning(warning)
            } else {
                status = .reachable
            }
        } catch let error as SilverBulletError {
            guard !Task.isCancelled else {
                status = .unknown
                return
            }
            status = .unreachable(error.userMessage)
        } catch is CancellationError {
            status = .unknown
        } catch {
            guard !Task.isCancelled else {
                status = .unknown
                return
            }
            status = .unreachable(error.localizedDescription)
        }
    }

    func startValidation() {
        validationTask?.cancel()
        validationTask = Task { [weak self] in
            await self?.validateAndSave()
        }
    }

    func cancelValidation() {
        validationTask?.cancel()
        validationTask = nil
        if status == .checking {
            status = .unknown
        }
    }

    func disconnect() {
        validationTask?.cancel()
        validationTask = nil
        try? KeychainStore.deleteToken()
        UserDefaults.standard.removeObject(forKey: defaultsURLKey)
        urlString = ""
        token = ""
        status = .unknown
        activeConfig = nil
        configurationID = UUID()
    }

    private func persist(_ config: SilverBulletConfig) -> String? {
        urlString = config.baseURL.absoluteString
        UserDefaults.standard.set(urlString, forKey: defaultsURLKey)

        do {
            try KeychainStore.saveToken(token)
            return nil
        } catch {
            return "Connected, but the token could not be saved to Keychain."
        }
    }
}
