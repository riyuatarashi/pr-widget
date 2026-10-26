import WidgetKit

struct PREntry: TimelineEntry {
    /// Étapes de la petite animation « nouvelle PR » : la cloche tinte deux fois, puis se pose.
    /// Chaque étape est une entrée de timeline ; WidgetKit anime le passage de l'une à l'autre.
    enum Phase: Int, Comparable {
        case calm, ring, swing, ringAgain, settle

        static let alertSequence: [Phase] = [.ring, .swing, .ringAgain, .settle]
        static let stepDuration: TimeInterval = 1.2

        static func < (lhs: Phase, rhs: Phase) -> Bool { lhs.rawValue < rhs.rawValue }

        var bellAngle: Double {
            switch self {
            case .ring: -22
            case .swing: 16
            case .ringAgain: -10
            case .calm, .settle: 0
            }
        }
    }

    let date: Date
    let snapshot: PRSnapshot
    let spotlight: PullRequestSummary?
    var avatar: Data? = nil
    var phase: Phase = .calm

    var count: Int { snapshot.pullRequests.count }
    var isAlerting: Bool { !snapshot.newIDs.isEmpty }

    func isNew(_ pr: PullRequestSummary) -> Bool { snapshot.newIDs.contains(pr.id) }

    /// Les autres PR, sous la carte mise en avant.
    var others: [PullRequestSummary] {
        snapshot.pullRequests.filter { $0.id != spotlight?.id }
    }
}

extension PRSnapshot {
    var spotlight: PullRequestSummary? { newPullRequests.first ?? pullRequests.first }
}

struct PRTimelineProvider: TimelineProvider {
    private static let refreshInterval: TimeInterval = 10 * 60

    func placeholder(in context: Context) -> PREntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (PREntry) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }
        let snapshot = SharedStore.shared.snapshot
        completion(PREntry(date: .now, snapshot: snapshot, spotlight: snapshot.spotlight))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PREntry>) -> Void) {
        let family = context.family
        Task {
            let now = Date.now
            let store = SharedStore.shared
            let widgetKey = "\(family)"

            var snapshot = await PRChecker.refresh(now: now)
            var announced = store.takeAnnouncement(from: snapshot, widgetKey: widgetKey, now: now)
            if announced == nil, store.takeDemo(widgetKey: widgetKey, now: now) {
                let demo = PullRequestSummary.demo(createdAt: now)
                snapshot.pullRequests.insert(demo, at: 0)
                snapshot.newIDs.insert(demo.id)
                announced = demo
            }

            let spotlight = announced ?? snapshot.spotlight
            var avatar: Data?
            if family.showsAvatar, let url = spotlight?.authorAvatarURL {
                avatar = await GitHubAPI.imageData(url, size: 96)
            }

            let base = PREntry(date: now, snapshot: snapshot, spotlight: spotlight, avatar: avatar)
            let entries: [PREntry]
            if announced != nil {
                entries = PREntry.Phase.alertSequence.enumerated().map { index, phase in
                    var entry = PREntry(
                        date: now.addingTimeInterval(Double(index) * PREntry.Phase.stepDuration),
                        snapshot: snapshot,
                        spotlight: spotlight,
                        avatar: avatar
                    )
                    entry.phase = phase
                    return entry
                }
            } else {
                entries = [base]
            }

            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(Self.refreshInterval))))
        }
    }
}

private extension WidgetFamily {
    var showsAvatar: Bool {
        switch self {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge: true
        default: false
        }
    }
}

extension PullRequestSummary {
    static func demo(createdAt: Date) -> PullRequestSummary {
        PullRequestSummary(
            number: 42,
            title: "Démo : c'est ici qu'apparaîtra ta prochaine PR à reviewer",
            repository: "pr-radar/demo",
            author: "octocat",
            authorAvatarURL: URL(string: "https://avatars.githubusercontent.com/u/583231"),
            url: URL(string: "https://github.com/pulls/review-requested")!,
            createdAt: createdAt,
            isDraft: false,
            reasons: [.reviewRequested]
        )
    }
}

extension PREntry {
    static let sample: PREntry = {
        let now = Date.now
        let prs = [
            PullRequestSummary(
                number: 128, title: "Ajoute le cache des avatars dans le widget", repository: "acme/mobile",
                author: "lea-dev", authorAvatarURL: nil, url: URL(string: "https://github.com")!,
                createdAt: now.addingTimeInterval(-600), isDraft: false, reasons: [.reviewRequested]
            ),
            PullRequestSummary(
                number: 64, title: "Corrige la pagination de l'API", repository: "acme/api",
                author: "tom", authorAvatarURL: nil, url: URL(string: "https://github.com")!,
                createdAt: now.addingTimeInterval(-7200), isDraft: false, reasons: [.reviewRequested]
            ),
            PullRequestSummary(
                number: 12, title: "Mise à jour des dépendances", repository: "acme/web",
                author: "renovate", authorAvatarURL: nil, url: URL(string: "https://github.com")!,
                createdAt: now.addingTimeInterval(-86_400), isDraft: true, reasons: [.assigned]
            ),
        ]
        let snapshot = PRSnapshot(status: .ok, pullRequests: prs, newIDs: [prs[0].id], fetchedAt: now)
        return PREntry(date: now, snapshot: snapshot, spotlight: prs[0])
    }()
}
