import BackgroundTasks
import Foundation
import WidgetKit

struct RepositoryGroup: Identifiable {
    let owner: GitHubAccount
    let repositories: [GitHubRepository]
    /// Page GitHub où modifier la liste des repositories accessibles à l'app pour ce compte.
    let manageURL: URL?

    var id: String { owner.login }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var credentialsKind: GitHubCredentials.Kind?
    @Published private(set) var login: String?
    @Published private(set) var snapshot: PRSnapshot
    @Published private(set) var isRefreshing = false

    @Published var settings: WatchSettings {
        didSet {
            store.settings = settings
            scheduleRefresh()
        }
    }

    // Connexion via la GitHub App (device flow)
    @Published private(set) var deviceCode: GitHubOAuth.DeviceCode?
    @Published var authError: String?

    private let store = SharedStore.shared
    private var authTask: Task<Void, Never>?
    private var pendingRefresh: Task<Void, Never>?

    var isSignedIn: Bool { credentialsKind != nil }

    init() {
        let store = SharedStore.shared
        credentialsKind = CredentialsStore.load()?.kind
        login = store.login
        snapshot = store.snapshot
        settings = store.settings
    }

    // MARK: Connexion

    func startGitHubSignIn() {
        authTask?.cancel()
        authError = nil
        authTask = Task {
            defer { deviceCode = nil }
            do {
                let code = try await GitHubOAuth.requestDeviceCode()
                deviceCode = code
                let credentials = try await GitHubOAuth.waitForAuthorization(code)
                try await completeSignIn(with: credentials)
            } catch {
                // Une annulation remonte aussi en URLError.cancelled : on ne l'affiche pas.
                if !Task.isCancelled { authError = error.localizedDescription }
            }
        }
    }

    func cancelGitHubSignIn() {
        authTask?.cancel()
        authTask = nil
        deviceCode = nil
    }

    func signIn(personalToken: String) async {
        authError = nil
        let token = personalToken.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await completeSignIn(with: GitHubCredentials(kind: .personalToken, accessToken: token))
        } catch {
            authError = error.localizedDescription
        }
    }

    private func completeSignIn(with credentials: GitHubCredentials) async throws {
        let user = try await GitHubAPI(token: credentials.accessToken).currentUser()
        try CredentialsStore.save(credentials)
        store.login = user.login
        login = user.login
        credentialsKind = credentials.kind
        await refresh()
    }

    func signOut() {
        cancelGitHubSignIn()
        CredentialsStore.clear()
        store.reset()
        credentialsKind = nil
        login = nil
        snapshot = store.snapshot
        settings = store.settings
        pendingRefresh?.cancel()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: PR

    func refresh() async {
        pendingRefresh?.cancel()
        isRefreshing = true
        snapshot = await PRChecker.refresh()
        isRefreshing = false
        if snapshot.status == .signedOut { credentialsKind = nil }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Les réglages changent souvent par rafales (cases cochées dans la liste) : on attend un peu.
    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    func markOpened(_ id: String) {
        store.acknowledge(id)
        snapshot = store.snapshot
        WidgetCenter.shared.reloadAllTimelines()
    }

    func markAllSeen() {
        store.acknowledgeAll()
        snapshot = store.snapshot
        WidgetCenter.shared.reloadAllTimelines()
    }

    func playWidgetDemo() {
        store.requestDemo()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Repositories

    func loadRepositories() async throws -> [RepositoryGroup] {
        guard let token = try await CredentialsStore.validAccessToken() else { return [] }
        let api = GitHubAPI(token: token)

        switch credentialsKind {
        case .githubApp:
            var groups: [RepositoryGroup] = []
            for installation in try await api.installations() {
                let repositories = try await api.repositories(installationID: installation.id)
                groups.append(RepositoryGroup(
                    owner: installation.account,
                    repositories: repositories.filter { $0.archived != true }.sorted { $0.fullName < $1.fullName },
                    manageURL: installation.htmlURL
                ))
            }
            return groups.sorted { $0.owner.login.lowercased() < $1.owner.login.lowercased() }

        case .personalToken, nil:
            let repositories = try await api.userRepositories().filter { $0.archived != true }
            return Dictionary(grouping: repositories, by: \.owner.login)
                .map { _, repos in
                    RepositoryGroup(owner: repos[0].owner, repositories: repos.sorted { $0.fullName < $1.fullName }, manageURL: nil)
                }
                .sorted { $0.owner.login.lowercased() < $1.owner.login.lowercased() }
        }
    }
}

// MARK: - Rafraîchissement en arrière-plan

/// En plus des rechargements du widget, iOS réveille l'app de temps en temps : c'est une chance de plus
/// de repérer une nouvelle PR rapidement.
enum BackgroundRefresh {
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: AppConfig.backgroundRefreshTaskID)
        request.earliestBeginDate = .now.addingTimeInterval(15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func run() async {
        schedule()
        let before = SharedStore.shared.snapshot
        let after = await PRChecker.refresh()
        // Un rechargement demandé depuis l'arrière-plan consomme le budget du widget : seulement si utile.
        if Set(before.pullRequests.map(\.id)) != Set(after.pullRequests.map(\.id)) || before.newIDs != after.newIDs {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
