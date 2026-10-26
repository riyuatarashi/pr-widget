import SwiftUI
import UIKit

struct SignInView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL
    @State private var showsTokenSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header

                    if let code = model.deviceCode {
                        DeviceCodeCard(code: code) {
                            UIPasteboard.general.string = code.userCode
                            openURL(code.verificationURI)
                        } onCancel: {
                            model.cancelGitHubSignIn()
                        }
                    } else {
                        actions
                    }

                    if let error = model.authError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .sheet(isPresented: $showsTokenSheet) {
                TokenSignInView()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Color.prAccent)
                .symbolEffect(.bounce, options: .repeating.speed(0.3))
                .padding(.top, 40)
            Text("PR Radar")
                .font(.largeTitle.bold())
            Text("Une petite cloche sur ton iPhone dès qu'une pull request attend ta review.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 12) {
            if AppConfig.hasGitHubApp {
                Button {
                    model.startGitHubSignIn()
                } label: {
                    Label("Se connecter avec GitHub", systemImage: "person.badge.key.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("Tu autorises l'app sur github.com, sans mot de passe ni token à copier. Tu choisis ensuite les repositories auxquels elle a accès.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Label("Aucune GitHub App n'est configurée : renseigne GITHUB_CLIENT_ID dans Config/Local.xcconfig (voir le README) pour activer la connexion GitHub.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("Utiliser un token personnel") {
                showsTokenSheet = true
            }
            .padding(.top, 8)
        }
    }
}

private struct DeviceCodeCard: View {
    let code: GitHubOAuth.DeviceCode
    let onOpen: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Saisis ce code sur GitHub")
                .font(.headline)

            Text(code.userCode)
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .textSelection(.enabled)
                .padding(.vertical, 6)

            Button {
                onOpen()
            } label: {
                Label("Copier le code et ouvrir GitHub", systemImage: "arrow.up.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack(spacing: 8) {
                ProgressView()
                Text("En attente de ton autorisation…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("Annuler", role: .cancel, action: onCancel)
                .font(.footnote)
        }
        .padding(20)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 20))
    }
}

private struct TokenSignInView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("github_pat_…", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Crée un **fine-grained token** sur github.com › Settings › Developer settings, limité aux repositories voulus, avec la permission **Pull requests : Read-only**. Il est stocké dans le trousseau de l'iPhone.")
                }

                if let error = model.authError {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Token personnel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Connexion") {
                            Task {
                                isSubmitting = true
                                await model.signIn(personalToken: token)
                                isSubmitting = false
                                if model.isSignedIn { dismiss() }
                            }
                        }
                        .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }
}
