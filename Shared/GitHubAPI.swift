import Foundation

enum GitHubAPIError: LocalizedError {
    case unauthorized
    case rateLimited(resetAt: Date?)
    case http(Int, String?)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Session GitHub expirée, reconnecte-toi."
        case .rateLimited(let resetAt):
            if let resetAt {
                "Limite de l'API GitHub atteinte, réessai après \(resetAt.formatted(date: .omitted, time: .shortened))."
            } else {
                "Limite de l'API GitHub atteinte."
            }
        case .http(let status, let message):
            "GitHub a répondu \(status)\(message.map { " : \($0)" } ?? "")."
        }
    }
}

struct GitHubAPI {
    let token: String
    var session: URLSession = .shared

    private static let baseURL = "https://api.github.com"

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: Endpoints

    func currentUser() async throws -> GitHubUser {
        let (user, _): (GitHubUser, HTTPURLResponse) = try await get("/user")
        return user
    }

    /// Comptes (perso / organisations) sur lesquels la GitHub App est installée.
    func installations() async throws -> [GitHubInstallation] {
        try await paginated("/user/installations") { (page: GitHubInstallationsPage) in page.installations }
    }

    /// Repositories qu'une installation donne à l'app (ceux choisis lors de l'installation).
    func repositories(installationID: Int) async throws -> [GitHubRepository] {
        try await paginated("/user/installations/\(installationID)/repositories") { (page: GitHubRepositoriesPage) in
            page.repositories
        }
    }

    /// Pour un token personnel : tous les repositories accessibles.
    func userRepositories() async throws -> [GitHubRepository] {
        try await paginated(
            "/user/repos",
            query: [
                URLQueryItem(name: "affiliation", value: "owner,collaborator,organization_member"),
                URLQueryItem(name: "sort", value: "pushed"),
            ]
        ) { (page: [GitHubRepository]) in page }
    }

    func searchPullRequests(_ query: String) async throws -> [GitHubIssueItem] {
        let (page, _): (GitHubSearchPage, HTTPURLResponse) = try await get("/search/issues", query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sort", value: "created"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "per_page", value: "50"),
        ])
        return page.items
    }

    /// Les avatars sont publics : pas besoin du token.
    static func imageData(_ url: URL, size: Int) async -> Data? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = (components?.queryItems ?? []) + [URLQueryItem(name: "s", value: String(size))]
        guard let url = components?.url else { return nil }
        return try? await URLSession.shared.data(from: url).0
    }

    // MARK: Plomberie

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> (T, HTTPURLResponse) {
        var components = URLComponents(string: Self.baseURL + path)!
        if !query.isEmpty { components.queryItems = query }
        return try await get(components.url!)
    }

    private func get<T: Decodable>(_ url: URL) async throws -> (T, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse

        let isRateLimited = http.statusCode == 429
            || (http.statusCode == 403 && http.value(forHTTPHeaderField: "x-ratelimit-remaining") == "0")

        switch http.statusCode {
        case 200..<300:
            return (try Self.decoder.decode(T.self, from: data), http)
        case 401:
            throw GitHubAPIError.unauthorized
        case _ where isRateLimited:
            let reset = http.value(forHTTPHeaderField: "x-ratelimit-reset")
                .flatMap(TimeInterval.init)
                .map(Date.init(timeIntervalSince1970:))
            throw GitHubAPIError.rateLimited(resetAt: reset)
        default:
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw GitHubAPIError.http(http.statusCode, message)
        }
    }

    private func paginated<Page: Decodable, Item>(
        _ path: String,
        query: [URLQueryItem] = [],
        items: (Page) -> [Item]
    ) async throws -> [Item] {
        var components = URLComponents(string: Self.baseURL + path)!
        components.queryItems = query + [URLQueryItem(name: "per_page", value: "100")]

        var next: URL? = components.url
        var all: [Item] = []
        while let url = next, all.count < 1_000 {
            let (page, response): (Page, HTTPURLResponse) = try await get(url)
            all += items(page)
            next = Self.nextPageURL(response.value(forHTTPHeaderField: "Link"))
        }
        return all
    }

    /// `<https://api.github.com/...&page=2>; rel="next", <...>; rel="last"`
    static func nextPageURL(_ linkHeader: String?) -> URL? {
        guard let linkHeader else { return nil }
        for part in linkHeader.split(separator: ",") {
            let sections = part.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard sections.count >= 2, sections.dropFirst().contains("rel=\"next\"") else { continue }
            return URL(string: sections[0].trimmingCharacters(in: CharacterSet(charactersIn: "<>")))
        }
        return nil
    }
}
