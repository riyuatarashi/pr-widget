import AppIntents
import WidgetKit

/// Bouton « rafraîchir » du widget : WidgetKit recharge la timeline une fois l'intent terminé.
struct RefreshPullRequestsIntent: AppIntent {
    static var title: LocalizedStringResource = "Rafraîchir les PR"
    static var description = IntentDescription("Vérifie s'il y a de nouvelles pull requests à reviewer.")

    func perform() async throws -> some IntentResult {
        await PRChecker.refresh()
        return .result()
    }
}
