import Foundation

// object → enum. 정규식은 NSRegularExpression (안드로이드와 같은 ICU 엔진).

/// 채점 결과: 정답 여부 + 오타 인정 여부
struct GradeResult: Equatable {
    var correct: Bool
    var typo: Bool

    init(_ correct: Bool, typo: Bool = false) {
        self.correct = correct
        self.typo = typo
    }
}

enum Grader {

    private static let CONTRACTIONS: [(first: String, second: String)] = [
        ("i'm", "i am"), ("you're", "you are"), ("he's", "he is"), ("she's", "she is"),
        ("it's", "it is"), ("we're", "we are"), ("they're", "they are"),
        ("i've", "i have"), ("you've", "you have"), ("we've", "we have"), ("they've", "they have"),
        ("i'll", "i will"), ("you'll", "you will"), ("he'll", "he will"), ("she'll", "she will"),
        ("we'll", "we will"), ("they'll", "they will"), ("it'll", "it will"),
        ("i'd", "i would"), ("you'd", "you would"), ("he'd", "he would"), ("she'd", "she would"),
        ("we'd", "we would"), ("they'd", "they would"),
        ("isn't", "is not"), ("aren't", "are not"), ("wasn't", "was not"), ("weren't", "were not"),
        ("don't", "do not"), ("doesn't", "does not"), ("didn't", "did not"),
        ("can't", "cannot"), ("couldn't", "could not"), ("won't", "will not"),
        ("wouldn't", "would not"), ("shouldn't", "should not"), ("mustn't", "must not"),
        ("haven't", "have not"), ("hasn't", "has not"), ("hadn't", "had not"),
        ("let's", "let us"), ("that's", "that is"), ("there's", "there is"),
        ("what's", "what is"), ("where's", "where is"), ("who's", "who is"), ("how's", "how is"),
    ]

    /// 축약형 정규식은 한 번만 만든다
    private static let CONTRACTION_RES: [(re: NSRegularExpression, full: String)] = CONTRACTIONS.map {
        (try! NSRegularExpression(pattern: "\\b" + NSRegularExpression.escapedPattern(for: $0.first) + "\\b"), $0.second)
    }
    private static let NON_WORD = try! NSRegularExpression(pattern: "[^a-z0-9' ]")
    private static let LONE_APOS = try! NSRegularExpression(pattern: "'(?=\\s|$)|(?<=\\s|^)'")
    private static let SPACES = try! NSRegularExpression(pattern: "\\s+")

    private static func replaceAll(_ re: NSRegularExpression, _ s: String, _ with: String) -> String {
        re.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length),
                                    withTemplate: NSRegularExpression.escapedTemplate(for: with))
    }

    /// 소문자화 → 축약형 전개 → 구두점 제거 → 공백 축약
    static func normalize(_ s: String) -> String {
        var t = s.trim().lowercase()
            .replace("’", "'").replace("‘", "'")
            .replace("“", "\"").replace("”", "\"")
        for (re, full) in CONTRACTION_RES {
            t = replaceAll(re, t, full)
        }
        t = replaceAll(NON_WORD, t, " ")
        t = replaceAll(LONE_APOS, t, " ") // 낱개 아포스트로피 제거
        t = replaceAll(SPACES, t, " ").trim()
        return t
    }

    /// 받아쓰기·타이핑 번역 채점. 오타(편집거리) 허용.
    static func grade(_ input: String, _ answer: String, _ alts: [String] = []) -> GradeResult {
        let inN = normalize(input)
        if inN.isEmpty { return GradeResult(false) }
        let answers = ([answer] + alts).map { normalize($0) }
        if answers.contains(where: { $0 == inN }) { return GradeResult(true) }
        // 오타 인정: 답 길이 >4 → 거리 1, >10 → 거리 2
        for a in answers {
            let tol: Int
            if a.length > 10 { tol = 2 } else if a.length > 4 { tol = 1 } else { tol = 0 }
            if tol > 0 && levenshtein(inN, a, tol) <= tol { return GradeResult(true, typo: true) }
        }
        return GradeResult(false)
    }

    /// 단어 타일 배열 채점
    static func gradeOrder(_ selected: [String], _ answerTokens: [String]) -> Bool {
        selected == answerTokens
    }

    private static func tokens(_ s: String) -> [String] {
        normalize(s).split(" ").filter { !$0.isEmpty }
    }

    /// 말하기 채점: 토큰 유사도(1-WER). 4단어 이상 0.75, 3단어 1오차, 1~2단어 정확히.
    static func gradeSpeak(_ recognized: String, _ target: String) -> Bool {
        let r = tokens(recognized)
        let t = tokens(target)
        if t.isEmpty { return false }
        if r.isEmpty { return false }
        let dist = tokenLevenshtein(r, t)
        if t.count >= 4 { return 1.0 - Double(dist) / Double(t.count) >= 0.75 }
        if t.count == 3 { return dist <= 1 }
        return dist == 0
    }

    /// 말하기 유사도 점수 0~100 (표시용)
    static func speakScore(_ recognized: String, _ target: String) -> Int {
        let r = tokens(recognized)
        let t = tokens(target)
        if t.isEmpty || r.isEmpty { return 0 }
        let dist = tokenLevenshtein(r, t)
        return Swift.max(0.0, (1.0 - Double(dist) / Double(Swift.max(t.count, r.count))) * 100).toInt()
    }

    /// 문자 단위 편집거리 (조기 종료 임계값 지원). 코틀린처럼 UTF-16 단위로 센다.
    static func levenshtein(_ a: String, _ b: String, _ cap: Int = Int(Int32.max)) -> Int {
        if a == b { return 0 }
        let a = Array(a.utf16), b = Array(b.utf16)
        if abs(a.count - b.count) > cap { return cap + 1 }
        var prev = Array(0...b.count)
        var cur = [Int](repeating: 0, count: b.count + 1)
        if a.isEmpty { return prev[b.count] }
        for i in 1...a.count {
            cur[0] = i
            var rowMin = cur[0]
            if !b.isEmpty {
                for j in 1...b.count {
                    let cost = a[i - 1] == b[j - 1] ? 0 : 1
                    cur[j] = Swift.min(Swift.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost)
                    rowMin = Swift.min(rowMin, cur[j])
                }
            }
            if rowMin > cap { return cap + 1 }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }

    private static func tokenLevenshtein(_ a: [String], _ b: [String]) -> Int {
        var prev = Array(0...b.count)
        var cur = [Int](repeating: 0, count: b.count + 1)
        if a.isEmpty { return prev[b.count] }
        for i in 1...a.count {
            cur[0] = i
            if !b.isEmpty {
                for j in 1...b.count {
                    let cost = a[i - 1] == b[j - 1] ? 0 : 1
                    cur[j] = Swift.min(Swift.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost)
                }
            }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }
}
