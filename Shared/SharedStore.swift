import Foundation

/// Données partagées entre l'app et le widget (UserDefaults de l'App Group).
final class SharedStore: @unchecked Sendable {
    static let shared = SharedStore()

    /// Une PR reste « nouvelle » tant qu'on ne l'a pas ouverte, au plus 24 h.
    static let newWindow: TimeInterval = 24 * 3600
    /// L'animation n'est jouée que si la PR a été détectée il y a moins de 45 min.
    static let announceWindow: TimeInterval = 45 * 60
    /// On oublie une PR absente des résultats depuis 3 jours (tolère les résultats de recherche incomplets).
    static let forgetAfter: TimeInterval = 3 * 24 * 3600

    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: AppConfig.appGroup) ?? .standard
    }

    // MARK: Réglages

    var settings: WatchSettings {
        get { value(forKey: "settings") ?? WatchSettings() }
        set {
            guard newValue != settings else { return }
            setValue(newValue, forKey: "settings")
            // Les PR déjà ouvertes dans des repos fraîchement ajoutés ne doivent pas déclencher d'alerte.
            hasBaseline = false
        }
    }

    var login: String? {
        get { defaults.string(forKey: "login") }
        set { defaults.set(newValue, forKey: "login") }
    }

    var snapshot: PRSnapshot {
        get { value(forKey: "snapshot") ?? .empty }
        set { setValue(newValue, forKey: "snapshot") }
    }

    func reset() {
        for key in ["settings", "login", "snapshot", "seen", "hasBaseline", "acknowledged", "announced", "demo"] {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: Détection des nouvelles PR

    private struct SeenRecord: Codable {
        var firstSeen: Date
        var lastSeen: Date
    }

    private var seen: [String: SeenRecord] {
        get { value(forKey: "seen") ?? [:] }
        set { setValue(newValue, forKey: "seen") }
    }

    private var hasBaseline: Bool {
        get { defaults.bool(forKey: "hasBaseline") }
        set { defaults.set(newValue, forKey: "hasBaseline") }
    }

    private var acknowledged: Set<String> {
        get { value(forKey: "acknowledged") ?? [] }
        set { setValue(newValue, forKey: "acknowledged") }
    }

    /// Enregistre le résultat d'une recherche et renvoie les PR triées (les plus récemment arrivées
    /// en premier) ainsi que celles à mettre en avant comme nouvelles.
    func register(_ pullRequests: [PullRequestSummary], now: Date) -> (sorted: [PullRequestSummary], newIDs: Set<String>) {
        var seen = seen
        // Première synchro (ou réglages modifiés) : ce qui est déjà là n'est pas « nouveau ».
        let firstDetection = hasBaseline ? now : .distantPast
        for pr in pullRequests {
            if var record = seen[pr.id] {
                record.lastSeen = now
                seen[pr.id] = record
            } else {
                seen[pr.id] = SeenRecord(firstSeen: firstDetection, lastSeen: now)
            }
        }
        seen = seen.filter { now.timeIntervalSince($0.value.lastSeen) < Self.forgetAfter }
        self.seen = seen
        hasBaseline = true

        let acknowledged = acknowledged.filter { seen[$0] != nil }
        self.acknowledged = acknowledged

        let newIDs = Set(pullRequests.map(\.id).filter { id in
            guard let record = seen[id], !acknowledged.contains(id) else { return false }
            return now.timeIntervalSince(record.firstSeen) < Self.newWindow
        })

        let sorted = pullRequests.sorted { lhs, rhs in
            let l = seen[lhs.id]?.firstSeen ?? .distantPast
            let r = seen[rhs.id]?.firstSeen ?? .distantPast
            return l != r ? l > r : lhs.createdAt > rhs.createdAt
        }
        return (sorted, newIDs)
    }

    /// Appelé quand on ouvre une PR (depuis le widget ou l'app) : elle n'est plus « nouvelle ».
    func acknowledge(_ id: String) {
        acknowledged.insert(id)
        var snapshot = snapshot
        snapshot.newIDs.remove(id)
        self.snapshot = snapshot
    }

    func acknowledgeAll() {
        var snapshot = snapshot
        acknowledged.formUnion(snapshot.newIDs)
        snapshot.newIDs = []
        self.snapshot = snapshot
    }

    // MARK: Animation du widget

    private var announced: [String: Set<String>] {
        get { value(forKey: "announced") ?? [:] }
        set { setValue(newValue, forKey: "announced") }
    }

    /// Renvoie la PR à annoncer (avec animation) pour une taille de widget donnée, une seule fois par PR.
    /// La clé par taille permet d'animer à la fois le widget StandBy et celui de l'écran d'accueil.
    func takeAnnouncement(from snapshot: PRSnapshot, widgetKey: String, now: Date) -> PullRequestSummary? {
        let seen = seen
        var announced = announced
        let alreadyAnnounced = announced[widgetKey] ?? []

        let candidates = snapshot.newPullRequests.filter { pr in
            guard !alreadyAnnounced.contains(pr.id), let record = seen[pr.id] else { return false }
            return now.timeIntervalSince(record.firstSeen) < Self.announceWindow
        }
        announced[widgetKey] = alreadyAnnounced.intersection(snapshot.newIDs).union(candidates.map(\.id))
        self.announced = announced
        return candidates.first
    }

    // MARK: Démo

    private struct DemoState: Codable {
        var requestedAt: Date
        var playedBy: Set<String>
    }

    /// « Tester l'animation » dans l'app : le widget rejouera l'animation à sa prochaine mise à jour.
    func requestDemo() {
        setValue(DemoState(requestedAt: .now, playedBy: []), forKey: "demo")
    }

    func takeDemo(widgetKey: String, now: Date) -> Bool {
        guard var demo: DemoState = value(forKey: "demo"),
              now.timeIntervalSince(demo.requestedAt) < 600,
              !demo.playedBy.contains(widgetKey)
        else { return false }
        demo.playedBy.insert(widgetKey)
        setValue(demo, forKey: "demo")
        return true
    }

    // MARK: Codable <-> UserDefaults

    private func value<T: Decodable>(forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func setValue<T: Encodable>(_ value: T, forKey key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
