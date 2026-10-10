import Foundation

// data class → struct (문제는 클래스라 배열에 참조로 담긴다). Pair 는 (first:, second:) 튜플.

struct LessonData {
    var id: String
    var title: String
    var questions: [Question]

    init(_ id: String, _ title: String, _ questions: [Question]) {
        self.id = id
        self.title = title
        self.questions = questions
    }
}

struct UnitData {
    var id: String
    var title: String
    var emoji: String
    var level: Int // BASIC 은 1~10, 나머지 트랙은 유닛 순번
    var lessons: [LessonData]

    init(_ id: String, _ title: String, _ emoji: String, _ level: Int, _ lessons: [LessonData]) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.level = level
        self.lessons = lessons
    }
}

struct TrackData {
    var id: String
    var title: String
    var emoji: String
    var color: String
    var subtitle: String
    var units: [UnitData]

    init(_ id: String, _ title: String, _ emoji: String, _ color: String, _ subtitle: String, _ units: [UnitData]) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.color = color
        self.subtitle = subtitle
        self.units = units
    }

    var lessonCount: Int { units.sumOf { $0.lessons.size } }

    func findLesson(_ lessonId: String) -> (first: UnitData, second: LessonData)? {
        for u in units { for l in u.lessons where l.id == lessonId { return (u, l) } }
        return nil
    }
}

/// assets 의 packs 폴더 JSON 로더. 트랙별 캐시.
enum ContentRepo {
    /// 이 앱이 싣는 트랙 — 삐약영어는 영어만 (Subject.MATH 는 모델로만 남아 있다)
    static let TRACK_IDS: [String] = Subject.ENGLISH.tracks

    static func tracksOf(_ subject: Subject) -> [String] { subject.tracks }

    private static var cache: [String: TrackData] = [:]

    /// 앱 언어를 바꾸면 걸러 놓은 결과가 달라진다 — 캐시를 버려야 새 언어로 다시 읽힌다
    static func clearCache() { cache.removeAll() }

    static func track(_ ctx: Context, _ trackId: String) -> TrackData? {
        if let t = cache[trackId] { return t }
        Tpl.initialize(ctx)      // 문제를 만들기 전에 언어부터 확인
        do {
            let json = ctx.assets.open("packs/\(trackId).json").readText()
            let t = try parseTrack(try JSONObject(json))
            cache[trackId] = t
            return t
        } catch {
            return nil
        }
    }

    /// 모르는 문제 type 이 있으면 던진다
    static func parseTrack(_ o: JSONObject) throws -> TrackData {
        let abroad = !Tpl.isKorean
        let unitsArr = o.getJSONArray("units")
        let units: [UnitData] = try (0..<unitsArr.length()).map { ui in
            let u = unitsArr.getJSONObject(ui)
            let lessonsArr = u.getJSONArray("lessons")
            let lessons: [LessonData] = try (0..<lessonsArr.length()).map { li in
                let l = lessonsArr.getJSONObject(li)
                let qArr = l.getJSONArray("questions")
                let all = try (0..<qArr.length()).map { qi in try Question.fromJson(qArr.getJSONObject(qi)) }
                // 비한국어 폰: 한국어 없이는 성립하지 않는 문제(짝맞추기·한국어 독해 등)를 뺀다.
                // 한국어 폰은 그대로.
                let qs = abroad ? all.filter { usableAbroad($0) } : all
                return LessonData(l.getString("id"), title(l), qs)
            }.filter { $0.questions.size >= (abroad ? 1 : 0) }
            return UnitData(u.getString("id"), title(u), u.optString("emoji", "🐥"),
                            u.optInt("level", ui + 1), lessons)
        }.filter { !abroad || $0.lessons.isNotEmpty() }
        return TrackData(
            o.getString("id"), title(o), o.optString("emoji", "🐥"),
            o.optString("color", "#FFD54F"), title(o, "stk", "sta", "subtitle"), units
        )
    }

    /// 배치고사 문제: (난이도, 문제) 목록. 과목마다 팩이 다르다.
    static func placement(_ ctx: Context, _ subject: Subject = .ENGLISH) -> [(first: Int, second: Question)] {
        let file = subject == .MATH ? "packs/math_placement.json" : "packs/placement.json"
        do {
            let json = ctx.assets.open(file).readText()
            let arr = try JSONObject(json).getJSONArray("questions")
            return try (0..<arr.length()).map {
                let q = arr.getJSONObject($0)
                return (q.getInt("level"), try Question.fromJson(q))
            }.filter { Tpl.isKorean || usableAbroad($0.second) }
        } catch {
            return []
        }
    }

    /// 트랙 요약(레슨 수·문제 수). 시작 화면에서 팩을 전부 파싱하지 않으려고 미리 구워 둔 색인.
    struct TrackSummary: Equatable {
        var lessons: Int
        var questions: Int
        init(_ lessons: Int, _ questions: Int) { self.lessons = lessons; self.questions = questions }
    }

    private static var summaryCache: [String: TrackSummary]? = nil

    static func summaries(_ ctx: Context) -> [String: TrackSummary] {
        if let s = summaryCache { return s }
        var out: [String: TrackSummary] = [:]
        // 색인이 없으면 비워 두고 넘어간다 (진행률만 안 보일 뿐 학습에는 지장 없음)
        if let o = try? JSONObject(ctx.assets.open("packs/index.json").readText()) {
            for key in o.keys() {
                let e = o.getJSONObject(key)
                out[key] = TrackSummary(e.optInt("lessons"), e.optInt("questions"))
            }
        }
        summaryCache = out
        return out
    }

    /// 과목 전체 레슨 수 (색인 기반이라 팩을 열지 않는다)
    static func lessonCountOf(_ ctx: Context, _ subject: Subject) -> Int {
        let s = summaries(ctx)
        return subject.tracks.sumOf { s[$0]?.lessons ?? 0 }
    }

    /// 오답 복습용: qid 로 문제 찾기 (트랙 전체 스캔, 캐시 활용)
    static func findQuestion(_ ctx: Context, _ trackId: String, _ lessonId: String, _ qid: String) -> Question? {
        guard let t = track(ctx, trackId) else { return nil }
        guard let lesson = t.findLesson(lessonId)?.second else { return nil }
        return lesson.questions.first { $0.id == qid }
    }

    /// 팩의 tk/ta 를 폰 언어 제목으로 조립한다 (한국어 폰·미태깅 제목은 원문 그대로)
    private static func title(_ o: JSONObject, _ key: String = "tk", _ args: String = "ta", _ field: String = "title") -> String {
        let ko = o.optString(field)
        let tk = o.optString(key)
        if tk.isEmpty { return ko }
        let ta = o.optJSONArray(args)
        let list: [String] = ta == nil ? [] : (0..<ta!.length()).map { ta!.getString($0) }
        return Tpl.sentence(tk, list, ko)
    }

    /// 비한국어 폰에서 한국어 없이 풀 수 있는 문제인가.
    /// - 짝맞추기·독해·대화듣기: 한쪽이 한국어면 뺀다
    /// - 4지선다: 문제문이 한국어라도 bigArt 가 있으면, 보기가 한국어라도 choiceArt 가 있으면 통과
    private static func usableAbroad(_ q: Question) -> Bool {
        switch q {
        case let q as Question.Match:
            return q.pairs.none { hasKo($0.first) || hasKo($0.second) }
        case let q as Question.ListenDialog:
            return !hasKo(q.prompt) && q.choices.none { hasKo($0) }
        case let q as Question.Mcq:
            return (!hasKo(q.prompt) || q.bigArt != nil) &&
                (q.choices.none { hasKo($0) } || q.choiceArt.isNotEmpty())
        case let q as Question.ListenMcq:
            return !hasKo(q.prompt) && q.choices.none { hasKo($0) }
        default:
            return true
        }
    }

    private static func hasKo(_ s: String) -> Bool {
        s.unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7A3 }
    }
}
