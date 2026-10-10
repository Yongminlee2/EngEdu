import Foundation

// 안드로이드 :core 를 한 줄씩 옮기면서 코틀린과 **똑같이** 굴러야 하는 것들.
//
// 특히 난수는 코틀린 `kotlin.random.Random(seed)` 와 비트 단위로 같은 수열을 낸다(XorWow).
// 그래야 안드로이드의 시드 고정 시험(밸런스 시뮬레이션 2만 판 등)을 숫자 그대로 옮겨
// 두 앱의 규칙이 같은지 대조할 수 있다. 반올림도 코틀린(Math.round)과 같게 둔다.

// MARK: - 난수

/// 코틀린 `kotlin.random.Random` 의 아이폰판. 메서드 이름과 인자 이름이 코틀린과 같다.
///
/// 시험용 난수(`ScriptedRandom`)가 `nextDouble()` 만 덮어쓰듯, 하위 클래스는 필요한 것만 덮어쓴다.
/// 기본 구현은 전부 `nextBits` 하나로 만든다 — 코틀린 `Random` 과 같은 구조다.
class KRandom {

    /// 하위 32비트 중 위쪽 `bitCount` 비트. 코틀린 `nextBits(bitCount)`.
    func nextBits(_ bitCount: Int) -> Int32 {
        fatalError("nextBits 를 구현해야 한다")
    }

    func nextInt() -> Int { Int(nextBits(32)) }

    func nextInt(until: Int) -> Int { nextInt(from: 0, until: until) }

    func nextInt(from: Int, until: Int) -> Int {
        precondition(until > from, "Random range is empty: [\(from), \(until)).")
        let n = Int32(truncatingIfNeeded: until &- from)
        if n > 0 || n == Int32.min {
            let rnd: Int32
            if n & -n == n {
                let bitCount = 31 - n.leadingZeroBitCount
                rnd = nextBits(bitCount)
            } else {
                var v: Int32
                var bits: Int32
                repeat {
                    bits = Int32(bitPattern: UInt32(bitPattern: Int32(truncatingIfNeeded: nextInt())) >> 1)
                    v = bits % n
                } while bits &- v &+ (n &- 1) < 0
                rnd = v
            }
            return from + Int(rnd)
        } else {
            while true {
                let rnd = nextInt()
                if rnd >= from && rnd < until { return rnd }
            }
        }
    }

    func nextLong() -> Int { (nextInt() << 32) &+ nextInt() }

    func nextBoolean() -> Bool { nextBits(1) != 0 }

    func nextDouble() -> Double {
        let hi = Int64(nextBits(26))
        let lo = Int64(nextBits(27))
        return Double((hi << 27) &+ lo) / Double(Int64(1) << 53)
    }

    func nextDouble(until: Double) -> Double { nextDouble(from: 0, until: until) }

    func nextDouble(from: Double, until: Double) -> Double {
        precondition(until > from, "Random range is empty: [\(from), \(until)).")
        let r = from + nextDouble() * (until - from)
        return r >= until ? until.nextDown : r
    }

    func nextFloat() -> Float { Float(nextBits(24)) / Float(1 << 24) }

    /// 코틀린 `Random.Default`. 시드 없이 기기 난수를 쓴다.
    static let `default`: KRandom = SystemKRandom()
}

/// 코틀린 `Random(seed)` — XorWow. 같은 시드면 안드로이드와 같은 수열을 낸다.
final class XorWowRandom: KRandom {
    private var x: Int32
    private var y: Int32
    private var z: Int32
    private var w: Int32
    private var v: Int32
    private var addend: Int32

    /// 코틀린 `Random(seed: Int)` 와 `Random(seed: Long)` 둘 다 이 하나로 받는다.
    /// 32비트에 들어가는 시드는 두 함수가 같은 값을 만든다(상위 32비트 = 부호 확장).
    init(seed: Int) {
        let seed1 = Int32(truncatingIfNeeded: seed)
        let seed2 = Int32(truncatingIfNeeded: seed >> 32)
        x = seed1
        y = seed2
        z = 0
        w = 0
        v = ~seed1
        addend = (seed1 << 10) ^ Int32(bitPattern: UInt32(bitPattern: seed2) >> 4)
        super.init()
        precondition((x | y | z | w | v) != 0, "Initial state must have at least one non-zero element.")
        for _ in 0..<64 { _ = nextRaw() }
    }

    private func nextRaw() -> Int32 {
        var t = x
        t = t ^ Int32(bitPattern: UInt32(bitPattern: t) >> 2)
        x = y
        y = z
        z = w
        let v0 = v
        w = v0
        t = (t ^ (t << 1)) ^ v0 ^ (v0 << 4)
        v = t
        addend = addend &+ 362437
        return t &+ addend
    }

    override func nextBits(_ bitCount: Int) -> Int32 {
        let r = nextRaw()
        // takeUpperBits: ushr(32 - bitCount) and (-bitCount shr 31)
        let shifted = Int32(bitPattern: UInt32(bitPattern: r) >> UInt32(32 - bitCount))
        let mask = Int32(truncatingIfNeeded: -bitCount) >> 31
        return shifted & mask
    }
}

/// 코틀린 `Random.Default` 자리. 시드가 없으니 수열 일치는 필요 없다.
final class SystemKRandom: KRandom {
    private var g = SystemRandomNumberGenerator()

    override func nextBits(_ bitCount: Int) -> Int32 {
        guard bitCount > 0 else { return 0 }
        let r = UInt32(truncatingIfNeeded: g.next())
        return Int32(bitPattern: r >> UInt32(32 - bitCount))
    }
}

extension Collection {
    /// 코틀린 `Collection.random(random)` — `nextInt(size)` 번째 원소.
    func random(random: KRandom) -> Element {
        precondition(!isEmpty, "Collection is empty.")
        return self[index(startIndex, offsetBy: random.nextInt(until: count))]
    }

    /// 코틀린 `randomOrNull(random)`.
    func randomOrNull(random: KRandom) -> Element? {
        isEmpty ? nil : self.random(random: random)
    }

    /// 코틀린 `shuffled(random)` — 뒤에서부터 `nextInt(i + 1)` 과 바꾼다. 난수 소비 순서가 같다.
    func shuffled(random: KRandom) -> [Element] {
        var a = Array(self)
        var i = a.count - 1
        while i >= 1 {
            let j = random.nextInt(until: i + 1)
            a.swapAt(i, j)
            i -= 1
        }
        return a
    }
}

// MARK: - 수

extension Double {
    /// 코틀린 `roundToInt()`(= `Math.round`): .5 는 양의 무한대 쪽으로. `rounded()` 와 음수에서 다르다.
    func roundToInt() -> Int {
        if isNaN { preconditionFailure("Cannot round NaN value.") }
        if self >= Double(Int.max) { return Int.max }
        if self <= Double(Int.min) { return Int.min }
        return Int((self + 0.5).rounded(.down))
    }

    /// 코틀린 `roundToLong()`. 아이폰의 Int 는 64비트라 같은 함수다.
    func roundToLong() -> Int { roundToInt() }
}

extension Comparable {
    func coerceIn(_ minimumValue: Self, _ maximumValue: Self) -> Self {
        Swift.min(Swift.max(self, minimumValue), maximumValue)
    }

    func coerceAtLeast(_ minimumValue: Self) -> Self { Swift.max(self, minimumValue) }

    func coerceAtMost(_ maximumValue: Self) -> Self { Swift.min(self, maximumValue) }
}

// MARK: - data class copy

/// 코틀린 data class 의 `copy(a = 1, b = 2)` 를 `copy { $0.a = 1; $0.b = 2 }` 로 쓴다.
protocol Copyable {}

extension Copyable {
    func copy(_ change: (inout Self) -> Void) -> Self {
        var c = self
        change(&c)
        return c
    }
}

// MARK: - 열거형

extension CaseIterable where Self: Equatable {
    /// 코틀린 enum 의 `ordinal`.
    var ordinal: Int { Array(Self.allCases).firstIndex(of: self)! }
}

/// 코틀린 `require` 가 저장 파일을 읽다 실패한 것과 같은 자리에서 던진다.
struct KotlinRequireError: Error, CustomStringConvertible {
    let description: String
}

/// 코틀린 `check`/`IllegalStateException` 을 부르는 쪽이 잡아야 하는 자리(시험이 예외를 확인하는 곳)에서 던진다.
struct KotlinStateError: Error, CustomStringConvertible {
    let description: String
}
