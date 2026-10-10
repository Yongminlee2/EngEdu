import UIKit

// LinearLayout · FrameLayout · ScrollView · GridLayout — 안드로이드 원본의 재기·배치 규칙을 옮긴 것.

extension ViewGroup {
    typealias LayoutParams = BaseLayoutParams
    typealias MarginLayoutParams = DroidMarginLayoutParams
}

// MARK: - LinearLayout

class LinearLayout: ViewGroup {
    static let HORIZONTAL = 0
    static let VERTICAL = 1
    static let SHOW_DIVIDER_NONE = 0, SHOW_DIVIDER_MIDDLE = 2

    final class LayoutParams: DroidMarginLayoutParams {
        var weight: Float = 0
        var gravity: Int = -1
        override init(_ width: Int, _ height: Int) { super.init(width, height) }
        init(_ width: Int, _ height: Int, _ weight: Float) { super.init(width, height); self.weight = weight }
        override init(_ src: BaseLayoutParams) {
            super.init(src)
            if let l = src as? LayoutParams { weight = l.weight; gravity = l.gravity }
        }
    }

    var orientation = LinearLayout.HORIZONTAL { didSet { requestLayout() } }
    var gravity = Gravity.START | Gravity.TOP { didSet { requestLayout() } }
    var weightSum: Float = -1
    var isBaselineAligned = true
    var showDividers = 0
    var dividerPadding = 0
    var dividerDrawable: Drawable?
    func setOrientation(_ o: Int) { orientation = o }
    func setGravity(_ g: Int) { gravity = g }
    func setHorizontalGravity(_ g: Int) { gravity = (gravity & ~Gravity.HORIZONTAL_GRAVITY_MASK) | (g & Gravity.HORIZONTAL_GRAVITY_MASK) }
    func setVerticalGravity(_ g: Int) { gravity = (gravity & ~Gravity.VERTICAL_GRAVITY_MASK) | (g & Gravity.VERTICAL_GRAVITY_MASK) }

    private var totalLength = 0

    override func generateDefaultLayoutParams() -> BaseLayoutParams {
        orientation == LinearLayout.HORIZONTAL
            ? LayoutParams(BaseLayoutParams.WRAP_CONTENT, BaseLayoutParams.WRAP_CONTENT)
            : LayoutParams(BaseLayoutParams.MATCH_PARENT, BaseLayoutParams.WRAP_CONTENT)
    }
    override func generateLayoutParams(_ p: BaseLayoutParams) -> BaseLayoutParams { LayoutParams(p) }
    override func checkLayoutParams(_ p: BaseLayoutParams) -> Bool { p is LayoutParams }

    private func lpOf(_ c: View) -> LayoutParams { (c.layoutParams as? LayoutParams) ?? LayoutParams(c.layoutParams ?? generateDefaultLayoutParams()) }

    override func onMeasure(_ w: Int, _ h: Int) {
        if orientation == LinearLayout.VERTICAL { measureVertical(w, h) } else { measureHorizontal(w, h) }
    }

    private func measureVertical(_ widthSpec: Int, _ heightSpec: Int) {
        totalLength = 0
        var maxWidth = 0
        var alternativeMaxWidth = 0
        var weightedMaxWidth = 0
        var totalWeight: Float = 0
        var matchWidth = false
        var allFillParent = true
        var skippedMeasure = false
        let widthMode = MeasureSpec.getMode(widthSpec)
        let heightMode = MeasureSpec.getMode(heightSpec)
        let visible = children.filter { $0.visibility != View.GONE }

        for child in visible {
            let lp = lpOf(child)
            totalWeight += lp.weight
            let useExcess = lp.height == 0 && lp.weight > 0
            if heightMode == MeasureSpec.EXACTLY && useExcess {
                totalLength = max(totalLength, totalLength + lp.topMargin + lp.bottomMargin)
                skippedMeasure = true
            } else {
                let saved = lp.height
                if useExcess { lp.height = BaseLayoutParams.WRAP_CONTENT }
                let usedHeight = totalWeight == 0 ? totalLength : 0
                measureChildWithMargins(child, widthSpec, 0, heightSpec, usedHeight)
                lp.height = saved
                totalLength = max(totalLength, totalLength + child.measuredHeight + lp.topMargin + lp.bottomMargin)
            }
            var matchWidthLocally = false
            if widthMode != MeasureSpec.EXACTLY && lp.width == BaseLayoutParams.MATCH_PARENT {
                matchWidth = true; matchWidthLocally = true
            }
            let margin = lp.leftMargin + lp.rightMargin
            let measuredW = child.measuredWidth + margin
            maxWidth = max(maxWidth, measuredW)
            allFillParent = allFillParent && lp.width == BaseLayoutParams.MATCH_PARENT
            if lp.weight > 0 { weightedMaxWidth = max(weightedMaxWidth, matchWidthLocally ? margin : measuredW) }
            else { alternativeMaxWidth = max(alternativeMaxWidth, matchWidthLocally ? margin : measuredW) }
        }

        totalLength += paddingTop + paddingBottom
        var heightSize = max(totalLength, suggestedMinimumHeight)
        heightSize = View.resolveSize(heightSize, heightSpec)
        var remaining = heightSize - totalLength

        if skippedMeasure || (remaining != 0 && totalWeight > 0) {
            var weightLeft = weightSum > 0 ? weightSum : totalWeight
            totalLength = 0
            for child in visible {
                let lp = lpOf(child)
                if lp.weight > 0 && weightLeft > 0 {
                    let share = Int(Float(remaining) * lp.weight / weightLeft)
                    weightLeft -= lp.weight
                    remaining -= share
                    let childH: Int
                    if lp.height == 0 && heightMode == MeasureSpec.EXACTLY { childH = max(0, share) }
                    else { childH = max(0, child.measuredHeight + share) }
                    let cw = ViewGroup.getChildMeasureSpec(widthSpec, paddingLeft + paddingRight + lp.leftMargin + lp.rightMargin, lp.width)
                    child.measure(cw, MeasureSpec.makeMeasureSpec(childH, MeasureSpec.EXACTLY))
                }
                let margin = lp.leftMargin + lp.rightMargin
                let measuredW = child.measuredWidth + margin
                maxWidth = max(maxWidth, measuredW)
                let matchLocally = widthMode != MeasureSpec.EXACTLY && lp.width == BaseLayoutParams.MATCH_PARENT
                alternativeMaxWidth = max(alternativeMaxWidth, matchLocally ? margin : measuredW)
                totalLength = max(totalLength, totalLength + child.measuredHeight + lp.topMargin + lp.bottomMargin)
            }
            totalLength += paddingTop + paddingBottom
        } else {
            alternativeMaxWidth = max(alternativeMaxWidth, weightedMaxWidth)
        }

        if !allFillParent && widthMode != MeasureSpec.EXACTLY { maxWidth = alternativeMaxWidth }
        maxWidth += paddingLeft + paddingRight
        maxWidth = max(maxWidth, suggestedMinimumWidth)
        setMeasuredDimension(View.resolveSize(maxWidth, widthSpec), heightSize)

        if matchWidth {
            let uniform = MeasureSpec.makeMeasureSpec(measuredWidth, MeasureSpec.EXACTLY)
            for child in visible {
                let lp = lpOf(child)
                if lp.width == BaseLayoutParams.MATCH_PARENT {
                    let oldH = lp.height
                    lp.height = child.measuredHeight
                    measureChildWithMargins(child, uniform, 0, heightSpec, 0)
                    lp.height = oldH
                }
            }
        }
    }

    private func measureHorizontal(_ widthSpec: Int, _ heightSpec: Int) {
        totalLength = 0
        var maxHeight = 0
        var alternativeMaxHeight = 0
        var weightedMaxHeight = 0
        var totalWeight: Float = 0
        var matchHeight = false
        var allFillParent = true
        var skippedMeasure = false
        let widthMode = MeasureSpec.getMode(widthSpec)
        let heightMode = MeasureSpec.getMode(heightSpec)
        let visible = children.filter { $0.visibility != View.GONE }
        var maxAscent = -1, maxDescent = -1

        for child in visible {
            let lp = lpOf(child)
            totalWeight += lp.weight
            let useExcess = lp.width == 0 && lp.weight > 0
            if widthMode == MeasureSpec.EXACTLY && useExcess {
                totalLength += lp.leftMargin + lp.rightMargin
                skippedMeasure = true
            } else {
                let saved = lp.width
                if useExcess { lp.width = BaseLayoutParams.WRAP_CONTENT }
                let usedWidth = totalWeight == 0 ? totalLength : 0
                measureChildWithMargins(child, widthSpec, usedWidth, heightSpec, 0)
                lp.width = saved
                totalLength = max(totalLength, totalLength + child.measuredWidth + lp.leftMargin + lp.rightMargin)
            }
            var matchHeightLocally = false
            if heightMode != MeasureSpec.EXACTLY && lp.height == BaseLayoutParams.MATCH_PARENT {
                matchHeight = true; matchHeightLocally = true
            }
            let margin = lp.topMargin + lp.bottomMargin
            let childHeight = child.measuredHeight + margin
            if isBaselineAligned, lp.height != BaseLayoutParams.MATCH_PARENT, let tv = child as? TextView,
               (lp.gravity < 0 ? gravity : lp.gravity) & Gravity.VERTICAL_GRAVITY_MASK == Gravity.TOP || (lp.gravity < 0 && gravity & Gravity.VERTICAL_GRAVITY_MASK == 0) {
                let base = tv.getBaseline()
                if base >= 0 {
                    maxAscent = max(maxAscent, base + lp.topMargin)
                    maxDescent = max(maxDescent, childHeight - base - lp.topMargin)
                }
            }
            maxHeight = max(maxHeight, childHeight)
            allFillParent = allFillParent && lp.height == BaseLayoutParams.MATCH_PARENT
            if lp.weight > 0 { weightedMaxHeight = max(weightedMaxHeight, matchHeightLocally ? margin : childHeight) }
            else { alternativeMaxHeight = max(alternativeMaxHeight, matchHeightLocally ? margin : childHeight) }
        }
        if maxAscent >= 0 { maxHeight = max(maxHeight, maxAscent + maxDescent) }

        totalLength += paddingLeft + paddingRight
        var widthSize = max(totalLength, suggestedMinimumWidth)
        widthSize = View.resolveSize(widthSize, widthSpec)
        var remaining = widthSize - totalLength

        if skippedMeasure || (remaining != 0 && totalWeight > 0) {
            var weightLeft = weightSum > 0 ? weightSum : totalWeight
            totalLength = 0
            maxHeight = -1
            maxAscent = -1; maxDescent = -1
            for child in visible {
                let lp = lpOf(child)
                if lp.weight > 0 && weightLeft > 0 {
                    let share = Int(Float(remaining) * lp.weight / weightLeft)
                    weightLeft -= lp.weight
                    remaining -= share
                    let childW: Int
                    if lp.width == 0 && widthMode == MeasureSpec.EXACTLY { childW = max(0, share) }
                    else { childW = max(0, child.measuredWidth + share) }
                    let ch = ViewGroup.getChildMeasureSpec(heightSpec, paddingTop + paddingBottom + lp.topMargin + lp.bottomMargin, lp.height)
                    child.measure(MeasureSpec.makeMeasureSpec(childW, MeasureSpec.EXACTLY), ch)
                }
                totalLength = max(totalLength, totalLength + child.measuredWidth + lp.leftMargin + lp.rightMargin)
                let margin = lp.topMargin + lp.bottomMargin
                let childHeight = child.measuredHeight + margin
                maxHeight = max(maxHeight, childHeight)
                let matchLocally = heightMode != MeasureSpec.EXACTLY && lp.height == BaseLayoutParams.MATCH_PARENT
                alternativeMaxHeight = max(alternativeMaxHeight, matchLocally ? margin : childHeight)
                if isBaselineAligned, lp.height != BaseLayoutParams.MATCH_PARENT, let tv = child as? TextView,
                   (lp.gravity < 0 ? gravity : lp.gravity) & Gravity.VERTICAL_GRAVITY_MASK == Gravity.TOP || (lp.gravity < 0 && gravity & Gravity.VERTICAL_GRAVITY_MASK == 0) {
                    let base = tv.getBaseline()
                    if base >= 0 {
                        maxAscent = max(maxAscent, base + lp.topMargin)
                        maxDescent = max(maxDescent, childHeight - base - lp.topMargin)
                    }
                }
            }
            if maxAscent >= 0 { maxHeight = max(maxHeight, maxAscent + maxDescent) }
            totalLength += paddingLeft + paddingRight
        } else {
            alternativeMaxHeight = max(alternativeMaxHeight, weightedMaxHeight)
        }

        if !allFillParent && heightMode != MeasureSpec.EXACTLY { maxHeight = alternativeMaxHeight }
        maxHeight += paddingTop + paddingBottom
        maxHeight = max(maxHeight, suggestedMinimumHeight)
        setMeasuredDimension(widthSize, View.resolveSize(maxHeight, heightSpec))

        if matchHeight {
            let uniform = MeasureSpec.makeMeasureSpec(measuredHeight, MeasureSpec.EXACTLY)
            for child in visible {
                let lp = lpOf(child)
                if lp.height == BaseLayoutParams.MATCH_PARENT {
                    let oldW = lp.width
                    lp.width = child.measuredWidth
                    measureChildWithMargins(child, widthSpec, 0, uniform, 0)
                    lp.width = oldW
                }
            }
        }
    }

    override func onLayout(_ changed: Bool, _ l: Int, _ t: Int, _ r: Int, _ b: Int) {
        if orientation == LinearLayout.VERTICAL { layoutVertical(l, t, r, b) } else { layoutHorizontal(l, t, r, b) }
    }

    private func layoutVertical(_ l: Int, _ t: Int, _ r: Int, _ b: Int) {
        let childRight = r - l - paddingRight
        let childSpace = r - l - paddingLeft - paddingRight
        var childTop: Int
        switch Gravity.vertical(gravity) {
        case 1: childTop = paddingTop + b - t - totalLength
        case 0: childTop = paddingTop + (b - t - totalLength) / 2
        default: childTop = paddingTop
        }
        for child in children where child.visibility != View.GONE {
            let lp = lpOf(child)
            let cw = child.measuredWidth, ch = child.measuredHeight
            let g = lp.gravity < 0 ? gravity : lp.gravity
            let childLeft: Int
            switch Gravity.horizontal(g) {
            case 0: childLeft = paddingLeft + (childSpace - cw) / 2 + lp.leftMargin - lp.rightMargin
            case 1: childLeft = childRight - cw - lp.rightMargin
            default: childLeft = paddingLeft + lp.leftMargin
            }
            childTop += lp.topMargin
            child.layout(childLeft, childTop, childLeft + cw, childTop + ch)
            childTop += ch + lp.bottomMargin
        }
    }

    private func layoutHorizontal(_ l: Int, _ t: Int, _ r: Int, _ b: Int) {
        let height = b - t
        let childBottom = height - paddingBottom
        let childSpace = height - paddingTop - paddingBottom
        var childLeft: Int
        switch Gravity.horizontal(gravity) {
        case 1: childLeft = paddingLeft + r - l - totalLength
        case 0: childLeft = paddingLeft + (r - l - totalLength) / 2
        default: childLeft = paddingLeft
        }
        // 기준선 맞추기(위 정렬일 때만, 안드로이드와 같게)
        var maxAscent = -1
        if isBaselineAligned {
            for child in children where child.visibility != View.GONE {
                let lp = lpOf(child)
                let g = lp.gravity < 0 ? gravity : lp.gravity
                if lp.height != BaseLayoutParams.MATCH_PARENT, Gravity.vertical(g) == -1, let tv = child as? TextView {
                    let base = tv.getBaseline()
                    if base >= 0 { maxAscent = max(maxAscent, base + lp.topMargin) }
                }
            }
        }
        for child in children where child.visibility != View.GONE {
            let lp = lpOf(child)
            let cw = child.measuredWidth, ch = child.measuredHeight
            let g = lp.gravity < 0 ? gravity : lp.gravity
            var childTop: Int
            switch Gravity.vertical(g) {
            case 0: childTop = paddingTop + (childSpace - ch) / 2 + lp.topMargin - lp.bottomMargin
            case 1: childTop = childBottom - ch - lp.bottomMargin
            default:
                childTop = paddingTop + lp.topMargin
                if maxAscent >= 0, lp.height != BaseLayoutParams.MATCH_PARENT, let tv = child as? TextView {
                    let base = tv.getBaseline()
                    if base >= 0 { childTop += maxAscent - lp.topMargin - base }
                }
            }
            childLeft += lp.leftMargin
            child.layout(childLeft, childTop, childLeft + cw, childTop + ch)
            childLeft += cw + lp.rightMargin
        }
    }
}

// MARK: - FrameLayout

class FrameLayout: ViewGroup {
    final class LayoutParams: DroidMarginLayoutParams {
        static let UNSPECIFIED_GRAVITY = -1
        var gravity: Int = -1
        override init(_ width: Int, _ height: Int) { super.init(width, height) }
        init(_ width: Int, _ height: Int, _ gravity: Int) { super.init(width, height); self.gravity = gravity }
        override init(_ src: BaseLayoutParams) {
            super.init(src)
            if let f = src as? LayoutParams { gravity = f.gravity }
        }
    }

    var measureAllChildren = false
    var foregroundGravity = 0

    override func generateDefaultLayoutParams() -> BaseLayoutParams { LayoutParams(BaseLayoutParams.MATCH_PARENT, BaseLayoutParams.MATCH_PARENT) }
    override func generateLayoutParams(_ p: BaseLayoutParams) -> BaseLayoutParams { LayoutParams(p) }
    override func checkLayoutParams(_ p: BaseLayoutParams) -> Bool { p is LayoutParams }

    func lpOf(_ c: View) -> LayoutParams { (c.layoutParams as? LayoutParams) ?? LayoutParams(c.layoutParams ?? generateDefaultLayoutParams()) }

    override func onMeasure(_ widthSpec: Int, _ heightSpec: Int) {
        let measureMatchParent = MeasureSpec.getMode(widthSpec) != MeasureSpec.EXACTLY || MeasureSpec.getMode(heightSpec) != MeasureSpec.EXACTLY
        var maxW = 0, maxH = 0
        var matchChildren: [View] = []
        for child in children where measureAllChildren || child.visibility != View.GONE {
            measureChildForFrame(child, widthSpec, heightSpec)
            let lp = lpOf(child)
            maxW = max(maxW, child.measuredWidth + lp.leftMargin + lp.rightMargin)
            maxH = max(maxH, child.measuredHeight + lp.topMargin + lp.bottomMargin)
            if measureMatchParent && (lp.width == BaseLayoutParams.MATCH_PARENT || lp.height == BaseLayoutParams.MATCH_PARENT) {
                matchChildren.append(child)
            }
        }
        maxW += paddingLeft + paddingRight
        maxH += paddingTop + paddingBottom
        maxW = max(maxW, suggestedMinimumWidth)
        maxH = max(maxH, suggestedMinimumHeight)
        setMeasuredDimension(View.resolveSize(maxW, widthSpec), View.resolveSize(maxH, heightSpec))

        if matchChildren.count > 1 {
            for child in matchChildren {
                let lp = lpOf(child)
                let cw = lp.width == BaseLayoutParams.MATCH_PARENT
                    ? MeasureSpec.makeMeasureSpec(max(0, measuredWidth - paddingLeft - paddingRight - lp.leftMargin - lp.rightMargin), MeasureSpec.EXACTLY)
                    : ViewGroup.getChildMeasureSpec(widthSpec, paddingLeft + paddingRight + lp.leftMargin + lp.rightMargin, lp.width)
                let ch = lp.height == BaseLayoutParams.MATCH_PARENT
                    ? MeasureSpec.makeMeasureSpec(max(0, measuredHeight - paddingTop - paddingBottom - lp.topMargin - lp.bottomMargin), MeasureSpec.EXACTLY)
                    : ViewGroup.getChildMeasureSpec(heightSpec, paddingTop + paddingBottom + lp.topMargin + lp.bottomMargin, lp.height)
                child.measure(cw, ch)
            }
        }
    }

    /// ScrollView 가 덮어써서 세로를 무한으로 잰다
    func measureChildForFrame(_ child: View, _ widthSpec: Int, _ heightSpec: Int) {
        measureChildWithMargins(child, widthSpec, 0, heightSpec, 0)
    }

    override func onLayout(_ changed: Bool, _ l: Int, _ t: Int, _ r: Int, _ b: Int) {
        layoutFrameChildren(r - l, b - t)
    }

    func layoutFrameChildren(_ w: Int, _ h: Int) {
        let parentLeft = paddingLeft, parentRight = w - paddingRight
        let parentTop = paddingTop, parentBottom = h - paddingBottom
        for child in children where child.visibility != View.GONE {
            let lp = lpOf(child)
            let cw = child.measuredWidth, ch = child.measuredHeight
            let g = lp.gravity < 0 ? (Gravity.TOP | Gravity.START) : lp.gravity
            let childLeft: Int
            switch Gravity.horizontal(g) {
            case 0: childLeft = parentLeft + (parentRight - parentLeft - cw) / 2 + lp.leftMargin - lp.rightMargin
            case 1: childLeft = parentRight - cw - lp.rightMargin
            default: childLeft = parentLeft + lp.leftMargin
            }
            let childTop: Int
            switch Gravity.vertical(g) {
            case 0: childTop = parentTop + (parentBottom - parentTop - ch) / 2 + lp.topMargin - lp.bottomMargin
            case 1: childTop = parentBottom - ch - lp.bottomMargin
            default: childTop = parentTop + lp.topMargin
            }
            child.layout(childLeft, childTop, childLeft + cw, childTop + ch)
        }
    }
}

// MARK: - ScrollView

class ScrollView: FrameLayout, UIScrollViewDelegate {
    static let FOCUS_UP = 33, FOCUS_DOWN = 130

    let scroller = UIScrollView()
    override var childContainer: UIView { scroller }

    var isFillViewport = false { didSet { requestLayout() } }
    var isVerticalScrollBarEnabled: Bool {
        get { scroller.showsVerticalScrollIndicator }
        set { scroller.showsVerticalScrollIndicator = newValue }
    }
    var isSmoothScrollingEnabled = true
    private var disallowCount = 0
    private var onScrollChange: ((View, Int, Int, Int, Int) -> Void)?

    override init(_ context: Context, _ attrs: AttributeSet? = nil) {
        super.init(context, attrs)
        scroller.delaysContentTouches = false
        scroller.canCancelContentTouches = true
        scroller.alwaysBounceVertical = false
        scroller.showsHorizontalScrollIndicator = false
        scroller.contentInsetAdjustmentBehavior = .never
        scroller.keyboardDismissMode = .interactive
        scroller.delegate = self
        addSubview(scroller)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func measureChildForFrame(_ child: View, _ widthSpec: Int, _ heightSpec: Int) {
        let lp = lpOf(child)
        let cw = ViewGroup.getChildMeasureSpec(widthSpec, paddingLeft + paddingRight + lp.leftMargin + lp.rightMargin, lp.width)
        let used = paddingTop + paddingBottom + lp.topMargin + lp.bottomMargin
        child.measure(cw, MeasureSpec.makeMeasureSpec(max(0, MeasureSpec.getSize(heightSpec) - used), MeasureSpec.UNSPECIFIED))
    }

    override func onMeasure(_ widthSpec: Int, _ heightSpec: Int) {
        super.onMeasure(widthSpec, heightSpec)
        guard isFillViewport, MeasureSpec.getMode(heightSpec) != MeasureSpec.UNSPECIFIED, let child = children.first else { return }
        let lp = lpOf(child)
        let h = measuredHeight - paddingTop - paddingBottom - lp.topMargin - lp.bottomMargin
        if child.measuredHeight < h {
            let cw = ViewGroup.getChildMeasureSpec(widthSpec, paddingLeft + paddingRight + lp.leftMargin + lp.rightMargin, lp.width)
            child.measure(cw, MeasureSpec.makeMeasureSpec(h, MeasureSpec.EXACTLY))
        }
    }

    override func onLayout(_ changed: Bool, _ l: Int, _ t: Int, _ r: Int, _ b: Int) {
        scroller.frame = CGRect(x: 0, y: 0, width: r - l, height: b - t)
        var contentH = 0, contentW = r - l
        for child in children where child.visibility != View.GONE {
            let lp = lpOf(child)
            let x = paddingLeft + lp.leftMargin, y = paddingTop + lp.topMargin
            child.layout(x, y, x + child.measuredWidth, y + child.measuredHeight)
            contentH = max(contentH, y + child.measuredHeight + lp.bottomMargin + paddingBottom)
            contentW = max(contentW, x + child.measuredWidth)
        }
        scroller.contentSize = CGSize(width: contentW, height: contentH)
        // 내용이 줄었으면 끝을 넘지 않게
        let maxY = max(0, CGFloat(contentH) - scroller.bounds.height + scroller.contentInset.bottom)
        if scroller.contentOffset.y > maxY { scroller.contentOffset.y = maxY }
    }

    var scrollY: Int {
        get { Int(scroller.contentOffset.y) }
        set { scrollTo(0, newValue) }
    }
    var scrollX: Int { Int(scroller.contentOffset.x) }
    func getScrollY() -> Int { scrollY }

    private func clampY(_ y: Int) -> CGFloat {
        let maxY = max(0, scroller.contentSize.height - scroller.bounds.height + scroller.contentInset.bottom)
        return min(max(0, CGFloat(y)), maxY)
    }
    func scrollTo(_ x: Int, _ y: Int) { scroller.setContentOffset(CGPoint(x: 0, y: clampY(y)), animated: false) }
    func scrollBy(_ x: Int, _ y: Int) { scrollTo(0, scrollY + y) }
    func smoothScrollTo(_ x: Int, _ y: Int) { scroller.setContentOffset(CGPoint(x: 0, y: clampY(y)), animated: true) }
    func smoothScrollBy(_ x: Int, _ y: Int) { smoothScrollTo(0, scrollY + y) }
    @discardableResult func fullScroll(_ direction: Int) -> Bool {
        if direction == ScrollView.FOCUS_DOWN { smoothScrollTo(0, Int(scroller.contentSize.height)) } else { smoothScrollTo(0, 0) }
        return true
    }
    func setOnScrollChangeListener(_ f: ((View, Int, Int, Int, Int) -> Void)?) { onScrollChange = f }

    private var lastY = 0
    func scrollViewDidScroll(_ s: UIScrollView) {
        let y = Int(s.contentOffset.y)
        onScrollChange?(self, 0, y, 0, lastY)
        lastY = y
    }

    override func requestDisallowInterceptTouchEvent(_ disallow: Bool) {
        if disallow {
            disallowCount += 1
            scroller.panGestureRecognizer.isEnabled = false
            scroller.panGestureRecognizer.isEnabled = true   // 지금 하던 스크롤을 끊고
            scroller.isScrollEnabled = false
        } else if disallowCount > 0 {
            disallowCount = 0
            scroller.isScrollEnabled = true
        }
        super.requestDisallowInterceptTouchEvent(disallow)
    }

    /// 손을 떼면 막았던 스크롤을 푼다(안드로이드는 손을 뗄 때 저절로 풀린다)
    static func releaseDisallow(from v: View) {
        var p = v.parent
        while let g = p {
            if let s = g as? ScrollView, s.disallowCount > 0 { s.disallowCount = 0; s.scroller.isScrollEnabled = true }
            p = g.parent
        }
    }
}

typealias NestedScrollView = ScrollView

// MARK: - GridLayout

class GridLayout: ViewGroup {
    static let UNDEFINED = Int.min
    static let HORIZONTAL = 0, VERTICAL = 1

    struct Alignment: Equatable { let g: Int }
    static let START = Alignment(g: Gravity.START), END = Alignment(g: Gravity.END)
    static let CENTER = Alignment(g: Gravity.CENTER), FILL = Alignment(g: Gravity.FILL)
    static let LEFT = Alignment(g: Gravity.LEFT), RIGHT = Alignment(g: Gravity.RIGHT)
    static let TOP = Alignment(g: Gravity.TOP), BOTTOM = Alignment(g: Gravity.BOTTOM)
    static let BASELINE = Alignment(g: Gravity.TOP)

    struct Spec {
        var start: Int = GridLayout.UNDEFINED
        var size: Int = 1
        var weight: Float = 0
        var alignment: Alignment? = nil
    }
    static func spec(_ start: Int) -> Spec { Spec(start: start) }
    static func spec(_ start: Int, _ size: Int) -> Spec { Spec(start: start, size: size) }
    static func spec(_ start: Int, _ weight: Float) -> Spec { Spec(start: start, weight: weight) }
    static func spec(_ start: Int, _ size: Int, _ weight: Float) -> Spec { Spec(start: start, size: size, weight: weight) }
    static func spec(_ start: Int, _ alignment: Alignment) -> Spec { Spec(start: start, alignment: alignment) }
    static func spec(_ start: Int, _ size: Int, _ alignment: Alignment) -> Spec { Spec(start: start, size: size, alignment: alignment) }
    static func spec(_ start: Int, _ alignment: Alignment, _ weight: Float) -> Spec { Spec(start: start, weight: weight, alignment: alignment) }
    static func spec(_ start: Int, _ size: Int, _ alignment: Alignment, _ weight: Float) -> Spec {
        Spec(start: start, size: size, weight: weight, alignment: alignment)
    }

    final class LayoutParams: DroidMarginLayoutParams {
        var rowSpec = Spec()
        var columnSpec = Spec()
        var gravity = -1
        init() { super.init(BaseLayoutParams.WRAP_CONTENT, BaseLayoutParams.WRAP_CONTENT) }
        init(_ rowSpec: Spec, _ columnSpec: Spec) {
            super.init(BaseLayoutParams.WRAP_CONTENT, BaseLayoutParams.WRAP_CONTENT)
            self.rowSpec = rowSpec; self.columnSpec = columnSpec
        }
        override init(_ width: Int, _ height: Int) { super.init(width, height) }
        override init(_ src: BaseLayoutParams) {
            super.init(src)
            if let g = src as? LayoutParams { rowSpec = g.rowSpec; columnSpec = g.columnSpec; gravity = g.gravity }
        }
        func setGravity(_ g: Int) { gravity = g }
    }

    var columnCount = 2 { didSet { requestLayout() } }
    var rowCount = GridLayout.UNDEFINED
    var orientation = GridLayout.HORIZONTAL
    var useDefaultMargins = false
    var alignmentMode = 0
    func setColumnCount(_ n: Int) { columnCount = n }

    override func generateDefaultLayoutParams() -> BaseLayoutParams { LayoutParams() }
    override func generateLayoutParams(_ p: BaseLayoutParams) -> BaseLayoutParams { LayoutParams(p) }
    override func checkLayoutParams(_ p: BaseLayoutParams) -> Bool { p is LayoutParams }
    private func lpOf(_ c: View) -> LayoutParams { (c.layoutParams as? LayoutParams) ?? LayoutParams(c.layoutParams ?? generateDefaultLayoutParams()) }

    private struct Cell { let view: View; let row: Int; let col: Int; let span: Int; let rowSpan: Int }
    private var cells: [Cell] = []
    private var colX: [Int] = []
    private var rowY: [Int] = []

    /// 자식들을 칸에 놓는다 (행 우선, 안드로이드 GridLayout 의 자동 배치와 같은 순서)
    private func place() -> [Cell] {
        let cols = max(1, columnCount)
        var occupied = Set<Int>()   // row * cols + col
        var out: [Cell] = []
        var row = 0, col = 0
        for v in children where v.visibility != View.GONE {
            let lp = lpOf(v)
            let span = min(cols, max(1, lp.columnSpec.size))
            let rowSpan = max(1, lp.rowSpec.size)
            if lp.rowSpec.start != GridLayout.UNDEFINED { if lp.rowSpec.start != row { row = lp.rowSpec.start; col = 0 } }
            if lp.columnSpec.start != GridLayout.UNDEFINED {
                if lp.columnSpec.start < col { row += 1 }
                col = lp.columnSpec.start
            }
            // 들어갈 자리를 찾는다
            while true {
                if col + span > cols { row += 1; col = lp.columnSpec.start != GridLayout.UNDEFINED ? lp.columnSpec.start : 0; continue }
                let free = (col..<(col + span)).allSatisfy { !occupied.contains(row * cols + $0) }
                if free { break }
                col += 1
            }
            for r in row..<(row + rowSpan) { for c in col..<(col + span) { occupied.insert(r * cols + c) } }
            out.append(Cell(view: v, row: row, col: col, span: span, rowSpan: rowSpan))
            col += span
        }
        return out
    }

    override func onMeasure(_ widthSpec: Int, _ heightSpec: Int) {
        cells = place()
        let cols = max(1, columnCount)
        let rows = (cells.map { $0.row + $0.rowSpan }.max() ?? 0)
        let widthMode = MeasureSpec.getMode(widthSpec)
        let availW = MeasureSpec.getSize(widthSpec) - paddingLeft - paddingRight

        // 열 무게
        var colWeight = [Float](repeating: 0, count: cols)
        for c in cells {
            let w = lpOf(c.view).columnSpec.weight
            if w > 0 { for i in c.col..<(c.col + c.span) { colWeight[i] = max(colWeight[i], w / Float(c.span)) } }
        }
        // 무게 없는 열은 내용 폭
        var colW = [Int](repeating: 0, count: cols)
        for c in cells where c.span == 1 && colWeight[c.col] == 0 {
            let lp = lpOf(c.view)
            measureChild(c.view, MeasureSpec.makeMeasureSpec(availW, widthMode == MeasureSpec.UNSPECIFIED ? MeasureSpec.UNSPECIFIED : MeasureSpec.AT_MOST),
                         heightSpec)
            colW[c.col] = max(colW[c.col], c.view.measuredWidth + lp.leftMargin + lp.rightMargin)
        }
        let totalWeight = colWeight.reduce(0, +)
        if totalWeight > 0 && widthMode != MeasureSpec.UNSPECIFIED {
            var remaining = max(0, availW - colW.enumerated().filter { colWeight[$0.offset] == 0 }.map { $0.element }.reduce(0, +))
            var weightLeft = totalWeight
            for i in 0..<cols where colWeight[i] > 0 {
                let share = Int(Float(remaining) * colWeight[i] / weightLeft)
                colW[i] = share; remaining -= share; weightLeft -= colWeight[i]
            }
        } else {
            // 무게 있는 열도 내용 폭으로
            for c in cells where c.span == 1 && colWeight[c.col] > 0 {
                let lp = lpOf(c.view)
                measureChild(c.view, MeasureSpec.makeMeasureSpec(availW, MeasureSpec.AT_MOST), heightSpec)
                colW[c.col] = max(colW[c.col], c.view.measuredWidth + lp.leftMargin + lp.rightMargin)
            }
        }

        // MATCH_PARENT 자식은 줄 폭 전체를 쓴다 — 걸친 열들을 넓힌다
        if widthMode != MeasureSpec.UNSPECIFIED {
            for c in cells where lpOf(c.view).width == BaseLayoutParams.MATCH_PARENT {
                let lp = lpOf(c.view)
                let have = colW[c.col..<(c.col + c.span)].reduce(0, +)
                let need = availW - colW.enumerated().filter { $0.offset < c.col || $0.offset >= c.col + c.span }.map { $0.element }.reduce(0, +)
                if need > have {
                    let extra = need - have
                    for (k, i) in (c.col..<(c.col + c.span)).enumerated() { colW[i] += extra / c.span + (k < extra % c.span ? 1 : 0) }
                }
                _ = lp
            }
        }

        // 자식 재기 (칸 폭에 맞춰)
        var rowH = [Int](repeating: 0, count: max(rows, 0))
        for c in cells {
            let lp = lpOf(c.view)
            let cellW = colW[c.col..<(c.col + c.span)].reduce(0, +) - lp.leftMargin - lp.rightMargin
            let fill = lp.width == 0 || lp.width == BaseLayoutParams.MATCH_PARENT ||
                (lp.columnSpec.alignment == GridLayout.FILL) || (lp.gravity >= 0 && Gravity.horizontal(lp.gravity) == 2)
            let ws: Int
            if lp.width > 0 { ws = MeasureSpec.makeMeasureSpec(lp.width, MeasureSpec.EXACTLY) }
            else if fill { ws = MeasureSpec.makeMeasureSpec(max(0, cellW), MeasureSpec.EXACTLY) }
            else { ws = MeasureSpec.makeMeasureSpec(max(0, cellW), MeasureSpec.AT_MOST) }
            let hs = lp.height >= 0 ? MeasureSpec.makeMeasureSpec(lp.height, MeasureSpec.EXACTLY)
                : MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
            c.view.measure(ws, hs)
            if c.rowSpan == 1 { rowH[c.row] = max(rowH[c.row], c.view.measuredHeight + lp.topMargin + lp.bottomMargin) }
        }
        colX = [paddingLeft]
        for w in colW { colX.append(colX.last! + w) }
        rowY = [paddingTop]
        for h in rowH { rowY.append(rowY.last! + h) }
        let totalW = colX.last! + paddingRight
        let totalH = rowY.last! + paddingBottom
        setMeasuredDimension(View.resolveSize(max(totalW, suggestedMinimumWidth), widthSpec),
                             View.resolveSize(max(totalH, suggestedMinimumHeight), heightSpec))
    }

    override func onLayout(_ changed: Bool, _ l: Int, _ t: Int, _ r: Int, _ b: Int) {
        for c in cells {
            let lp = lpOf(c.view)
            let x0 = colX[c.col] + lp.leftMargin, x1 = colX[c.col + c.span] - lp.rightMargin
            let y0 = rowY[c.row] + lp.topMargin, y1 = rowY[min(rowY.count - 1, c.row + c.rowSpan)] - lp.bottomMargin
            let w = c.view.measuredWidth, h = c.view.measuredHeight
            let g = lp.gravity >= 0 ? lp.gravity : (lp.columnSpec.alignment?.g ?? Gravity.START)
            var x = x0
            switch Gravity.horizontal(g) { case 0: x = x0 + (x1 - x0 - w) / 2; case 1: x = x1 - w; default: break }
            var y = y0
            let vg = lp.gravity >= 0 ? lp.gravity : (lp.rowSpec.alignment?.g ?? Gravity.TOP)
            switch Gravity.vertical(vg) { case 0: y = y0 + (y1 - y0 - h) / 2; case 1: y = y1 - h; default: break }
            c.view.layout(x, y, x + w, y + h)
        }
    }
}
