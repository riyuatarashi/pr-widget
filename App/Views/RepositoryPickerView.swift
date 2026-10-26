import SwiftUI

struct RepositoryPickerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var groups: [RepositoryGroup] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var search = ""

    var body: some View {
        List {
            Section {
                Toggle("Tous les repositories accessibles", isOn: $model.settings.watchAll)
            } footer: {
                Text(model.settings.watchAll
                     ? "Toutes les PR où ta review est demandée, dans les repositories auxquels l'app a accès."
                     : "Seules les PR des repositories cochés déclenchent le widget.")
            }

            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }

            if !isLoading && groups.isEmpty && error == nil {
                noAccessSection
            }

            ForEach(filteredGroups) { group in
                Section {
                    ForEach(group.repositories) { repository in
                        row(repository)
                    }
                } header: {
                    Text(group.owner.login)
                } footer: {
                    if let url = group.manageURL {
                        Link("Modifier les repositories accessibles pour \(group.owner.login)", destination: url)
                            .font(.footnote)
                    }
                }
            }

            if model.credentialsKind == .githubApp, let url = AppConfig.installationURL, !groups.isEmpty {
                Section {
                    Link(destination: url) {
                        Label("Installer l'app sur un autre compte ou une organisation", systemImage: "plus.circle")
                    }
                }
            }
        }
        .overlay {
            if isLoading && groups.isEmpty { ProgressView() }
        }
        .navigationTitle("Repositories")
        .searchable(text: $search, prompt: "Filtrer")
        .refreshable { await load() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Au retour de GitHub (accès modifiés), on recharge la liste.
            if phase == .active { Task { await load() } }
        }
    }

    @ViewBuilder
    private var noAccessSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Aucun repository accessible")
                    .font(.headline)
                Text(model.credentialsKind == .githubApp
                     ? "Installe l'app sur ton compte (ou une organisation) et choisis les repositories qu'elle peut voir."
                     : "Ton token n'a accès à aucun repository.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            if model.credentialsKind == .githubApp, let url = AppConfig.installationURL {
                Link(destination: url) {
                    Label("Installer l'app sur GitHub", systemImage: "arrow.up.right.square")
                }
            }
        }
    }

    private func row(_ repository: GitHubRepository) -> some View {
        let isSelected = model.settings.watchAll || model.settings.repositories.contains(repository.fullName)
        return Button {
            toggle(repository.fullName)
        } label: {
            HStack {
                Image(systemName: repository.isPrivate ? "lock.fill" : "book.closed")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text(repository.fullName.split(separator: "/").last.map(String.init) ?? repository.fullName)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.prAccent : Color.secondary)
            }
        }
        .disabled(model.settings.watchAll)
    }

    private var filteredGroups: [RepositoryGroup] {
        guard !search.isEmpty else { return groups }
        return groups.compactMap { group in
            let repositories = group.repositories.filter { $0.fullName.localizedCaseInsensitiveContains(search) }
            return repositories.isEmpty ? nil : RepositoryGroup(owner: group.owner, repositories: repositories, manageURL: group.manageURL)
        }
    }

    private func toggle(_ fullName: String) {
        if let index = model.settings.repositories.firstIndex(of: fullName) {
            model.settings.repositories.remove(at: index)
        } else {
            model.settings.repositories.append(fullName)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            groups = try await model.loadRepositories()
            error = nil

            // Oublie les repositories qui ne sont plus accessibles (retirés de l'app, renommés…).
            let available = Set(groups.flatMap(\.repositories).map(\.fullName))
            let kept = model.settings.repositories.filter { available.contains($0) }
            if kept.count != model.settings.repositories.count {
                model.settings.repositories = kept
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
