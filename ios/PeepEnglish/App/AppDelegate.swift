import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        PiyakApp.install()
        R.register()
        Bindings.registerCustomViews()
        #if DEBUG
        DebugLaunch.shots = [
            "main": MainActivity.self, "track": TrackActivity.self, "lesson": LessonActivity.self,
            "placement": PlacementActivity.self, "stats": StatsActivity.self,
            "settings": SettingsActivity.self, "wallet": WalletActivity.self,
            "stage": StageActivity.self, "alphabet": AlphabetActivity.self, "trace": TraceActivity.self,
            "playground": PlaygroundActivity.self, "game": GameActivity.self,
        ]
        #endif
        return true
    }
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask { .portrait }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        window = w
        DroidHost.shared.start(in: w, launcher: DebugLaunch.launcher(default: MainActivity.self), intent: DebugLaunch.intent())
    }
}
