import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                statusSection
                pullRequestsSection
                watchSection
                widgetSection
                accountSection
            }
            .navigationTitle("PR Radar")
            .refreshable { await model.refresh() }
            .toolbar {
                if model.isRefreshing {
                    ToolbarItem(placement: .topBarTrailing) { ProgressView() }
                }
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active { Task { await model.refresh() } }
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var statusSection: some View {
        switch model.snapshot.status {
        case .authExpired:
            Section {
                Label("Ta session GitHub a expiré.", systemImage: "key.fill")
                Button("Se reconnecter") { model.signOut() }
            }
        case .failed(let message):
            Section {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        case .ok, .signedOut:
            EmptyView()
        }
    }

    private var pullRequestsSection: some View {
        Section {
            if model.snapshot.pullRequests.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Tout est calme", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(Color.prLeaf)
                    Text("Aucune pull request n'attend ta review.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            } else {
                ForEach(model.snapshot.pullRequests) { pr in
                    Button {
                        model.markOpened(pr.id)
                        openURL(pr.url)
                    } label: {
                        PullRequestRow(pr: pr, isNew: model.snapshot.newIDs.contains(pr.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            HStack {
                Text("En attente de ta review")
                Spacer()
                if !model.snapshot.newIDs.isEmpty {
                    Button("Tout marquer comme vu") { model.markAllSeen() }
                        .font(.caption)
                        .textCase(nil)
                }
            }
        } footer: {
            if model.snapshot.fetchedAt > .distantPast {
                Text("Mis à jour \(model.snapshot.fetchedAt.formatted(.relative(presentation: .named))).")
            }
        }
    }

    private var watchSection: some View {
        Section("Surveillance") {
            NavigationLink {
                RepositoryPickerView()
            } label: {
                LabeledContent("Repositories", value: watchSummary)
            }
            Toggle("Inclure les PR qui me sont assignées", isOn: $model.settings.includeAssigned)
            Toggle("Ignorer les brouillons", isOn: $model.settings.ignoreDrafts)
        }
    }

    private var widgetSection: some View {
        Section {
            Button {
                model.playWidgetDemo()
            } label: {
                Label("Tester l'animation du widget", systemImage: "bell.and.waves.left.and.right")
            }
        } header: {
            Text("Widget")
        } footer: {
            Text("Pour le mode StandBy : écran d'accueil › appui long › Modifier › Ajouter un widget › PR Radar (petit format). Pose ensuite l'iPhone en charge, à l'horizontale ou plié en tente, puis balaie jusqu'à la pile de widgets et ajoute PR Radar. Le widget se met à jour toutes les 10 à 20 minutes environ (rythme fixé par iOS) ; touche l'heure en bas du widget moyen ou grand pour forcer une vérification.")
        }
    }

    private var accountSection: some View {
        Section {
            if let login = model.login {
                LabeledContent("Connecté en tant que", value: "@\(login)")
            }
            if model.credentialsKind == .githubApp, let url = AppConfig.installationURL {
                Link(destination: url) {
                    Label("Gérer l'accès de l'app sur GitHub", systemImage: "arrow.up.right.square")
                }
            }
            Button("Se déconnecter", role: .destructive) { model.signOut() }
        } header: {
            Text("Compte")
        } footer: {
            if model.credentialsKind == .personalToken {
                Text("Connecté avec un token personnel.")
            }
        }
    }

    private var watchSummary: String {
        if model.settings.watchAll { return "Tous" }
        let count = model.settings.repositories.count
        return count == 0 ? "Aucun" : "\(count) sélectionné\(count > 1 ? "s" : "")"
    }
}

private struct PullRequestRow: View {
    let pr: PullRequestSummary
    let isNew: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: pr.authorAvatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.tertiary)
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(pr.repository) #\(pr.number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if isNew {
                        Text("Nouvelle")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.prOnAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.prAccent, in: .capsule)
                    }
                }
                Text(pr.title)
                    .font(.body.weight(.medium))
                    .lineLimit(3)
                HStack(spacing: 6) {
                    Text("\(pr.author) · \(pr.createdAt.formatted(.relative(presentation: .named)))")
                    if pr.isDraft { Label("Brouillon", systemImage: "pencil.circle") }
                    if pr.reasons.contains(.assigned) { Image(systemName: "person.fill.checkmark") }
                    if pr.reasons.contains(.reviewRequested) { Image(systemName: "eye") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
