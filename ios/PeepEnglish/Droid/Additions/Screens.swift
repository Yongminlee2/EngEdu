import UIKit

// 화면(Main·Track·Stats …)을 옮기며 호환 층에 더한 것. 나중에 Droid/ 로 합친다.

// MARK: - Pair 풀기

/// 코틀린 `val (a, b) = pair` — 받은 값이 Pair 든 튜플이든 같은 코드로 푼다
func unpair<A, B>(_ p: Pair<A, B>) -> (A, B) { (p.first, p.second) }
func unpair<A, B>(_ p: (A, B)) -> (A, B) { p }

// MARK: - InsetDrawable

/// 안드로이드 InsetDrawable — 안쪽 그림을 사방 여백만큼 줄여 그린다
final class InsetDrawable: Drawable {
    let drawable: Drawable?
    let insetLeft: Int, insetTop: Int, insetRight: Int, insetBottom: Int

    init(_ drawable: Drawable?, _ l: Int, _ t: Int, _ r: Int, _ b: Int) {
        self.drawable = drawable
        insetLeft = l; insetTop = t; insetRight = r; insetBottom = b
    }
    convenience init(_ drawable: Drawable?, _ inset: Int) { self.init(drawable, inset, inset, inset, inset) }

    override var intrinsicWidth: Int {
        guard let w = drawable?.intrinsicWidth, w >= 0 else { return -1 }
        return w + insetLeft + insetRight
    }
    override var intrinsicHeight: Int {
        guard let h = drawable?.intrinsicHeight, h >= 0 else { return -1 }
        return h + insetTop + insetBottom
    }

    override func draw(_ canvas: Canvas) {
        guard let d = drawable else { return }
        d.setBounds(bounds.left + insetLeft, bounds.top + insetTop, bounds.right - insetRight, bounds.bottom - insetBottom)
        let oldAlpha = d.alpha, oldTint = d.tintColor
        d.alpha = alpha
        if let t = tintColor { d.tintColor = t }
        d.draw(canvas)
        d.alpha = oldAlpha; d.tintColor = oldTint
    }
}

// MARK: - android.text.Layout 상수

/// TextView.breakStrategy · hyphenationFrequency 값 (아이폰은 줄바꿈을 스스로 정한다)
enum Layout {
    static let BREAK_STRATEGY_SIMPLE = 0, BREAK_STRATEGY_HIGH_QUALITY = 1, BREAK_STRATEGY_BALANCED = 2
    static let HYPHENATION_FREQUENCY_NONE = 0, HYPHENATION_FREQUENCY_NORMAL = 1, HYPHENATION_FREQUENCY_FULL = 2
}

// MARK: - LocalDate (달력)

/// java.time.DayOfWeek — value 1=월 … 7=일
struct DayOfWeek: Equatable {
    let value: Int
}

extension LocalDate {
    var dayOfWeek: DayOfWeek { DayOfWeek(value: dayOfWeekValue) }
    func withDayOfMonth(_ d: Int) -> LocalDate { LocalDate.of(year, monthValue, d) }
    func lengthOfMonth() -> Int {
        switch monthValue {
        case 2: return LocalDate.isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }
    func isAfter(_ o: LocalDate) -> Bool { epochDay > o.epochDay }
    func isBefore(_ o: LocalDate) -> Bool { epochDay < o.epochDay }
}
