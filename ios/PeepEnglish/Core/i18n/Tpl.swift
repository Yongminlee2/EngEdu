import Foundation

// 코틀린 `Tpl.init(ctx)` 는 스위프트에서 init 이 예약어라 `Tpl.initialize(ctx)` 로 옮겼다.

/// 문제 팩의 번역 키를 **폰 언어의 문장으로 조립한다.**
///
/// 팩에는 한국어 원문과 함께 `tk`(뼈대 키) + `ta`(끼워 넣을 값)가 실려 있다.
///   tk = "e8755f8c",  ta = ["다섯", "5", "🍎🍎🍎🍎🍎"]
///   tpl_e8755f8c(en) = "Count one by one: %1$s. That's %2$s in all. %3$s"
/// 번역이 없는 뼈대는 한국어 원문을 그대로 쓴다. 한국어 폰에서는 아무 일도 하지 않는다.
enum Tpl {

    private static var res: Resources? = nil
    private static var pkg: String = ""
    private static var passthrough = true

    /// 이 폰이 한국어인가. 한국어면 팩에 실린 한국어를 **그대로** 쓴다.
    /// 다른 언어일 때만 그림 보기처럼 언어를 안 타는 방식으로 바꿔 준다.
    static var isKorean: Bool { passthrough }

    /// "tpl_<키>" → 리소스 id. 0 은 "번역 없음"으로 캐시된다
    private static var ids: [String: Int] = [:]

    /// 인자·선택지 안에 박혀 오는 한국어 낱말 (사과·쿠키·삼각형 …)
    private static var wordDict: [String: String] = [:]

    /// 답 옆에 붙는 단위 (개·명·분·원 …)
    private static var unitDict: [String: String] = [:]

    static func initialize(_ ctx: Context) {
        let c = ctx.applicationContext
        let r = c.resources
        // 앱 안에서 고른 언어가 있으면 그게 우선이다.
        let picked = AppCompatDelegate.getApplicationLocales()
        let lang = !picked.isEmpty ? picked.get(0)!.language
                                   : (r.configuration.locales.get(0)?.language ?? "")
        res = r
        pkg = c.packageName
        passthrough = lang == "ko"
        if passthrough { return }

        wordDict = dict(r, "tpl_words")
        unitDict = dict(r, "tpl_units")
    }

    /// "한국어|번역" 한 줄씩 담긴 string-array 를 표로 읽는다
    private static func dict(_ r: Resources, _ name: String) -> [String: String] {
        let id = r.getIdentifier(name, "array", pkg)
        if id == 0 { return [:] }
        var out: [String: String] = [:]
        for it in r.getStringArray(id) {
            let i = it.indexOf("|")
            if i <= 0 { continue }
            out[it.substring(0, i)] = it.substring(i + 1)
        }
        return out
    }

    private static func idOf(_ name: String) -> Int {
        if let id = ids[name] { return id }
        let id = res?.getIdentifier(name, "string", pkg) ?? 0
        ids[name] = id
        return id
    }

    /// 뼈대 + 값 → 폰 언어의 문장.
    /// 번역이 없거나 서식이 안 맞으면 **한국어 원문을 그대로** 돌려준다.
    static func sentence(_ tk: String?, _ ta: [String], _ ko: String) -> String {
        if passthrough || tk.isNullOrEmpty() { return ko }
        let id = idOf("tpl_\(tk!)")
        if id == 0 { return ko }
        guard let r = res else { return ko }
        let fmt = r.getString(id)
        // 자바 String.format 이 던질 자리(인자 모자람·%d 에 글자)는 원문으로 — 문제는 계속 풀려야 한다
        guard formatFits(fmt, ta.count) else { return ko }
        let args: [Any] = ta.map { word($0) }
        return JavaFormat.format(fmt, args)
    }

    /// 인자가 전부 글자일 때 자바 String.format 이 예외 없이 끝나는 서식인가
    private static func formatFits(_ fmt: String, _ argc: Int) -> Bool {
        let u = Array(fmt.unicodeScalars)
        var i = 0
        var next = 0
        while i < u.count {
            if u[i] != "%" { i += 1; continue }
            i += 1
            var spec = ""
            while i < u.count, !CharacterSet.letters.contains(u[i]), u[i] != "%" {
                spec.unicodeScalars.append(u[i]); i += 1
            }
            guard i < u.count else { return false }
            let conv = u[i]
            i += 1
            if conv == "%" || conv == "n" { continue }
            // 글자 인자는 s·S(그리고 b·h)만 받는다
            if !"sSbBhH".unicodeScalars.contains(conv) { return false }
            var index: Int
            if let d = spec.firstIndex(of: "$"), let n = Int(spec[..<d]) {
                index = n - 1
            } else {
                index = next
                next += 1
            }
            if index >= argc { return false }
        }
        return true
    }

    /// 문자열 안의 한국어 낱말만 갈아 끼운다 (그림 라벨·선택지·단위에 쓴다).
    /// 사전에 없는 낱말은 그대로 둔다 — 반쪽이라도 읽히는 편이 낫다.
    static func word(_ s: String) -> String {
        if passthrough || wordDict.isEmpty || s.isEmpty { return s }
        if !hasHangul(s) { return s }
        // 통째로 등록된 구절이 먼저다 (문장째 갈아 끼워야 말이 되는 것들)
        if let w = wordDict[s] { return w }
        // 앞뒤 공백은 문장을 이어 붙이는 데 쓰이므로 살려 둔다
        let t = s.trim()
        if t.length != s.length, let w = wordDict[t] { return s.replace(t, w) }
        // 여러 줄이면 줄마다 따로 찾는다
        if s.contains("\n") { return s.split("\n").map { word($0) }.joined(separator: "\n") }
        return replaceHangul(s) { wordDict[$0] ?? $0 }
    }

    /// 단위(개·명·분·원 …). 그림 라벨의 "원"(동그라미)과 단위의 "원"(돈)이 겹쳐서 사전을 따로 둔다.
    static func unit(_ s: String) -> String {
        if passthrough || s.isEmpty { return s }
        return unitDict[s] ?? word(s)
    }

    /// 해설처럼 없어도 되는 글: 비한국어 폰에서 한국어가 섞여 있으면 감춘다
    static func textOrNull(_ s: String) -> String? { !passthrough && hasHangul(s) ? nil : s }

    static func words(_ list: [String]) -> [String] {
        passthrough ? list : list.map { word($0) }
    }

    private static func isHangul(_ v: Unicode.Scalar) -> Bool { v.value >= 0xAC00 && v.value <= 0xD7A3 }

    private static func hasHangul(_ s: String) -> Bool { s.unicodeScalars.contains { isHangul($0) } }

    /// 정규식 [가-힣]+ 의 덩어리마다 f 로 바꾼다
    private static func replaceHangul(_ s: String, _ f: (String) -> String) -> String {
        var out = ""
        var run = ""
        for v in s.unicodeScalars {
            if isHangul(v) {
                run.unicodeScalars.append(v)
            } else {
                if !run.isEmpty { out += f(run); run = "" }
                out.unicodeScalars.append(v)
            }
        }
        if !run.isEmpty { out += f(run) }
        return out
    }
}
