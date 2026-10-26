import Foundation

struct GitHubCredentials: Codable, Equatable {
    enum Kind: String, Codable {
        /// Token utilisateur obtenu via la GitHub App (device flow).
        case githubApp
        /// Token personnel collé à la main (solution de repli).
        case personalToken
    }

    var kind: Kind
    var accessToken: String
    var expiresAt: Date?
    var refreshToken: String?
    var refreshTokenExpiresAt: Date?

    var needsRefresh: Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSinceNow < 120
    }
}

enum AuthError: LocalizedError {
    case notConfigured
    case expired
    case denied
    case github(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Aucune GitHub App n'est configurée (GITHUB_CLIENT_ID)."
        case .expired: "Le code a expiré, recommence la connexion."
        case .denied: "Autorisation refusée sur GitHub."
        case .github(let message): message
        }
    }
}

// MARK: - Stockage

enum CredentialsStore {
    private static let account = "github-credentials"

    static func load() -> GitHubCredentials? {
        guard let data = Keychain.read(account: account) else { return nil }
        return try? JSONDecoder().decode(GitHubCredentials.self, from: data)
    }

    static func save(_ credentials: GitHubCredentials) throws {
        try Keychain.save(JSONEncoder().encode(credentials), account: account)
    }

    static func clear() {
        Keychain.delete(account: account)
    }

    /// Renvoie un token utilisable, en le rafraîchissant si la GitHub App fait expirer les tokens.
    static func validAccessToken() async throws -> String? {
        guard let credentials = load() else { return nil }
        guard credentials.needsRefresh else { return credentials.accessToken }

        guard let refreshToken = credentials.refreshToken,
              (credentials.refreshTokenExpiresAt ?? .distantFuture) > .now
        else { throw GitHubAPIError.unauthorized }

        do {
            let refreshed = try await GitHubOAuth.refresh(refreshToken: refreshToken)
            try save(refreshed)
            return refreshed.accessToken
        } catch {
            // L'app et le widget peuvent rafraîchir en même temps ; un refresh token ne sert qu'une
            // fois. Si l'autre processus a gagné la course, on récupère simplement son token.
            if let current = load(), current.accessToken != credentials.accessToken, !current.needsRefresh {
                return current.accessToken
            }
            throw GitHubAPIError.unauthorized
        }
    }
}

// MARK: - OAuth (device flow)

/// Connexion « Sign in with GitHub » sans client secret ni redirection :
/// GitHub affiche son écran d'autorisation, on y saisit un code court, et l'app récupère le token.
enum GitHubOAuth {
    struct DeviceCode: Decodable {
        let deviceCode: String
        let userCode: String
        let verificationURI: URL
        let expiresIn: Int
        let interval: Int

        enum CodingKeys: String, CodingKey {
            case deviceCode = "device_code"
            case userCode = "user_code"
            case verificationURI = "verification_uri"
            case expiresIn = "expires_in"
            case interval
        }
    }

    private struct TokenResponse: Decodable {
        let accessToken: String?
        let expiresIn: Int?
        let refreshToken: String?
        let refreshTokenExpiresIn: Int?
        let error: String?
        let errorDescription: String?
        let interval: Int?

        enum CodingKeys: String, CodingKey {
            case interval, error
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
            case refreshTokenExpiresIn = "refresh_token_expires_in"
            case errorDescription = "error_description"
        }

        var credentials: GitHubCredentials? {
            guard let accessToken else { return nil }
            return GitHubCredentials(
                kind: .githubApp,
                accessToken: accessToken,
                expiresAt: expiresIn.map { Date.now.addingTimeInterval(TimeInterval($0)) },
                refreshToken: refreshToken,
                refreshTokenExpiresAt: refreshTokenExpiresIn.map { Date.now.addingTimeInterval(TimeInterval($0)) }
            )
        }
    }

    static func requestDeviceCode() async throws -> DeviceCode {
        guard AppConfig.hasGitHubApp else { throw AuthError.notConfigured }
        let data = try await post("https://github.com/login/device/code", form: [
            "client_id": AppConfig.githubClientID,
        ])
        if let code = try? JSONDecoder().decode(DeviceCode.self, from: data) {
            return code
        }
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        throw AuthError.github(response.errorDescription ?? response.error ?? "Réponse inattendue de GitHub.")
    }

    /// Interroge GitHub jusqu'à ce que l'utilisateur ait autorisé l'app (ou refusé, ou laissé expirer).
    static func waitForAuthorization(_ code: DeviceCode) async throws -> GitHubCredentials {
        var interval = max(code.interval, 5)
        let deadline = Date.now.addingTimeInterval(TimeInterval(code.expiresIn))

        while Date.now < deadline {
            try await Task.sleep(for: .seconds(interval))

            let data = try await post("https://github.com/login/oauth/access_token", form: [
                "client_id": AppConfig.githubClientID,
                "device_code": code.deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            ])
            let response = try JSONDecoder().decode(TokenResponse.self, from: data)

            if let credentials = response.credentials { return credentials }

            switch response.error {
            case "authorization_pending":
                continue
            case "slow_down":
                interval = response.interval ?? interval + 5
            case "expired_token":
                throw AuthError.expired
            case "access_denied":
                throw AuthError.denied
            default:
                throw AuthError.github(response.errorDescription ?? response.error ?? "Erreur inconnue.")
            }
        }
        throw AuthError.expired
    }

    /// Utile seulement si l'option « Expire user authorization tokens » est cochée dans la GitHub App.
    static func refresh(refreshToken: String) async throws -> GitHubCredentials {
        let data = try await post("https://github.com/login/oauth/access_token", form: [
            "client_id": AppConfig.githubClientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
        ])
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let credentials = response.credentials else {
            throw AuthError.github(response.errorDescription ?? response.error ?? "Refresh impossible.")
        }
        return credentials
    }

    private static func post(_ url: String, form: [String: String]) async throws -> Data {
        var components = URLComponents()
        components.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }

        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}
