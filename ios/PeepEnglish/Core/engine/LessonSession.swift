import Foundation

/// 레슨 한 판의 진행 상태. 순수 로직 — 단위테스트 대상.
/// 듀오링고 방식: 틀린 문제는 큐 끝에 재출제. 하트 0이면 실패.
final class LessonSession {
    var hearts: Int
    let useHearts: Bool

    private var queue: [Question]
    private let total: Int
    private var solved = 0
    private var firstTryWrong = Set<String>()
    /// 틀린 문제 id (처음 틀린 순서 그대로, 중복 없음 — LinkedHashSet)
    private(set) var wrongIds: [String] = []

    private(set) var failed = false

    init(_ questions: [Question], hearts: Int, useHearts: Bool = true) {
        self.queue = questions
        self.total = questions.count
        self.hearts = hearts
        self.useHearts = useHearts
    }

    func current() -> Question? { queue.first }

    var isFinished: Bool { queue.isEmpty || failed }

    /// 0.0 ~ 1.0 진행률 (고유 문제 기준)
    var progress: Float { total == 0 ? 1 : Float(solved) / Float(total) }

    var totalCount: Int { total }

    /// 지금까지 푼 고유 문제 수 — "3 / 12" 표시에 쓴다
    var solvedCount: Int { solved }

    /// 정답 처리 → true. 오답이면 재출제 큐잉 + 하트 차감 → false.
    @discardableResult
    func submit(_ correct: Bool) -> Bool {
        guard !queue.isEmpty else { return correct }
        let q = queue.removeFirst()
        if correct {
            solved += 1
            return true
        }
        firstTryWrong.insert(q.id)
        if !wrongIds.contains(q.id) { wrongIds.append(q.id) }
        if useHearts {
            hearts -= 1
            if hearts <= 0 { failed = true }
        }
        queue.append(q)
        return false
    }

    /// 재출제·하트 차감 없이 넘어가는 제출 (매칭 문제, 말하기 건너뛰기). correct=false 면 퍼펙트만 깨진다.
    func submitNoPenalty(_ correct: Bool) {
        guard !queue.isEmpty else { return }
        let q = queue.removeFirst()
        solved += 1
        if !correct { firstTryWrong.insert(q.id) }
    }

    /// 첫 시도에 다 맞았는지
    var isPerfect: Bool { firstTryWrong.isEmpty }

    /// 첫 시도 정답 수
    var firstTryCorrect: Int { total - firstTryWrong.count }

    /// 정답률 (첫 시도 기준)
    var accuracy: Float { total == 0 ? 1 : Float(firstTryCorrect) / Float(total) }

    /// 획득 XP: 첫시도 정답당 2 + 완료 10 + 퍼펙트 5
    func xpEarned() -> Int {
        if failed { return 0 }
        var xp = firstTryCorrect * 2 + 10
        if isPerfect { xp += 5 }
        return xp
    }

    /// 별점 1~3 (첫 시도 정답률)
    func stars() -> Int {
        if isPerfect { return 3 }
        if accuracy >= 0.8 { return 2 }
        return 1
    }
}
