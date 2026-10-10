import Foundation

// 코틀린 표준 라이브러리에서 옮긴 코드가 자주 쓰는 것들.
// 이름을 코틀린과 같게 두어 한 줄씩 옮길 수 있게 한다.
// 문자열 위치(length·substring·indexOf)는 코틀린처럼 UTF-16 단위다.

// MARK: - apply / also

protocol KotlinScope {}
extension KotlinScope where Self: AnyObject {
    /// 코틀린 `apply { }` — 블록 안에서는 `$0.` 으로 쓴다.
    @discardableResult func apply(_ block: (Self) -> Void) -> Self { block(self); return self }
    @discardableResult func also(_ block: (Self) -> Void) -> Self { block(self); return self }
}
extension NSObject: KotlinScope {}

func TODO(_ reason: String = "") -> Never { fatalError("An operation is not implemented: \(reason)") }

/// 코틀린 `require` — 어기면 앱이 죽는다(안드로이드와 같게).
func require(_ cond: Bool, _ msg: @autoclosure () -> String = "Failed requirement.") {
    if !cond { fatalError(msg()) }
}
func check(_ cond: Bool, _ msg: @autoclosure () -> String = "Check failed.") {
    if !cond { fatalError(msg()) }
}

// MARK: - 수

extension Int {
    func toFloat() -> Float { Float(self) }
    func toDouble() -> Double { Double(self) }
    func toLong() -> Int { self }
    func toInt() -> Int { self }
    func toString() -> String { String(self) }
    /// 코틀린 `a.mod(b)` (항상 0 이상)
    func mod(_ m: Int) -> Int { let r = self % m; return r < 0 ? r + m : r }
    var sign: Int { self > 0 ? 1 : (self < 0 ? -1 : 0) }
}

extension Float {
    func toInt() -> Int { isNaN ? 0 : (self >= Float(Int.max) ? Int.max : (self <= Float(Int.min) ? Int.min : Int(self))) }
    func toDouble() -> Double { Double(self) }
    func toFloat() -> Float { self }
    func toLong() -> Int { toInt() }
    /// 코틀린 roundToInt (Math.round: .5 는 위로)
    func roundToInt() -> Int { (self + 0.5).rounded(.down).toInt() }
}

extension Double {
    func toInt() -> Int { isNaN ? 0 : (self >= Double(Int.max) ? Int.max : (self <= Double(Int.min) ? Int.min : Int(self))) }
    func toFloat() -> Float { Float(self) }
    func toDouble() -> Double { self }
    func toLong() -> Int { toInt() }
}

// MARK: - 문자열 (UTF-16 위치)

extension String {
    var length: Int { utf16.count }

    private func u16Index(_ i: Int) -> String.Index {
        utf16.index(utf16.startIndex, offsetBy: Swift.max(0, Swift.min(i, utf16.count)))
    }
    func substring(_ start: Int) -> String { substring(start, length) }
    func substring(_ start: Int, _ end: Int) -> String {
        let s = Swift.max(0, Swift.min(start, length)), e = Swift.max(s, Swift.min(end, length))
        return String(utf16[u16Index(s)..<u16Index(e)]) ?? ""
    }
    /// 코틀린 `s[i]` (UTF-16 한 단위)
    func charAt(_ i: Int) -> UInt16 { Array(utf16)[i] }

    func indexOf(_ sub: String, _ from: Int = 0) -> Int {
        guard from <= length, let r = range(of: sub, range: u16Index(from)..<endIndex) else { return -1 }
        return utf16.distance(from: utf16.startIndex, to: r.lowerBound)
    }
    func lastIndexOf(_ sub: String) -> Int {
        guard let r = range(of: sub, options: .backwards) else { return -1 }
        return utf16.distance(from: utf16.startIndex, to: r.lowerBound)
    }
    func trim() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
    func isBlank() -> Bool { trim().isEmpty }
    func isNotBlank() -> Bool { !isBlank() }
    func isNotEmpty() -> Bool { !isEmpty }
    func ifBlank(_ f: () -> String) -> String { isBlank() ? f() : self }
    func ifEmpty(_ f: () -> String) -> String { isEmpty ? f() : self }
    func lowercase() -> String { lowercased() }
    func uppercase() -> String { uppercased() }
    func startsWith(_ p: String) -> Bool { hasPrefix(p) }
    func endsWith(_ p: String) -> Bool { hasSuffix(p) }
    func removePrefix(_ p: String) -> String { hasPrefix(p) ? String(dropFirst(p.count)) : self }
    func removeSuffix(_ p: String) -> String { hasSuffix(p) ? String(dropLast(p.count)) : self }
    func removeSurrounding(_ d: String) -> String {
        (count >= 2 * d.count && hasPrefix(d) && hasSuffix(d)) ? String(dropFirst(d.count).dropLast(d.count)) : self
    }
    func removeSurrounding(_ p: String, _ s: String) -> String {
        (count >= p.count + s.count && hasPrefix(p) && hasSuffix(s)) ? String(dropFirst(p.count).dropLast(s.count)) : self
    }
    func replace(_ a: String, _ b: String) -> String { replacingOccurrences(of: a, with: b) }
    func replace(_ a: String, _ b: String, ignoreCase: Bool) -> String {
        replacingOccurrences(of: a, with: b, options: ignoreCase ? [.caseInsensitive] : [])
    }
    func split(_ sep: String) -> [String] { components(separatedBy: sep) }
    func lines() -> [String] { components(separatedBy: "\n").map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 } }
    func toIntOrNull() -> Int? { Int(self) }
    func toInt() -> Int { Int(self)! }
    func toLongOrNull() -> Int? { Int(self) }
    func toFloatOrNull() -> Float? { Float(self) }
    func toDoubleOrNull() -> Double? { Double(self) }
    func padStart(_ n: Int, _ c: Character = " ") -> String { count >= n ? self : String(repeating: c, count: n - count) + self }
    func padEnd(_ n: Int, _ c: Character = " ") -> String { count >= n ? self : self + String(repeating: c, count: n - count) }
    func repeat_(_ n: Int) -> String { String(repeating: self, count: Swift.max(0, n)) }
    func take(_ n: Int) -> String { String(prefix(Swift.max(0, n))) }
    func takeLast(_ n: Int) -> String { String(suffix(Swift.max(0, n))) }
    func drop(_ n: Int) -> String { String(dropFirst(Swift.max(0, n))) }
    func dropLast_(_ n: Int) -> String { String(dropLast(Swift.max(0, n))) }
    func equals(_ o: String, ignoreCase: Bool) -> Bool { ignoreCase ? caseInsensitiveCompare(o) == .orderedSame : self == o }
    func contains(_ s: String, ignoreCase: Bool) -> Bool { ignoreCase ? range(of: s, options: .caseInsensitive) != nil : contains(s) }
    /// 코틀린 `String.format(...)` — 자바 형식(%d %s %.1f %1$s %,d).
    func format(_ args: Any...) -> String { JavaFormat.format(self, args) }
    func capitalize() -> String { prefix(1).uppercased() + dropFirst() }
}

/// 자바 `String.format` 과 안드로이드 `getString(id, args)` 의 형식 문자열을 처리한다.
enum JavaFormat {
    static func format(_ fmt: String, _ args: [Any]) -> String {
        var out = ""
        var it = Array(fmt.unicodeScalars)[...]
        var nextArg = 0
        while let c = it.first {
            it = it.dropFirst()
            if c != "%" { out.unicodeScalars.append(c); continue }
            // %[index$][flags][width][.precision]conv
            var spec = ""
            while let d = it.first, !"sdfxXcbeEgG%n".unicodeScalars.contains(d) { spec.unicodeScalars.append(d); it = it.dropFirst() }
            guard let conv = it.first else { out += "%" + spec; break }
            it = it.dropFirst()
            if conv == "%" { out += "%"; continue }
            if conv == "n" { out += "\n"; continue }
            var argIndex: Int? = nil
            if let dollar = spec.firstIndex(of: "$") {
                argIndex = Int(spec[..<dollar]).map { $0 - 1 }
                spec = String(spec[spec.index(after: dollar)...])
            }
            let idx = argIndex ?? nextArg
            if argIndex == nil { nextArg += 1 }
            let arg: Any = idx < args.count ? args[idx] : ""
            var flags = ""
            while let f = spec.first, "-+ 0,#(".contains(f) { flags.append(f); spec.removeFirst() }
            let parts = spec.split(separator: ".", omittingEmptySubsequences: false)
            let width = Int(parts.first ?? "") ?? 0
            let precision = parts.count > 1 ? Int(parts[1]) : nil
            var body: String
            switch conv {
            case "d":
                let v: Int = (arg as? Int) ?? Int("\(arg)") ?? Int((arg as? Double) ?? 0)
                if flags.contains(",") {
                    let nf = NumberFormatter(); nf.numberStyle = .decimal; nf.locale = Locale(identifier: "en_US")
                    body = nf.string(from: NSNumber(value: v)) ?? String(v)
                } else { body = String(v) }
                if flags.contains("+") && v >= 0 { body = "+" + body }
            case "f", "e", "E", "g", "G":
                let v: Double = (arg as? Double) ?? (arg as? Float).map { Double($0) } ?? (arg as? Int).map { Double($0) } ?? Double("\(arg)") ?? 0
                body = String(format: "%.\(precision ?? 6)\(conv)", v)
                // 자바 String.format 은 기기(앱) 언어의 소수점을 쓴다 — 독일어 1,5
                let sep = JLocale.getDefault().foundation.decimalSeparator ?? "."
                if sep != "." { body = body.replacingOccurrences(of: ".", with: sep) }
                if flags.contains(",") {
                    let nf = NumberFormatter(); nf.numberStyle = .decimal; nf.locale = Locale(identifier: "en_US")
                    nf.minimumFractionDigits = precision ?? 6; nf.maximumFractionDigits = precision ?? 6
                    body = nf.string(from: NSNumber(value: v)) ?? body
                }
                if flags.contains("+") && v >= 0 { body = "+" + body }
            case "x": body = String((arg as? Int) ?? 0, radix: 16)
            case "X": body = String((arg as? Int) ?? 0, radix: 16).uppercased()
            case "c": body = "\(arg)"
            case "b": body = "\(arg)"
            default:
                body = stringify(arg)
                if let p = precision { body = String(body.prefix(p)) }
            }
            if body.count < width {
                let pad = String(repeating: flags.contains("0") && !flags.contains("-") ? "0" : " ", count: width - body.count)
                body = flags.contains("-") ? body + pad : pad + body
            }
            out += body
        }
        return out
    }

    static func stringify(_ a: Any) -> String {
        if let f = a as? Float { return kotlinFloatString(Double(f)) }
        if let d = a as? Double { return kotlinFloatString(d) }
        return "\(a)"
    }
    /// 코틀린 `1.0f.toString()` == "1.0"
    static func kotlinFloatString(_ d: Double) -> String {
        if d == d.rounded() && abs(d) < 1e15 { return String(format: "%.1f", d) }
        return "\(d)"
    }
}

// MARK: - 컬렉션

extension Array {
    func getOrNull(_ i: Int) -> Element? { i >= 0 && i < count ? self[i] : nil }
    func getOrElse(_ i: Int, _ f: (Int) -> Element) -> Element { i >= 0 && i < count ? self[i] : f(i) }
    func firstOrNull() -> Element? { first }
    func lastOrNull() -> Element? { last }
    func firstOrNull(_ p: (Element) -> Bool) -> Element? { first(where: p) }
    func lastOrNull(_ p: (Element) -> Bool) -> Element? { last(where: p) }
    func isNotEmpty() -> Bool { !isEmpty }
    var size: Int { count }
    var indices_: Range<Int> { 0..<count }
    var lastIndex: Int { count - 1 }
    func take(_ n: Int) -> [Element] { Array(prefix(Swift.max(0, n))) }
    func takeLast(_ n: Int) -> [Element] { Array(suffix(Swift.max(0, n))) }
    func drop(_ n: Int) -> [Element] { Array(dropFirst(Swift.max(0, n))) }
    func chunked(_ n: Int) -> [[Element]] {
        stride(from: 0, to: count, by: n).map { Array(self[$0..<Swift.min($0 + n, count)]) }
    }
    func windowed(_ n: Int) -> [[Element]] {
        count < n ? [] : (0...(count - n)).map { Array(self[$0..<($0 + n)]) }
    }
    func sumOf(_ f: (Element) -> Int) -> Int { reduce(0) { $0 + f($1) } }
    func sumOfDouble(_ f: (Element) -> Double) -> Double { reduce(0) { $0 + f($1) } }
    func count(_ p: (Element) -> Bool) -> Int { reduce(0) { $0 + (p($1) ? 1 : 0) } }
    func any(_ p: (Element) -> Bool) -> Bool { contains(where: p) }
    func all(_ p: (Element) -> Bool) -> Bool { allSatisfy(p) }
    func none(_ p: (Element) -> Bool) -> Bool { !contains(where: p) }
    func mapIndexed<T>(_ f: (Int, Element) -> T) -> [T] { enumerated().map { f($0.offset, $0.element) } }
    func forEachIndexed(_ f: (Int, Element) -> Void) { for (i, e) in enumerated() { f(i, e) } }
    func filterIndexed(_ f: (Int, Element) -> Bool) -> [Element] { enumerated().filter { f($0.offset, $0.element) }.map { $0.element } }
    func indexOfFirst(_ p: (Element) -> Bool) -> Int { firstIndex(where: p) ?? -1 }
    func indexOfLast(_ p: (Element) -> Bool) -> Int { lastIndex(where: p) ?? -1 }
    func maxByOrNull<T: Comparable>(_ f: (Element) -> T) -> Element? { self.max { f($0) < f($1) } }
    func minByOrNull<T: Comparable>(_ f: (Element) -> T) -> Element? { self.min { f($0) < f($1) } }
    func sortedBy<T: Comparable>(_ f: (Element) -> T) -> [Element] { stableSorted { f($0) < f($1) } }
    func sortedByDescending<T: Comparable>(_ f: (Element) -> T) -> [Element] { stableSorted { f($0) > f($1) } }
    /// 코틀린 sortedBy 는 안정 정렬이다 — 같은 값은 원래 순서를 지킨다.
    func stableSorted(_ less: (Element, Element) -> Bool) -> [Element] {
        enumerated().sorted { a, b in
            if less(a.element, b.element) { return true }
            if less(b.element, a.element) { return false }
            return a.offset < b.offset
        }.map { $0.element }
    }
    func groupBy<K: Hashable>(_ f: (Element) -> K) -> [(K, [Element])] {
        var order: [K] = []
        var m: [K: [Element]] = [:]
        for e in self { let k = f(e); if m[k] == nil { order.append(k) }; m[k, default: []].append(e) }
        return order.map { ($0, m[$0]!) }
    }
    func partition(_ p: (Element) -> Bool) -> ([Element], [Element]) {
        var a: [Element] = [], b: [Element] = []
        for e in self { if p(e) { a.append(e) } else { b.append(e) } }
        return (a, b)
    }
    func zipWithNext() -> [(Element, Element)] { count < 2 ? [] : (0..<(count - 1)).map { (self[$0], self[$0 + 1]) } }
    func random(_ rng: KRandom = KRandom.default) -> Element { self[rng.nextInt(until: count)] }
    func shuffled(_ rng: KRandom) -> [Element] { shuffled(random: rng) }
    mutating func removeFirstOrNull() -> Element? { isEmpty ? nil : removeFirst() }
    mutating func removeLastOrNull() -> Element? { isEmpty ? nil : removeLast() }
    mutating func removeAt(_ i: Int) -> Element { remove(at: i) }
    mutating func addLast(_ e: Element) { append(e) }
    mutating func addFirst(_ e: Element) { insert(e, at: 0) }
    mutating func add(_ e: Element) { append(e) }
}

extension Array where Element: Equatable {
    func indexOf(_ e: Element) -> Int { firstIndex(of: e) ?? -1 }
    func distinct() -> [Element] { var out: [Element] = []; for e in self where !out.contains(e) { out.append(e) }; return out }
    mutating func remove(_ e: Element) -> Bool { if let i = firstIndex(of: e) { remove(at: i); return true }; return false }
}

extension Array where Element: Hashable {
    func toSet() -> Set<Element> { Set(self) }
    func distinctBy<K: Hashable>(_ f: (Element) -> K) -> [Element] {
        var seen = Set<K>(); return filter { seen.insert(f($0)).inserted }
    }
}

extension Array where Element == Int {
    func sum() -> Int { reduce(0, +) }
}
extension Array where Element == Float {
    func sum() -> Float { reduce(0, +) }
}
extension Array where Element == Double {
    func sum() -> Double { reduce(0, +) }
    func average() -> Double { isEmpty ? .nan : sum() / Double(count) }
}

extension Set {
    func isNotEmpty() -> Bool { !isEmpty }
    var size: Int { count }
}

extension Dictionary {
    func getOrDefault(_ k: Key, _ d: Value) -> Value { self[k] ?? d }
    func isNotEmpty() -> Bool { !isEmpty }
    var size: Int { count }
}

extension Optional where Wrapped == String {
    func isNullOrEmpty() -> Bool { self?.isEmpty ?? true }
    func isNullOrBlank() -> Bool { self?.isBlank() ?? true }
    func orEmpty() -> String { self ?? "" }
}

// MARK: - 시간

enum System {
    static func currentTimeMillis() -> Int { Int(Date().timeIntervalSince1970 * 1000) }
    static func nanoTime() -> Int { Int(DispatchTime.now().uptimeNanoseconds) }
}
enum SystemClock {
    static func uptimeMillis() -> Int { Int(DispatchTime.now().uptimeNanoseconds / 1_000_000) }
    static func elapsedRealtime() -> Int { uptimeMillis() }
}

/// java.time.LocalDate 의 필요한 만큼 — 기기 시간대 기준 날짜.
struct LocalDate: Equatable, Comparable {
    let epochDay: Int

    static func now() -> LocalDate {
        let c = Calendar(identifier: .gregorian)
        let d = c.dateComponents([.year, .month, .day], from: Date())
        return of(d.year!, d.month!, d.day!)
    }
    static func ofEpochDay(_ d: Int) -> LocalDate { LocalDate(epochDay: d) }
    static func of(_ y: Int, _ m: Int, _ d: Int) -> LocalDate {
        // 그레고리력 → 1970-01-01 기준 일수 (java.time 과 같은 식)
        var total = 365 * y
        if y >= 0 { total += (y + 3) / 4 - (y + 99) / 100 + (y + 399) / 400 } else { total -= y / -4 - y / -100 + y / -400 }
        total += (367 * m - 362) / 12
        total += d - 1
        if m > 2 { total -= 1; if !isLeap(y) { total -= 1 } }
        return LocalDate(epochDay: total - 719528)
    }
    static func isLeap(_ y: Int) -> Bool { (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }

    func toEpochDay() -> Int { epochDay }
    func plusDays(_ n: Int) -> LocalDate { LocalDate(epochDay: epochDay + n) }
    func minusDays(_ n: Int) -> LocalDate { LocalDate(epochDay: epochDay - n) }

    private var ymd: (Int, Int, Int) {
        // java.time LocalDate.ofEpochDay
        var zeroDay = epochDay + 719528 - 60
        var adjust = 0
        if zeroDay < 0 { let cycles = (zeroDay + 1) / 146097 - 1; adjust = cycles * 400; zeroDay += -cycles * 146097 }
        var yearEst = (400 * zeroDay + 591) / 146097
        var doyEst = zeroDay - (365 * yearEst + yearEst / 4 - yearEst / 100 + yearEst / 400)
        if doyEst < 0 { yearEst -= 1; doyEst = zeroDay - (365 * yearEst + yearEst / 4 - yearEst / 100 + yearEst / 400) }
        yearEst += adjust
        let marchDoy0 = doyEst
        let marchMonth0 = (marchDoy0 * 5 + 2) / 153
        let month = (marchMonth0 + 2) % 12 + 1
        let dom = marchDoy0 - (marchMonth0 * 306 + 5) / 10 + 1
        yearEst += marchMonth0 / 10
        return (yearEst, month, dom)
    }
    var year: Int { ymd.0 }
    var monthValue: Int { ymd.1 }
    var dayOfMonth: Int { ymd.2 }
    /// 1=월 … 7=일 (java DayOfWeek.value)
    var dayOfWeekValue: Int { ((epochDay + 3) % 7 + 7) % 7 + 1 }

    static func < (a: LocalDate, b: LocalDate) -> Bool { a.epochDay < b.epochDay }
}

// MARK: - java.text / java.util 시간

/// java.text.SimpleDateFormat — 패턴 글자는 자바와 ICU 가 거의 같다(yyyy-MM-dd HH:mm:ss, M/d …)
final class SimpleDateFormat {
    private let f = DateFormatter()
    init(_ pattern: String, _ locale: JLocale = JLocale.getDefault()) {
        f.dateFormat = pattern
        f.locale = locale.foundation
        f.timeZone = .current
    }
    func format(_ d: Date) -> String { f.string(from: d) }
    func format(_ millis: Int) -> String { f.string(from: Date(timeIntervalSince1970: Double(millis) / 1000)) }
}
extension Date {
    /// java.util.Date(millis)
    init(millis: Int) { self.init(timeIntervalSince1970: Double(millis) / 1000) }
    var time: Int { Int(timeIntervalSince1970 * 1000) }
}

/// java.util.Calendar 의 필요한 만큼
final class JCalendar {
    static let YEAR = 1, MONTH = 2, DAY_OF_MONTH = 5, HOUR_OF_DAY = 11, MINUTE = 12, SECOND = 13, DAY_OF_WEEK = 7
    private var date = Date()
    static func getInstance() -> JCalendar { JCalendar() }
    var timeInMillis: Int { get { date.time } set { date = Date(millis: newValue) } }
    func get(_ field: Int) -> Int {
        let c = Calendar(identifier: .gregorian)
        switch field {
        case JCalendar.YEAR: return c.component(.year, from: date)
        case JCalendar.MONTH: return c.component(.month, from: date) - 1
        case JCalendar.DAY_OF_MONTH: return c.component(.day, from: date)
        case JCalendar.HOUR_OF_DAY: return c.component(.hour, from: date)
        case JCalendar.MINUTE: return c.component(.minute, from: date)
        case JCalendar.SECOND: return c.component(.second, from: date)
        case JCalendar.DAY_OF_WEEK: return c.component(.weekday, from: date)
        default: return 0
        }
    }
}

/// 코틀린 Pair / Triple
struct Pair<A, B> {
    var first: A
    var second: B
    init(_ a: A, _ b: B) { first = a; second = b }
}
extension Pair: Equatable where A: Equatable, B: Equatable {}
extension Pair: Hashable where A: Hashable, B: Hashable {}
struct Triple<A, B, C> {
    var first: A
    var second: B
    var third: C
    init(_ a: A, _ b: B, _ c: C) { first = a; second = b; third = c }
}
extension Triple: Equatable where A: Equatable, B: Equatable, C: Equatable {}
extension Triple: Hashable where A: Hashable, B: Hashable, C: Hashable {}

/// 코틀린 `a to b`
func to<A, B>(_ a: A, _ b: B) -> Pair<A, B> { Pair(a, b) }

/// 코틀린 enum 의 name·ordinal·entries·valueOf — `enum X: String, KotlinEnum` 으로 쓰면 원시값이 이름
protocol KotlinEnum: CaseIterable, Equatable {}
extension KotlinEnum {
    var ordinal: Int { Array(Self.allCases).firstIndex(of: self)! }
    static var entries: [Self] { Array(allCases) }
    static func values() -> [Self] { Array(allCases) }
}
extension KotlinEnum where Self: RawRepresentable, RawValue == String {
    var name: String { rawValue }
    static func valueOf(_ s: String) -> Self { Self(rawValue: s)! }
    static func valueOfOrNull(_ s: String) -> Self? { Self(rawValue: s) }
}
