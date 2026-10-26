import SwiftUI

@main
struct PRRadarApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { BackgroundRefresh.schedule() }
        }
        .backgroundTask(.appRefresh(AppConfig.backgroundRefreshTaskID)) {
            await BackgroundRefresh.run()
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if model.isSignedIn {
                HomeView()
            } else {
                SignInView()
            }
        }
        .tint(.prAccent)
        .onOpenURL { url in
            guard case .pullRequest(let id, let target)? = DeepLink(url: url) else { return }
            model.markOpened(id)
            openURL(target)
        }
    }
}
