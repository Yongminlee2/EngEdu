import Foundation
import UIKit

// 안드로이드 Application 자리. 아이폰에는 앱 객체를 바꿔 끼울 일이 없어 정적 함수만 둔다.
// 시스템 바 여백(fitSystemBarsEverywhere)은 Droid 의 Activity 가 이미 처리한다.

/// 앱이 죽으면 그 이유를 파일에 남긴다 — 나중에 설정 화면에서 꺼내 볼 수 있게.
/// 앱 시작 때 `PiyakApp.install()` 을 한 번 부른다.
enum PiyakApp {

    private static var installed = false
    private static var previousHandler: (@convention(c) (NSException) -> Void)? = nil
    /// 신호 처리기 안에서는 새로 만들 수 없는 것들을 미리 마련해 둔다
    private static var crashPath = ""
    private static var versionName = "?"

    static func install() {
        if installed { return }
        installed = true
        crashPath = crashFile(AppContext.shared).path
        versionName = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"

        // 오브젝트-C 예외
        previousHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler { e in
            let trace = "\(e.name.rawValue): \(e.reason ?? "")\n" + e.callStackSymbols.joined(separator: "\n")
            PiyakApp.save(trace)
            // 원래 처리(앱 종료·시스템 보고)는 그대로 이어 준다
            PiyakApp.previousHandler?(e)
        }

        // 스위프트 런타임 오류(강제 언랩·fatalError)는 신호로 온다
        for sig in [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGTRAP] {
            signal(sig) { s in
                PiyakApp.save("Signal \(PiyakApp.signalName(s)) (\(s))\n" + Thread.callStackSymbols.joined(separator: "\n"))
                // 기본 처리로 되돌려 다시 일으킨다 — 시스템 크래시 보고가 그대로 남는다
                signal(s, SIG_DFL)
                raise(s)
            }
        }
    }

    fileprivate static func signalName(_ s: Int32) -> String {
        switch s {
        case SIGABRT: return "SIGABRT"
        case SIGSEGV: return "SIGSEGV"
        case SIGBUS: return "SIGBUS"
        case SIGILL: return "SIGILL"
        case SIGTRAP: return "SIGTRAP"
        default: return "SIG\(s)"
        }
    }

    fileprivate static func save(_ trace: String) {
        // 같은 죽음이 예외 → SIGABRT 로 두 번 올 수 있다. 먼저 적은 것(더 자세한 쪽)을 지킨다.
        if savedOnce { return }
        savedOnce = true
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fmt.locale = Locale(identifier: "ko_KR")
        let when_ = fmt.string(from: Date())
        let threadName: String = {
            if Thread.isMainThread { return "main" }
            let n = Thread.current.name ?? ""
            return n.isEmpty ? "\(Thread.current)" : n
        }()
        let text = "때: \(when_)\n스레드: \(threadName)\n앱: \(versionName)\n\n\(trace)"
        let path = crashPath.isEmpty ? crashFile(AppContext.shared).path : crashPath
        try? text.write(toFile: path, atomically: true, encoding: .utf8)
    }
    private static var savedOnce = false

    static func crashFile(_ app: Context) -> URL { app.filesDir.appendingPathComponent("last_crash.txt") }

    /// 마지막으로 죽은 기록 (없으면 nil)
    static func lastCrash(_ app: Context) -> String? {
        let f = crashFile(app)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: f.path, isDirectory: &isDir), !isDir.boolValue else { return nil }
        guard let s = try? String(contentsOf: f, encoding: .utf8) else { return nil }
        return s.isBlank() ? nil : s
    }

    static func clearCrash(_ app: Context) {
        try? FileManager.default.removeItem(at: crashFile(app))
    }
}
