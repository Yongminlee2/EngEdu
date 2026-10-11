import XCTest

/// 녹화 순서를 맞출 때 쓰는 탐색 시험: 화면을 찍고 화면 요소 목록을 첨부로 남긴다.
final class ProbeUITests: XCTestCase {
    func testProbe() {
        let app = XCUIApplication(bundleIdentifier: ProcessInfo.processInfo.environment["BUNDLE"] ?? "com.peep.english")
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        sleep(4)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "01_home"; shot.lifetime = .keepAlways; add(shot)
        let tree = XCTAttachment(string: app.debugDescription); tree.name = "02_tree"; tree.lifetime = .keepAlways; add(tree)
    }
}
