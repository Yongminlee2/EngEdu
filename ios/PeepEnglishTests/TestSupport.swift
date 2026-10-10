import Foundation
@testable import PeepEnglish

/// 시험들이 같이 쓰는 도우미 — 코틀린 File·Regex 자리.
enum TestSupport {
    static func isFile(_ u: URL) -> Bool {
        var dir: ObjCBool = false
        return FileManager.default.fileExists(atPath: u.path, isDirectory: &dir) && !dir.boolValue
    }

    static func isDirectory(_ u: URL) -> Bool {
        var dir: ObjCBool = false
        return FileManager.default.fileExists(atPath: u.path, isDirectory: &dir) && dir.boolValue
    }

    static func readText(_ u: URL) -> String { (try? String(contentsOf: u, encoding: .utf8)) ?? "" }

    /// app/src/main/assets/packs
    static func packsDir() -> URL {
        precondition(isDirectory(RepoPaths.packs), "packs 디렉터리를 찾을 수 없음: \(RepoPaths.packs.path)")
        return RepoPaths.packs
    }

    static func pack(_ name: String) -> URL { packsDir().appendingPathComponent("\(name).json") }

    /// 팩 하나를 파싱한다 (없으면 nil)
    static func track(_ tid: String) throws -> TrackData? {
        let f = pack(tid)
        guard isFile(f) else { return nil }
        return try ContentRepo.parseTrack(try JSONObject(readText(f)))
    }

    // MARK: - 정규식 (코틀린 Regex 자리)

    /// 걸린 것마다 groupValues
    static func findAll(_ pattern: String, _ s: String, _ options: NSRegularExpression.Options = []) -> [[String]] {
        let re = try! NSRegularExpression(pattern: pattern, options: options)
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { m in
            (0..<m.numberOfRanges).map {
                let r = m.range(at: $0)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
        }
    }

    static func find(_ pattern: String, _ s: String, _ options: NSRegularExpression.Options = []) -> [String]? {
        findAll(pattern, s, options).first
    }

    static func containsMatch(_ pattern: String, _ s: String) -> Bool { find(pattern, s) != nil }
}
