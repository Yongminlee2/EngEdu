import XCTest

/// 앱 심사 회신용 녹화(지침 2.1 자료 요청): 앱 실행부터 평소 흐름까지 실기기에서 누른다.
/// 글자가 있는 단추는 글자로, 버블·쓰기 판은 화면 좌표로 누른다. 앱은 영어로 띄운다(심사원이 읽게).
/// 말하기 문제에서 마이크·음성 인식 허용 창이 뜨는 것까지 보인다.
/// 앱은 처음 깐 상태여야 한다(record.sh 앞에서 지우고 다시 깐다).
final class ReviewWalkthroughUITests: XCTestCase {
    var app: XCUIApplication!
    var step = 0

    func snap(_ name: String) {
        step += 1
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = String(format: "%02d_", step) + name; shot.lifetime = .keepAlways; add(shot)
    }

    func text(_ label: String, timeout: Double = 6) -> XCUIElement {
        let exact = app.staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch
        if exact.waitForExistence(timeout: timeout) { return exact }
        return app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }

    /// 화면 왼쪽 위의 ◀ 또는 ✕. 그만둘지 묻는 창이 뜨면 그만둔다.
    func back() {
        let close = app.otherElements["그만두기"].firstMatch
        if close.exists && close.isHittable { close.tap(); sleep(2); let q = text("Quit", timeout: 2); if q.exists { q.tap(); sleep(2) }; return }
        let b = text("◀", timeout: 2)
        if b.exists { b.tap() } else {
            let x = app.staticTexts.matching(NSPredicate(format: "label == %@ OR label == %@", "✕", "✖")).firstMatch
            if x.exists { x.tap() } else { point(40, 100).tap() }
        }
        sleep(2)
        let quit = text("Quit", timeout: 1)
        if quit.exists { quit.tap(); sleep(2) }
    }

    /// 시스템 허용 창(마이크·음성 인식)은 springboard 에 뜬다 — 「허용/OK」 를 누른다
    func allowSystemAlerts() {
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<3 {
            let alert = sb.alerts.firstMatch
            guard alert.waitForExistence(timeout: 4) else { return }
            sleep(2)
            let ok = alert.buttons.matching(NSPredicate(format: "label IN %@", ["Allow", "OK", "허용", "확인"])).firstMatch
            if ok.exists { ok.tap() } else { alert.buttons.element(boundBy: alert.buttons.count - 1).tap() }
            sleep(2)
        }
    }

    /// 지금 문제를 한 번 풀어 본다: 보기 자리를 차례로 눌러 「Check」 → 「Keep going」 이 나오면 끝.
    func answerOne(_ name: String) {
        let spots: [(CGFloat, CGFloat)] = [(108, 455), (292, 455), (108, 560), (292, 560), (110, 520), (290, 520)]
        let check = text("Check", timeout: 3)
        for (x, y) in spots {
            point(x, y).tap(); sleep(1)
            if check.exists && check.isHittable { check.tap() }
            sleep(2)
            let cont = text("Keep going", timeout: 2)
            if cont.exists {
                snap(name)
                cont.tap(); sleep(2)
                return
            }
        }
        snap(name + "_stuck")
    }

    func testWalkthrough() {
        app = XCUIApplication(bundleIdentifier: "com.peep.english")
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        sleep(4); snap("home")
        app.swipeUp(); sleep(2); snap("home_scrolled")
        app.swipeDown(); sleep(1); app.swipeDown(); sleep(1)

        // 유아 영어 → 알파벳 쓰기 → A 따라 쓰기(첫 획은 위 초록 동그라미에서 왼쪽 아래로)
        text("Preschool English").tap(); sleep(3); snap("stage_preschool")
        text("Alphabet writing").tap(); sleep(3); snap("alphabet")
        text("A").tap(); sleep(3); snap("trace")
        text("🐥 How do I write it?").tap(); sleep(5); snap("trace_demo")
        point(200, 352).press(forDuration: 0.5, thenDragTo: point(104, 584), withVelocity: 90, thenHoldForDuration: 0.5)
        sleep(1)
        point(200, 352).press(forDuration: 0.5, thenDragTo: point(300, 586), withVelocity: 90, thenHoldForDuration: 0.5)
        sleep(1)
        point(118, 506).press(forDuration: 0.5, thenDragTo: point(242, 506), withVelocity: 90, thenHoldForDuration: 0.5)
        sleep(2); snap("trace_stroke")
        back(); back()

        // 놀이터 → 풍선 터뜨리기
        text("Playground").tap(); sleep(3); snap("playground")
        text("Balloon pop").tap(); sleep(4); snap("game")
        for (x, y) in [(100, 600), (200, 650), (300, 600), (150, 700), (250, 560)] as [(CGFloat, CGFloat)] {
            point(x, y).tap(); sleep(1)
        }
        sleep(2); snap("game_play")
        back(); back(); back()

        // 초등 영어 → 초등 코스 → 첫 레슨, 문제 세 개
        text("Elementary English").tap(); sleep(3); snap("stage_elementary")
        text("Elementary course").tap(); sleep(3); snap("track")
        point(52, 226).tap(); sleep(4); snap("lesson")
        for i in 1...3 { answerOne("question\(i)") }
        back(); back(); back()

        // 영역별 훈련 → 말하기: 미리 듣기 → 🎤 (처음엔 허용 창) → 다시 🎤
        app.swipeUp(); sleep(1)
        text("Skill-by-skill training").tap(); sleep(3)
        text("Speaking").tap(); sleep(3); snap("speaking_track")
        point(52, 226).tap(); sleep(4); snap("speak_question")
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Preview")).firstMatch.tap(); sleep(4)
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Speak")).firstMatch.tap(); sleep(2); snap("permission")
        allowSystemAlerts()
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Speak")).firstMatch.tap(); sleep(7); snap("speak_listening")
        let skip = text("I can't speak right now", timeout: 3)
        if skip.exists { skip.tap(); sleep(3); snap("speak_skipped") }
        back(); back(); back()

        // 지갑·상점 → 통계 → 설정
        app.swipeUp(); sleep(2)
        text("Shop · Cash out").tap(); sleep(3); snap("wallet")
        app.swipeUp(); sleep(2); snap("shop")
        back()
        app.swipeUp(); sleep(1)
        text("Stats").tap(); sleep(3); snap("stats")
        back()
        app.swipeUp(); sleep(1)
        text("Settings").tap(); sleep(3); snap("settings")
        back()
        sleep(2); snap("end")
    }
}
