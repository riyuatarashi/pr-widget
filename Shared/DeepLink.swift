import Foundation

/// Liens `prradar://` ouverts depuis le widget.
enum DeepLink {
    case home
    case pullRequest(id: String, url: URL)

    var url: URL {
        var components = URLComponents()
        components.scheme = AppConfig.urlScheme
        switch self {
        case .home:
            components.host = "home"
        case .pullRequest(let id, let url):
            components.host = "pr"
            components.queryItems = [
                URLQueryItem(name: "id", value: id),
                URLQueryItem(name: "url", value: url.absoluteString),
            ]
        }
        return components.url!
    }

    init?(url: URL) {
        guard url.scheme == AppConfig.urlScheme else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = { (name: String) in items.first { $0.name == name }?.value }

        switch url.host {
        case "pr":
            guard let id = value("id"), let target = value("url").flatMap(URL.init(string:)) else { return nil }
            self = .pullRequest(id: id, url: target)
        default:
            self = .home
        }
    }

    static func open(_ pr: PullRequestSummary) -> URL {
        DeepLink.pullRequest(id: pr.id, url: pr.url).url
    }
}
