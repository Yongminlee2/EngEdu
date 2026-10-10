import Foundation

/// 실력 영역. 이름은 **문자열 리소스 id** 다 — 폰 언어를 따라가야 하므로
struct SkillDef: Equatable {
    var id: String
    var emoji: String
    var titleRes: Int
    var color: String

    init(_ id: String, _ emoji: String, _ titleRes: Int, _ color: String) {
        self.id = id
        self.emoji = emoji
        self.titleRes = titleRes
        self.color = color
    }
}

/// 한 영역의 현재 상태
struct SkillState {
    var def: SkillDef
    var correct: Int
    var attempts: Int

    init(_ def: SkillDef, correct: Int, attempts: Int) {
        self.def = def
        self.correct = correct
        self.attempts = attempts
    }

    var level: Int { Skills.levelFor(correct) }
    /// 다음 레벨까지 진행률 0~1
    var progress: Float { Skills.progressFor(correct) }
    /// 정답률 0~100 (시도 없으면 0)
    var accuracy: Int { attempts == 0 ? 0 : correct * 100 / attempts }
    var nextLevelNeed: Int { (Skills.correctForLevel(level + 1) - correct).coerceAtLeast(0) }
}

enum Skills {
    static let MAX_LEVEL = 10

    /// 영어 영역 (배지 판정 기준이기도 하다)
    static let ALL: [SkillDef] = [
        SkillDef("listening", "🎧", R.string.sk_listen, "#AEE3F0"),
        SkillDef("speaking", "🎤", R.string.sk_speak, "#F7C6C7"),
        SkillDef("writing", "✍️", R.string.sk_write, "#CFE8B8"),
        SkillDef("grammar", "📖", R.string.sk_grammar, "#F3D7B0"),
        SkillDef("reading", "📚", R.string.sk_read, "#D8CBF0"),
        SkillDef("vocab", "🔤", R.string.sk_vocab, "#FFE082"),
    ]

    /// 수학 영역
    static let MATH: [SkillDef] = [
        SkillDef("m_calc", "➕", R.string.sk_calc, "#FFCCBC"),
        SkillDef("m_number", "🔢", R.string.sk_number, "#FFE082"),
        SkillDef("m_shape", "🔺", R.string.sk_shape, "#C5E1A5"),
        SkillDef("m_measure", "📏", R.string.sk_measure, "#B3E5FC"),
        SkillDef("m_data", "📊", R.string.sk_data, "#D1C4E9"),
        SkillDef("m_word", "🧩", R.string.sk_word, "#F8BBD0"),
    ]

    static func forSubject(_ subject: Subject) -> [SkillDef] { subject == .MATH ? MATH : ALL }

    static func def(_ id: String) -> SkillDef { (ALL + MATH).first { $0.id == id } ?? ALL.last! }

    /// 레벨 n 도달에 필요한 누적 정답 수 = 10 * n(n+1)/2 (Lv1=10, Lv2=30, Lv3=60 … Lv10=550)
    static func correctForLevel(_ n: Int) -> Int { 10 * n * (n + 1) / 2 }

    static func levelFor(_ correct: Int) -> Int {
        var n = 0
        while n < MAX_LEVEL && correctForLevel(n + 1) <= correct { n += 1 }
        return n
    }

    static func progressFor(_ correct: Int) -> Float {
        let lv = levelFor(correct)
        if lv >= MAX_LEVEL { return 1 }
        let cur = correctForLevel(lv)
        let next = correctForLevel(lv + 1)
        return (Float(correct - cur) / Float(next - cur)).coerceIn(0, 1)
    }

    /// 여섯 영역 레벨의 평균 = 종합 실력 레벨
    static func overallLevel(_ states: [SkillState]) -> Float {
        if states.isEmpty { return 0 }
        return Float(states.sumOf { $0.level }) / Float(states.count)
    }

    /// 가장 약한 영역 (연습 안 한 영역 우선)
    static func weakest(_ states: [SkillState]) -> SkillState? {
        states.minByOrNull { $0.level * 1000 + $0.correct }
    }
}

/// 칭호. 종합 실력이 오를수록 병아리가 자란다.
struct Rank: Equatable {
    var emoji: String
    var titleRes: Int
    var minOverall: Float

    init(_ emoji: String, _ titleRes: Int, _ minOverall: Float) {
        self.emoji = emoji
        self.titleRes = titleRes
        self.minOverall = minOverall
    }
}

enum Ranks {
    static let ALL: [Rank] = [
        Rank("🥚", R.string.rk_seed, 0),
        Rank("🐣", R.string.rk_hatch, 0.7),
        Rank("🐥", R.string.rk_piyak, 1.5),
        Rank("🐤", R.string.rk_brave, 2.5),
        Rank("🐦", R.string.rk_sparrow, 3.5),
        Rank("🕊️", R.string.rk_dove, 4.5),
        Rank("🦜", R.string.rk_parrot, 5.5),
        Rank("🦉", R.string.rk_owl, 6.5),
        Rank("🦅", R.string.rk_eagle, 7.5),
        Rank("👑", R.string.rk_master, 9),
    ]

    static func of(_ overall: Float) -> Rank { ALL.last { overall >= $0.minOverall }! }

    /// 다음 칭호 (최고면 nil)
    static func next(_ overall: Float) -> Rank? { ALL.first { $0.minOverall > overall } }

    /// 현재 칭호에서 다음 칭호까지 진행률 0~1
    static func progress(_ overall: Float) -> Float {
        let cur = of(overall)
        guard let nxt = next(overall) else { return 1 }
        return ((overall - cur.minOverall) / (nxt.minOverall - cur.minOverall)).coerceIn(0, 1)
    }
}

/// 오늘의 목표
enum DailyGoal {
    static let OPTIONS = [20, 50, 100, 200]
    static let DEFAULT = 50

    static func progress(_ todayXp: Int, _ goal: Int) -> Float {
        goal <= 0 ? 1 : Swift.min(1, Float(todayXp) / Float(goal))
    }

    static func isDone(_ todayXp: Int, _ goal: Int) -> Bool { todayXp >= goal }
}
