import Foundation

/// Récupère les PR qui attendent l'utilisateur, utilisé à la fois par le widget et par l'app.
enum PRChecker {
    @discardableResult
    static func refresh(now: Date = .now) async -> PRSnapshot {
        let store = SharedStore.shared
        var snapshot = store.snapshot

        do {
            guard let token = try await CredentialsStore.validAccessToken() else {
                snapshot = PRSnapshot(status: .signedOut, pullRequests: [], newIDs: [], fetchedAt: now)
                store.snapshot = snapshot
                return snapshot
            }

            let pullRequests = try await fetchPullRequests(api: GitHubAPI(token: token), settings: store.settings)
            let (sorted, newIDs) = store.register(pullRequests, now: now)
            snapshot = PRSnapshot(status: .ok, pullRequests: sorted, newIDs: newIDs, fetchedAt: now)
        } catch GitHubAPIError.unauthorized {
            snapshot.status = .authExpired
        } catch {
            // On garde les dernières PR connues : mieux vaut un widget un peu en retard qu'un widget vide.
            snapshot.status = .failed(error.localizedDescription)
        }

        store.snapshot = snapshot
        return snapshot
    }

    static func fetchPullRequests(api: GitHubAPI, settings: WatchSettings) async throws -> [PullRequestSummary] {
        if !settings.watchAll && settings.repositories.isEmpty { return [] }

        var base = "is:pr is:open archived:false"
        if settings.ignoreDrafts { base += " draft:false" }

        // `review-requested` couvre aussi les demandes faites à une équipe dont on fait partie.
        var filters: [(qualifier: String, reason: PullRequestSummary.Reason)] = [("review-requested:@me", .reviewRequested)]
        if settings.includeAssigned { filters.append(("assignee:@me", .assigned)) }

        // Plusieurs `repo:` dans une même requête sont combinés en OU ; on découpe pour rester sous
        // les limites de longueur de la recherche GitHub.
        let repoGroups: [[String]] = settings.watchAll ? [[]] : settings.repositories.sorted().chunked(into: 12)

        var byID: [String: PullRequestSummary] = [:]
        for group in repoGroups {
            for filter in filters {
                let items = try await search(api: api, terms: [base, filter.qualifier], repositories: group)
                for item in items {
                    let summary = PullRequestSummary(item: item, reason: filter.reason)
                    byID[summary.id, default: summary].reasons.insert(filter.reason)
                }
            }
        }
        return Array(byID.values)
    }

    /// GitHub rejette (422) toute la requête si un seul `repo:` n'est plus accessible (repo supprimé,
    /// renommé, retiré de l'app) : on retente alors repo par repo en ignorant ceux qui posent problème.
    private static func search(api: GitHubAPI, terms: [String], repositories: [String]) async throws -> [GitHubIssueItem] {
        let query = (terms + repositories.map { "repo:\($0)" }).joined(separator: " ")
        do {
            return try await api.searchPullRequests(query)
        } catch GitHubAPIError.http(422, _) where !repositories.isEmpty {
            guard repositories.count > 1 else { return [] }
            var items: [GitHubIssueItem] = []
            for repository in repositories {
                items += try await search(api: api, terms: terms, repositories: [repository])
            }
            return items
        }
    }
}

private extension PullRequestSummary {
    init(item: GitHubIssueItem, reason: Reason) {
        self.init(
            number: item.number,
            title: item.title,
            repository: item.repositoryFullName,
            author: item.user.login,
            authorAvatarURL: item.user.avatarURL,
            url: item.htmlURL,
            createdAt: item.createdAt,
            isDraft: item.draft ?? false,
            reasons: [reason]
        )
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
