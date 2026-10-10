import Foundation

// data class → struct, object → enum. Pair/Triple 은 (first:, second:(, third:)) 튜플.
// 시드 난수 시험이 코틀린과 같은 값을 내도록 난수 쓰는 순서를 그대로 둔다.

/// 미니게임 한 종류
struct GameDef: Equatable {
    var id: String
    var emoji: String
    /// 이름·설명은 문자열 리소스 id — 폰 언어를 따라간다
    var titleRes: Int
    var descRes: Int
    var subject: Subject
    var color: String

    init(_ id: String, _ emoji: String, _ titleRes: Int, _ descRes: Int, _ subject: Subject, _ color: String) {
        self.id = id
        self.emoji = emoji
        self.titleRes = titleRes
        self.descRes = descRes
        self.subject = subject
        self.color = color
    }
}

/// 게임에서 내는 한 문제 — 물음과 보기(정답 하나 + 오답들).
/// 코틀린에서 이름 붙여 만드는 자리라 init 이름표를 그대로 둔다.
struct GameRound: Equatable {
    var question: String
    /// 물음을 **폰 언어로** 다시 만들 때 쓰는 뼈대와 값. 화면이 이 두 값으로 번역문을 조립한다.
    /// 0 이면 원문을 그대로 쓴다.
    var questionRes: Int
    var questionArgs: [String]
    /// 화면에 띄울 항목들. 정답은 answer 와 같은 문자열
    var options: [String]
    var answer: String
    /// 소리로 읽어 줄 말 (없으면 question 을 읽는다)
    var speak: String?
    /// 크게 보여줄 그림
    var emoji: String?

    init(question: String, questionRes: Int = 0, questionArgs: [String] = [],
         options: [String], answer: String, speak: String? = nil, emoji: String? = nil) {
        self.question = question
        self.questionRes = questionRes
        self.questionArgs = questionArgs
        self.options = options
        self.answer = answer
        self.speak = speak
        self.emoji = emoji
    }
}

enum MiniGames {

    static let BALLOON = "balloon"
    static let BASKET = "basket"
    static let LINE = "line"

    static let ALL: [GameDef] = [
        GameDef(
            BALLOON, "🎈", R.string.game_balloon,
            R.string.game_balloon_math_d, .MATH, "#FFCDD2"
        ),
        GameDef(
            BASKET, "🧺", R.string.game_basket,
            R.string.game_basket_d, .MATH, "#C8E6C9"
        ),
        GameDef(
            LINE, "🔗", R.string.game_line,
            R.string.game_line_math_d, .MATH, "#B3E5FC"
        ),
        GameDef(
            "\(BALLOON)_en", "🎈", R.string.game_balloon,
            R.string.game_balloon_en_d, .ENGLISH, "#FFCDD2"
        ),
        GameDef(
            "\(LINE)_en", "🔗", R.string.game_line,
            R.string.game_line_en_d, .ENGLISH, "#B3E5FC"
        ),
    ]

    static func forSubject(_ s: Subject) -> [GameDef] { ALL.filter { $0.subject == s } }

    static func byId(_ id: String) -> GameDef? { ALL.first { $0.id == id } }

    // ---------------- 낱말 데이터 (영어 게임용) ----------------
    /// (이모지, 영어, 뜻)
    static let WORDS: [(first: String, second: String, third: String)] = [
        ("🍎", "apple", "사과"), ("🍌", "banana", "바나나"),
        ("🍓", "strawberry", "딸기"), ("🍊", "orange", "오렌지"),
        ("🐶", "dog", "개"), ("🐱", "cat", "고양이"),
        ("🐰", "rabbit", "토끼"), ("🐻", "bear", "곰"),
        ("🐷", "pig", "돼지"), ("🐸", "frog", "개구리"),
        ("🐧", "penguin", "펭귄"), ("🦁", "lion", "사자"),
        ("🚗", "car", "자동차"), ("🚌", "bus", "버스"),
        ("✈️", "airplane", "비행기"), ("🚲", "bicycle", "자전거"),
        ("🏠", "house", "집"), ("🏫", "school", "학교"),
        ("🌳", "tree", "나무"), ("🌸", "flower", "꽃"),
        ("⭐", "star", "별"), ("🌙", "moon", "달"),
        ("☀️", "sun", "해"), ("🌈", "rainbow", "무지개"),
        ("📚", "book", "책"), ("✏️", "pencil", "연필"),
        ("👟", "shoes", "신발"), ("🎒", "backpack", "가방"),
        ("🍪", "cookie", "쿠키"), ("🥛", "milk", "우유"),
    ]

    /// 수 세기용 사물
    static let THINGS = ["🍎", "🍓", "⭐", "🎈", "🍪", "🐥", "🌸", "🐟", "🚗", "🧸"]

    // ---------------- 라운드 생성 ----------------

    /// 풍선 게임 라운드. level 1~5 (커질수록 큰 수·곱셈까지)
    static func balloonMath(_ level: Int, _ rnd: KRandom = KRandom.default) -> GameRound {
        let max: Int
        switch level {
        case 1: max = 5
        case 2: max = 9
        case 3: max = 20
        case 4: max = 50
        default: max = 99
        }
        let kind = level >= 3 && rnd.nextInt(until: 3) == 0 ? "×" : (rnd.nextBoolean() ? "+" : "-")
        let q: String
        let ans: Int
        switch kind {
        case "×":
            let a = rnd.nextInt(from: 2, until: 10)
            let b = rnd.nextInt(from: 2, until: 10)
            (q, ans) = ("\(a) × \(b)", a * b)
        case "+":
            let a = rnd.nextInt(from: 1, until: max)
            let b = rnd.nextInt(from: 1, until: max)
            (q, ans) = ("\(a) + \(b)", a + b)
        default:
            let a = rnd.nextInt(from: 2, until: max + 1)
            let b = rnd.nextInt(from: 1, until: a)
            (q, ans) = ("\(a) - \(b)", a - b)
        }
        return GameRound(
            question: "\(q) = ?",
            options: wrongNumbers(ans, 5, rnd).map { String($0) },
            answer: String(ans),
            speak: nil
        )
    }

    /// 영어 풍선: 낱말을 듣고 맞는 그림 고르기
    static func balloonEnglish(_ rnd: KRandom = KRandom.default) -> GameRound {
        let pool = WORDS.shuffled(random: rnd)
        let target = pool[0]
        let options = ([target] + pool.drop(1).take(5)).shuffled(random: rnd)
        return GameRound(
            question: "\(target.second) 를 찾아 터뜨려요!",
            questionRes: R.string.game_q_balloon,
            questionArgs: [target.second],
            options: options.map { $0.first },
            answer: target.first,
            speak: target.second
        )
    }

    /// 바구니 담기: n개 담기
    static func basketRound(_ level: Int, _ rnd: KRandom = KRandom.default) -> GameRound {
        let n: Int
        switch level {
        case 1: n = rnd.nextInt(from: 1, until: 6)
        case 2: n = rnd.nextInt(from: 3, until: 10)
        default: n = rnd.nextInt(from: 5, until: 16)
        }
        let thing = THINGS.random(random: rnd)
        return GameRound(
            question: "\(thing) 를 \(n) 개 담아요",
            questionRes: R.string.game_q_basket,
            questionArgs: [thing, String(n)],
            options: [thing],
            answer: String(n),
            speak: "\(n) 개 담아 보세요",
            emoji: thing
        )
    }

    /// 선 잇기(수학): 식 ↔ 답 4쌍
    static func lineMath(_ level: Int, _ rnd: KRandom = KRandom.default) -> [(first: String, second: String)] {
        var used = Set<Int>()
        var out: [(first: String, second: String)] = []
        var guardCount = 0
        while out.count < 4 {
            // 코틀린 guard++ < 100 (비교 뒤에 올린다)
            let g = guardCount
            guardCount += 1
            if !(g < 100) { break }
            let r = balloonMath(level, rnd)
            let ans = Int(r.answer)!
            if !used.insert(ans).inserted { continue }
            out.append((r.question.removeSuffix(" = ?"), r.answer))
        }
        return out
    }

    /// 선 잇기(영어): 그림 ↔ 낱말 4쌍
    static func lineEnglish(_ rnd: KRandom = KRandom.default) -> [(first: String, second: String)] {
        WORDS.shuffled(random: rnd).take(4).map { ($0.first, $0.second) }
    }

    /// 정답 주변의 그럴듯한 오답 n개 (중복·음수 없음)
    static func wrongNumbers(_ answer: Int, _ n: Int, _ rnd: KRandom = KRandom.default) -> [Int] {
        var set: [Int] = []   // LinkedHashSet — 넣은 순서를 지킨다
        set.append(answer)
        var d = 1
        while set.count < n && d < 60 {
            for w in [answer + d, answer - d] {
                if w >= 0 && set.count < n && !set.contains(w) { set.append(w) }
            }
            d += 1
        }
        return set.shuffled(random: rnd)
    }
}

/// 게임 결과 → 보상. 게임으로 용돈을 무한히 벌 수 없게 하루 판수를 제한한다.
enum GameReward {
    /// 하루에 용돈을 받을 수 있는 판 수
    static let DAILY_PAID_ROUNDS = 3

    /// 한 판 최대 용돈
    static let MAX_COINS = 20

    /// 정답 하나당 점수
    static let SCORE_PER_HIT = 10

    /// 점수 → 용돈 (만점에 가까울수록 많이, 최대 MAX_COINS)
    static func coinsFor(_ score: Int, _ maxScore: Int) -> Int {
        if maxScore <= 0 { return 0 }
        let ratio = Float(score) / Float(maxScore)
        return (Float(MAX_COINS) * ratio).toInt().coerceIn(0, MAX_COINS)
    }

    /// 점수 → XP
    static func xpFor(_ score: Int) -> Int { (score / 10).coerceIn(0, 30) }

    /// 별점 (결과 화면 표시용)
    static func stars(_ score: Int, _ maxScore: Int) -> Int {
        if maxScore <= 0 { return 0 }
        if score >= maxScore { return 3 }
        if Float(score) >= Float(maxScore) * 0.7 { return 2 }
        if score > 0 { return 1 }
        return 0
    }
}
