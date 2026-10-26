import Foundation

/// Valeurs injectées dans les Info.plist depuis Config/*.xcconfig.
enum AppConfig {
    static let githubClientID = infoValue("GitHubClientID")
    static let githubAppSlug = infoValue("GitHubAppSlug")
    static let appGroup = infoValue("AppGroupIdentifier")

    static let widgetKind = "PRRadarWidget"
    static let backgroundRefreshTaskID = "prradar.refresh"
    static let urlScheme = "prradar"

    /// Vrai quand une GitHub App a été renseignée : la connexion OAuth (device flow) est alors possible.
    static var hasGitHubApp: Bool { !githubClientID.isEmpty }

    /// Page GitHub où l'on installe l'app et choisit les repositories auxquels elle a accès.
    static var installationURL: URL? {
        guard !githubAppSlug.isEmpty else { return nil }
        return URL(string: "https://github.com/apps/\(githubAppSlug)/installations/new")
    }

    private static func infoValue(_ key: String) -> String {
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
