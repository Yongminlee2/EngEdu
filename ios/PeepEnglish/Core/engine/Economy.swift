import Foundation

// 코틀린 Pair 반환은 (first:, second:) 튜플 — `let (cur, best) = Economy.streak(...)` 처럼 풀어 쓸 수 있다.

/// XP 레벨·하트·스트릭 순수 계산 로직
enum Economy {
    static let MAX_HEARTS = 5
    static let HEART_REFILL_MS = 30 * 60 * 1000 // 30분당 1개

    /// 레벨 n 도달에 필요한 누적 XP = 60 * n(n+1)/2  (레벨1=60, 2=180, 3=360…)
    static func xpForLevel(_ n: Int) -> Int { 60 * n * (n + 1) / 2 }

    /// 현재 누적 XP 의 레벨 (0부터)
    static func levelFor(_ xp: Int) -> Int {
        var n = 0
        while xpForLevel(n + 1) <= xp { n += 1 }
        return n
    }

    /// 다음 레벨까지 진행률 0~1
    static func levelProgress(_ xp: Int) -> Float {
        let lv = levelFor(xp)
        let cur = xpForLevel(lv)
        let next = xpForLevel(lv + 1)
        return Float(xp - cur) / Float(next - cur)
    }

    /// 하트 자동 회복 계산. 새 날이면 풀 회복, 아니면 30분당 1개.
    /// - saved 저장된 하트 수, savedAt 저장 시각 ms, savedAtDay 저장 시점의 epochDay
    static func heartsNow(
        _ saved: Int, _ savedAt: Int, _ savedAtDay: Int, _ now: Int, _ nowDay: Int,
        max: Int = MAX_HEARTS
    ) -> Int {
        if saved >= max { return max }
        if nowDay > savedAtDay { return max }
        let refills = (now - savedAt) / HEART_REFILL_MS
        return Swift.min(max, saved + refills)
    }

    /// 스트릭 계산 → (현재 스트릭, 최고 스트릭). 오늘 안 했어도 어제까지 이어졌으면 현재 스트릭 유지.
    static func streak(_ days: Set<Int>, _ today: Int) -> (first: Int, second: Int) {
        if days.isEmpty { return (0, 0) }
        // 현재 스트릭: 오늘 또는 어제부터 뒤로 연속
        var cur = 0
        var d = days.contains(today) ? today : today - 1
        while days.contains(d) { cur += 1; d -= 1 }
        // 최고 스트릭
        var best = 0
        var run = 0
        var prev = Int.min
        for day in days.sorted() {
            run = (day == prev &+ 1) ? run + 1 : 1
            if run > best { best = run }
            prev = day
        }
        return (cur, best)
    }
}
