import Foundation

// MARK: - Modèle de l'app (persisté pour le widget)

struct PullRequestSummary: Codable, Hashable, Identifiable {
    enum Reason: String, Codable {
        case reviewRequested
        case assigned
    }

    /// "owner/repo#123" : stable et lisible.
    var id: String { "\(repository)#\(number)" }

    let number: Int
    let title: String
    let repository: String
    let author: String
    let authorAvatarURL: URL?
    let url: URL
    let createdAt: Date
    let isDraft: Bool
    var reasons: Set<Reason>

    var repositoryName: String {
        repository.split(separator: "/").last.map(String.init) ?? repository
    }
}

struct PRSnapshot: Codable {
    enum Status: Codable, Equatable {
        case ok
        case signedOut
        case authExpired
        case failed(String)
    }

    var status: Status
    var pullRequests: [PullRequestSummary]
    /// PR considérées comme « nouvelles » (pas encore ouvertes, arrivées récemment).
    var newIDs: Set<String>
    var fetchedAt: Date

    static let empty = PRSnapshot(status: .signedOut, pullRequests: [], newIDs: [], fetchedAt: .distantPast)

    var newPullRequests: [PullRequestSummary] {
        pullRequests.filter { newIDs.contains($0.id) }
    }
}

struct WatchSettings: Codable, Equatable {
    /// `true` : tous les repositories accessibles par l'app. Sinon uniquement `repositories`.
    var watchAll = true
    var repositories: [String] = []
    var includeAssigned = true
    var ignoreDrafts = false
}

// MARK: - Réponses de l'API GitHub

struct GitHubAccount: Codable, Hashable {
    let login: String
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case login
        case avatarURL = "avatar_url"
    }
}

struct GitHubUser: Codable {
    let login: String
    let name: String?
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case login, name
        case avatarURL = "avatar_url"
    }
}

struct GitHubInstallation: Decodable, Identifiable {
    let id: Int
    let account: GitHubAccount
    let repositorySelection: String
    let htmlURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, account
        case repositorySelection = "repository_selection"
        case htmlURL = "html_url"
    }
}

struct GitHubInstallationsPage: Decodable {
    let installations: [GitHubInstallation]
}

struct GitHubRepository: Decodable, Identifiable, Hashable {
    let id: Int
    let fullName: String
    let owner: GitHubAccount
    let isPrivate: Bool
    let archived: Bool?

    enum CodingKeys: String, CodingKey {
        case id, owner, archived
        case fullName = "full_name"
        case isPrivate = "private"
    }
}

struct GitHubRepositoriesPage: Decodable {
    let repositories: [GitHubRepository]
}

struct GitHubSearchPage: Decodable {
    let totalCount: Int
    let items: [GitHubIssueItem]

    enum CodingKeys: String, CodingKey {
        case items
        case totalCount = "total_count"
    }
}

struct GitHubIssueItem: Decodable {
    let number: Int
    let title: String
    let htmlURL: URL
    let repositoryURL: URL
    let user: GitHubAccount
    let createdAt: Date
    let draft: Bool?

    enum CodingKeys: String, CodingKey {
        case number, title, user, draft
        case htmlURL = "html_url"
        case repositoryURL = "repository_url"
        case createdAt = "created_at"
    }

    /// `https://api.github.com/repos/owner/repo` → `owner/repo`
    var repositoryFullName: String {
        repositoryURL.pathComponents.suffix(2).joined(separator: "/")
    }
}
