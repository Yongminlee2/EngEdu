import Foundation

/// 시험이 안드로이드 원본(문제 팩·strings.xml·Db.kt)을 저장소에서 바로 읽는다.
enum RepoPaths {
    /// .../EngEdu (저장소 뿌리)
    static let repo: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // PeepEnglishTests
        .deletingLastPathComponent()   // ios
        .deletingLastPathComponent()
    /// app/src/main
    static let androidMain = repo.appendingPathComponent("app/src/main")
    static let packs = androidMain.appendingPathComponent("assets/packs")
    static let res = androidMain.appendingPathComponent("res")
    static func read(_ rel: String) -> String { (try? String(contentsOf: androidMain.appendingPathComponent(rel), encoding: .utf8)) ?? "" }
}
