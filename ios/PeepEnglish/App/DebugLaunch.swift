import Foundation

/// 시뮬레이터 화면 확인용 실행 인자 (DEBUG 빌드에서만 읽는다).
/// 이 맥에서는 시뮬레이터에 탭을 넣을 수 없어서 화면을 실행 인자로 바로 띄운다.
///   xcrun simctl launch booted com.peep.english -shot lesson
enum DebugLaunch {
    static var args: [String: String] {
        #if DEBUG
        var out: [String: String] = [:]
        let a = ProcessInfo.processInfo.arguments
        var i = 1
        while i < a.count {
            if a[i].hasPrefix("-"), i + 1 < a.count { out[String(a[i].dropFirst())] = a[i + 1]; i += 2 } else { i += 1 }
        }
        return out
        #else
        return [:]
        #endif
    }
    static var shot: String? { args["shot"] }

    static func launcher(default d: Activity.Type) -> Activity.Type {
        #if DEBUG
        if let s = shot, let t = shots[s] { return t }
        #endif
        return d
    }
    static func intent() -> Intent {
        let i = Intent()
        for (k, v) in args where k != "shot" { i.putExtra(k, v) }
        return i
    }
    /// -shot 이름 → 첫 화면
    static var shots: [String: Activity.Type] = [:]
}
