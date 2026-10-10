import UIKit

// TextView · Button · ImageView · EditText · ProgressBar · SeekBar · 스위치.
// 글자는 안쪽 UILabel 이 그리고, 크기는 안드로이드 TextView 처럼 잰다.

enum TypedValue {
    static let COMPLEX_UNIT_PX = 0, COMPLEX_UNIT_DIP = 1, COMPLEX_UNIT_SP = 2, COMPLEX_UNIT_PT = 3
    static func applyDimension(_ unit: Int, _ value: Float, _ metrics: DisplayMetrics) -> Float { value }
}

enum TextUtils {
    enum TruncateAt { case START, MIDDLE, END, MARQUEE }
    static func isEmpty(_ s: String?) -> Bool { s?.isEmpty ?? true }
}

enum InputType {
    static let TYPE_CLASS_TEXT = 1, TYPE_CLASS_NUMBER = 2, TYPE_CLASS_PHONE = 3
    static let TYPE_NUMBER_VARIATION_PASSWORD = 0x10, TYPE_TEXT_VARIATION_PASSWORD = 0x80
    static let TYPE_TEXT_VARIATION_VISIBLE_PASSWORD = 0x90, TYPE_TEXT_FLAG_NO_SUGGESTIONS = 0x80000
    static let TYPE_NUMBER_FLAG_DECIMAL = 0x2000, TYPE_NUMBER_FLAG_SIGNED = 0x1000
    static let TYPE_TEXT_FLAG_CAP_CHARACTERS = 0x1000
}

enum EditorInfo { static let IME_ACTION_DONE = 6, IME_ACTION_NEXT = 5, IME_ACTION_GO = 2, IME_ACTION_SEND = 4 }

class MovementMethod {}
final class ScrollingMovementMethod: MovementMethod {
    static func getInstance() -> ScrollingMovementMethod { ScrollingMovementMethod() }
}
final class LinkMovementMethod: MovementMethod {
    static func getInstance() -> LinkMovementMethod { LinkMovementMethod() }
}

/// 테마(Theme.Piyak)의 기본값 — 모든 글자는 sans-serif-medium, 갈색
enum DroidTheme {
    static var textColor: Int = Color.parseColor("#4E342E")
    static var fontFamily = "sans-serif-medium"
    static var colorPrimary: Int = Color.parseColor("#FFD54F")
    static var colorOnPrimary: Int = Color.parseColor("#4E342E")
    static var windowBackground: Int = Color.parseColor("#FFF8E7")
    static var hintColor: Int = 0x61000000
}

// MARK: - TextView

class TextView: View {
    let label = UILabel()
    private let scrollBox = UIScrollView()

    var text: String = "" { didSet { if oldValue != text { textChanged() } } }
    func setText(_ s: String) { text = s }
    func setText(_ id: Int) { text = Res.shared.string(id) }
    func getText() -> String { text }

    /// 안드로이드 textSize(sp). 이 앱에서는 pt 와 같다.
    var textSize: Float = 14 { didSet { if oldValue != textSize { styleChanged() } } }
    func setTextSize(_ unit: Int, _ size: Float) { textSize = size }
    func setTextSize(_ size: Float) { textSize = size }

    private(set) var currentTextColor: Int = DroidTheme.textColor
    func setTextColor(_ c: Int) { currentTextColor = c; styleChanged(relayout: false) }
    func setTextColor(_ l: ColorStateList?) { if let l { setTextColor(l.defaultColor) } }
    var textColors: ColorStateList { ColorStateList(currentTextColor) }

    var typeface: Typeface? = Typeface(family: DroidTheme.fontFamily, style: Typeface.NORMAL) { didSet { styleChanged() } }
    func setTypeface(_ tf: Typeface?) { typeface = tf }
    func setTypeface(_ tf: Typeface?, _ style: Int) {
        typeface = Typeface(family: tf?.family ?? DroidTheme.fontFamily, style: style)
    }
    var paintFlags: Int = 0 { didSet { styleChanged(relayout: false) } }

    var gravity: Int = Gravity.TOP | Gravity.START { didSet { styleChanged() } }
    func setGravity(_ g: Int) { gravity = g }

    var maxLines: Int = Int.max { didSet { styleChanged() } }
    var minLines: Int = 0 { didSet { requestLayout() } }
    func setLines(_ n: Int) { minLines = n; maxLines = n }
    func setMaxLines(_ n: Int) { maxLines = n }
    func setMinLines(_ n: Int) { minLines = n }
    var isSingleLine: Bool { get { maxLines == 1 } set { maxLines = newValue ? 1 : Int.max } }
    func setSingleLine() { isSingleLine = true }
    func setSingleLine(_ b: Bool) { isSingleLine = b }
    var ellipsize: TextUtils.TruncateAt? = nil { didSet { styleChanged() } }
    var maxWidth: Int = Int.max { didSet { requestLayout() } }
    var minWidth: Int { get { minimumWidth } set { minimumWidth = newValue } }
    var minHeight: Int { get { minimumHeight } set { minimumHeight = newValue } }
    var maxHeight: Int = Int.max
    var maxEms = 0

    private(set) var lineSpacingMultiplier: Float = 1
    private(set) var lineSpacingExtra: Float = 0
    func setLineSpacing(_ add: Float, _ mult: Float) { lineSpacingExtra = add; lineSpacingMultiplier = mult; styleChanged() }
    var letterSpacing: Float = 0 { didSet { styleChanged() } }
    var includeFontPadding = true
    var breakStrategy = 0
    var hyphenationFrequency = 0
    var isAllCaps = false { didSet { styleChanged() } }
    func setAllCaps(_ b: Bool) { isAllCaps = b }
    var movementMethod: MovementMethod? { didSet { styleChanged() } }
    var hint: String = "" { didSet { styleChanged() } }
    func setHint(_ id: Int) { hint = Res.shared.string(id) }
    var hintTextColor: Int = DroidTheme.hintColor
    func setHintTextColor(_ c: Int) { hintTextColor = c; styleChanged(relayout: false) }
    var shadowRadius: Float = 0, shadowDx: Float = 0, shadowDy: Float = 0, shadowColor: Int = 0
    func setShadowLayer(_ r: Float, _ dx: Float, _ dy: Float, _ c: Int) {
        shadowRadius = r; shadowDx = dx; shadowDy = dy; shadowColor = c; styleChanged(relayout: false)
    }

    // 글자 크기 자동 맞춤 (app:autoSizeTextType="uniform")
    private(set) var autoSizeMin: Float = 0
    private(set) var autoSizeMax: Float = 0
    private var autoSizeStep: Float = 1
    var isAutoSize: Bool { autoSizeMax > 0 }
    func setAutoSizeTextTypeUniformWithConfiguration(_ min: Int, _ max: Int, _ step: Int, _ unit: Int) {
        autoSizeMin = Float(min); autoSizeMax = Float(max); autoSizeStep = Float(Swift.max(1, step)); requestLayout()
    }
    func setAutoSizeTextTypeWithDefaults(_ type: Int) {
        if type == 0 { autoSizeMax = 0 } else { autoSizeMin = 12; autoSizeMax = 112; autoSizeStep = 1 }
        requestLayout()
    }
    private var autoSizedTextSize: Float? = nil
    var effectiveTextSize: Float { autoSizedTextSize ?? textSize }

    // 글자 옆 그림 (drawableStart 등)
    private(set) var drawableStart: Drawable?
    private(set) var drawableTop: Drawable?
    private(set) var drawableEnd: Drawable?
    private(set) var drawableBottom: Drawable?
    var compoundDrawablePadding: Int = 0 { didSet { requestLayout() } }
    var compoundDrawableTint: Int? = nil
    func setCompoundDrawablesRelativeWithIntrinsicBounds(_ start: Int, _ top: Int, _ end: Int, _ bottom: Int) {
        setCompoundDrawablesRelativeWithIntrinsicBounds(start == 0 ? nil : Res.shared.drawable(start), top == 0 ? nil : Res.shared.drawable(top),
                                                        end == 0 ? nil : Res.shared.drawable(end), bottom == 0 ? nil : Res.shared.drawable(bottom))
    }
    func setCompoundDrawablesRelativeWithIntrinsicBounds(_ start: Drawable?, _ top: Drawable?, _ end: Drawable?, _ bottom: Drawable?) {
        drawableStart = start; drawableTop = top; drawableEnd = end; drawableBottom = bottom
        requestLayout(); invalidate()
    }
    func setCompoundDrawablesWithIntrinsicBounds(_ l: Int, _ t: Int, _ r: Int, _ b: Int) { setCompoundDrawablesRelativeWithIntrinsicBounds(l, t, r, b) }
    func setCompoundDrawablesWithIntrinsicBounds(_ l: Drawable?, _ t: Drawable?, _ r: Drawable?, _ b: Drawable?) {
        setCompoundDrawablesRelativeWithIntrinsicBounds(l, t, r, b)
    }
    func setCompoundDrawables(_ l: Drawable?, _ t: Drawable?, _ r: Drawable?, _ b: Drawable?) {
        setCompoundDrawablesRelativeWithIntrinsicBounds(l, t, r, b)
    }
    var compoundDrawables: [Drawable?] { [drawableStart, drawableTop, drawableEnd, drawableBottom] }

    private var textWatchers: [TextWatcher] = []
    func addTextChangedListener(_ w: TextWatcher) { textWatchers.append(w) }

    override init(_ context: Context, _ attrs: AttributeSet? = nil) {
        super.init(context, attrs)
        label.isUserInteractionEnabled = false
        label.backgroundColor = .clear
        label.lineBreakStrategy = .standard
        scrollBox.isHidden = true
        scrollBox.showsHorizontalScrollIndicator = false
        addSubview(scrollBox)
        addSubview(label)
        styleChanged()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func textChanged() {
        textWatchers.forEach { $0.afterTextChanged(text) }
        styleChanged()
    }

    func styleChanged(relayout: Bool = true) {
        applyLabel()
        if relayout { requestLayout() }
        invalidate()
    }

    var displayText: String { isAllCaps ? text.uppercased() : text }

    func font(size: Float) -> UIFont { (typeface ?? .DEFAULT).font(size: CGFloat(size)) }

    func attributed(_ s: String, size: Float, color: Int) -> NSAttributedString {
        let f = font(size: size)
        let ps = NSMutableParagraphStyle()
        ps.lineBreakStrategy = .standard
        ps.lineBreakMode = .byWordWrapping
        if lineSpacingMultiplier != 1 { ps.lineHeightMultiple = CGFloat(lineSpacingMultiplier) }
        if lineSpacingExtra != 0 { ps.lineSpacing = CGFloat(lineSpacingExtra) }
        switch Gravity.horizontal(gravity) {
        case 0: ps.alignment = .center
        case 1: ps.alignment = .right
        default: ps.alignment = .left
        }
        var a: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: Color.ui(color), .paragraphStyle: ps]
        if letterSpacing != 0 { a[.kern] = CGFloat(letterSpacing * size) }
        if paintFlags & Paint.STRIKE_THRU_TEXT_FLAG != 0 { a[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if paintFlags & Paint.UNDERLINE_TEXT_FLAG != 0 { a[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if shadowRadius > 0 {
            let sh = NSShadow()
            sh.shadowBlurRadius = CGFloat(shadowRadius); sh.shadowOffset = CGSize(width: CGFloat(shadowDx), height: CGFloat(shadowDy))
            sh.shadowColor = Color.ui(shadowColor)
            a[.shadow] = sh
        }
        return NSAttributedString(string: s, attributes: a)
    }

    private func applyLabel() {
        let showHint = text.isEmpty && !hint.isEmpty
        let s = showHint ? hint : displayText
        let c = showHint ? hintTextColor : currentTextColor
        label.attributedText = attributed(s, size: effectiveTextSize, color: isEnabled ? c : (c & 0x00FFFFFF) | 0x61000000)
        label.numberOfLines = movementMethod != nil ? 0 : (maxLines == Int.max ? 0 : maxLines)
        label.lineBreakMode = ellipsize == .END || ellipsize == .MARQUEE ? .byTruncatingTail
            : ellipsize == .START ? .byTruncatingHead : ellipsize == .MIDDLE ? .byTruncatingMiddle : .byWordWrapping
        if maxLines == 1 && ellipsize == nil { label.lineBreakMode = .byClipping }
    }

    override var isEnabled: Bool { didSet { applyLabel() } }

    // MARK: 재기

    /// 글자 상자 크기 (여백 제외) — width 안에서 줄을 바꾼다
    func textSize(for width: CGFloat, size: Float? = nil, lines: Int? = nil) -> CGSize {
        let s = text.isEmpty && !hint.isEmpty ? hint : displayText
        let str = attributed(s.isEmpty ? " " : s, size: size ?? effectiveTextSize, color: currentTextColor)
        let maxL = lines ?? (maxLines == Int.max ? 0 : maxLines)
        let r = str.boundingRect(with: CGSize(width: max(1, width), height: .greatestFiniteMagnitude),
                                 options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        var h = ceil(r.height)
        var w = ceil(r.width)
        let lineH = lineHeight(size: size ?? effectiveTextSize)
        if maxL > 0 {
            let limit = ceil(lineH * CGFloat(maxL))
            if h > limit + 1 { h = limit }
        }
        if minLines > 0 { h = max(h, ceil(lineH * CGFloat(minLines))) }
        if s.isEmpty { w = 0 }
        return CGSize(width: w, height: h)
    }

    func lineHeight(size: Float) -> CGFloat {
        let f = font(size: size)
        return f.lineHeight * CGFloat(lineSpacingMultiplier) + CGFloat(lineSpacingExtra)
    }

    /// 한 줄로 썼을 때 폭
    func singleLineWidth(size: Float) -> CGFloat {
        let s = text.isEmpty && !hint.isEmpty ? hint : displayText
        var w: CGFloat = 0
        for line in s.components(separatedBy: "\n") {
            w = max(w, attributed(line, size: size, color: 0).size().width)
        }
        return ceil(w)
    }

    private var drawablesWidth: Int {
        var w = 0
        if let d = drawableStart { w += max(0, d.intrinsicWidth) + compoundDrawablePadding }
        if let d = drawableEnd { w += max(0, d.intrinsicWidth) + compoundDrawablePadding }
        return w
    }
    private var drawablesHeight: Int {
        var h = 0
        if let d = drawableTop { h += max(0, d.intrinsicHeight) + compoundDrawablePadding }
        if let d = drawableBottom { h += max(0, d.intrinsicHeight) + compoundDrawablePadding }
        return h
    }
    private var sideDrawableHeight: Int {
        max(drawableStart?.intrinsicHeight ?? 0, drawableEnd?.intrinsicHeight ?? 0)
    }

    override func onMeasure(_ widthSpec: Int, _ heightSpec: Int) {
        let wMode = MeasureSpec.getMode(widthSpec), wSize = MeasureSpec.getSize(widthSpec)
        let hMode = MeasureSpec.getMode(heightSpec), hSize = MeasureSpec.getSize(heightSpec)
        let padH = paddingLeft + paddingRight + drawablesWidth
        let padV = paddingTop + paddingBottom + drawablesHeight

        var width: Int
        if wMode == MeasureSpec.EXACTLY {
            width = wSize
        } else {
            let base = isAutoSize ? autoSizeMax : textSize
            var desired = Int(singleLineWidth(size: base)) + padH
            if let d = drawableTop { desired = max(desired, d.intrinsicWidth + paddingLeft + paddingRight) }
            desired = max(desired, suggestedMinimumWidth)
            desired = min(desired, maxWidth == Int.max ? desired : maxWidth)
            width = wMode == MeasureSpec.AT_MOST ? min(desired, wSize) : desired
        }
        let contentW = CGFloat(max(1, width - padH))

        // 자동 맞춤: 가장 큰 크기부터 줄여 가며 폭(과 줄 수·높이)에 들어가는지 본다
        if isAutoSize {
            var size = autoSizeMax
            let limitLines = maxLines == Int.max ? 0 : maxLines
            let availH: CGFloat? = hMode == MeasureSpec.EXACTLY ? CGFloat(hSize - padV) : nil
            while size > autoSizeMin {
                let fits: Bool
                if limitLines == 1 { fits = singleLineWidth(size: size) <= contentW }
                else {
                    let full = textSize(for: contentW, size: size, lines: 0)
                    let lh = lineHeight(size: size)
                    let linesUsed = Int((full.height / lh).rounded())
                    fits = (limitLines == 0 || linesUsed <= limitLines) && (availH == nil || full.height <= availH! + 0.5)
                        && longestWordFits(size: size, width: contentW)
                }
                if fits { break }
                size -= autoSizeStep
            }
            let newSize = max(autoSizeMin, size)
            if autoSizedTextSize != newSize { autoSizedTextSize = newSize; applyLabel() }
        }

        let ts = textSize(for: contentW)
        var height: Int
        if hMode == MeasureSpec.EXACTLY { height = hSize } else {
            var desired = Int(ceil(ts.height)) + padV
            desired = max(desired, sideDrawableHeight + paddingTop + paddingBottom)
            desired = max(desired, suggestedMinimumHeight)
            if maxHeight != Int.max { desired = min(desired, maxHeight) }
            height = hMode == MeasureSpec.AT_MOST ? min(desired, hSize) : desired
        }
        if wMode != MeasureSpec.EXACTLY && ts.width > 0 {
            // 줄이 바뀌면 실제 쓰인 폭이 더 좁을 수 있지만 안드로이드처럼 가장 긴 줄 폭을 쓴다
        }
        setMeasuredDimension(width, height)
    }

    private func longestWordFits(size: Float, width: CGFloat) -> Bool {
        let words = displayText.split(whereSeparator: { $0 == " " || $0 == "\n" })
        for w in words where attributed(String(w), size: size, color: 0).size().width > width + 0.5 { return false }
        return true
    }

    override func onLayout(_ changed: Bool, _ l: Int, _ t: Int, _ r: Int, _ b: Int) {
        layoutLabel()
    }

    /// 글자 상자 자리 (gravity 에 따라 위·가운데·아래)
    var textRect: CGRect {
        var x = CGFloat(paddingLeft), y = CGFloat(paddingTop)
        var w = CGFloat(width - paddingLeft - paddingRight), h = CGFloat(height - paddingTop - paddingBottom)
        if let d = drawableStart { let dw = CGFloat(max(0, d.intrinsicWidth) + compoundDrawablePadding); x += dw; w -= dw }
        if let d = drawableEnd { w -= CGFloat(max(0, d.intrinsicWidth) + compoundDrawablePadding) }
        if let d = drawableTop { let dh = CGFloat(max(0, d.intrinsicHeight) + compoundDrawablePadding); y += dh; h -= dh }
        if let d = drawableBottom { h -= CGFloat(max(0, d.intrinsicHeight) + compoundDrawablePadding) }
        return CGRect(x: x, y: y, width: max(0, w), height: max(0, h))
    }

    private func layoutLabel() {
        let box = textRect
        var ts = textSize(for: box.width)
        ts.height = min(ts.height, box.height)
        let vy: CGFloat
        switch Gravity.vertical(gravity) {
        case 0: vy = box.minY + (box.height - ts.height) / 2
        case 1: vy = box.maxY - ts.height
        default: vy = box.minY
        }
        // 글자가 옆 그림과 같이 가운데로 모이도록 (drawableStart + gravity center)
        var lx = box.minX, lw = box.width
        if (drawableStart != nil || drawableEnd != nil) && Gravity.horizontal(gravity) == 0 {
            let used = min(box.width, singleLineWidth(size: effectiveTextSize))
            lx = box.minX + (box.width - used) / 2; lw = used
        }
        if movementMethod != nil {
            scrollBox.isHidden = false
            scrollBox.frame = CGRect(x: lx, y: vy, width: lw, height: ts.height)
            let full = textSize(for: lw, lines: 0)
            if label.superview !== scrollBox { scrollBox.addSubview(label) }
            label.frame = CGRect(x: 0, y: 0, width: lw, height: full.height)
            scrollBox.contentSize = CGSize(width: lw, height: full.height)
            isUserInteractionEnabled = true
        } else {
            if label.superview !== self { addSubview(label) }
            scrollBox.isHidden = true
            label.frame = CGRect(x: lx, y: vy, width: lw, height: ts.height)
        }
    }

    /// 첫 줄 기준선 (LinearLayout 기준선 맞추기용)
    func getBaseline() -> Int {
        let f = font(size: effectiveTextSize)
        let box = textRect
        let ts = textSize(for: box.width)
        var top = box.minY
        if height > 0 {
            switch Gravity.vertical(gravity) {
            case 0: top = box.minY + (box.height - min(ts.height, box.height)) / 2
            case 1: top = box.maxY - min(ts.height, box.height)
            default: break
            }
        }
        let lineExtra = (lineHeight(size: effectiveTextSize) - f.lineHeight)
        return Int((top + f.ascender + max(0, lineExtra)).rounded())
    }

    var lineCount: Int {
        let lh = lineHeight(size: effectiveTextSize)
        return max(1, Int((textSize(for: textRect.width).height / lh).rounded()))
    }

    // MARK: 그리기 (옆 그림)

    override func onDraw(_ canvas: Canvas) {
        let box = textRect
        let ts = textSize(for: box.width)
        let tint = compoundDrawableTint
        func put(_ d: Drawable, _ x: CGFloat, _ y: CGFloat) {
            let w = CGFloat(max(0, d.intrinsicWidth)), h = CGFloat(max(0, d.intrinsicHeight))
            d.setBounds(Int(x.rounded()), Int(y.rounded()), Int((x + w).rounded()), Int((y + h).rounded()))
            if let t = tint { d.tintColor = t }
            d.draw(canvas)
        }
        let textW = min(box.width, singleLineWidth(size: effectiveTextSize))
        if let d = drawableStart {
            let w = CGFloat(max(0, d.intrinsicWidth)), h = CGFloat(max(0, d.intrinsicHeight))
            var x = CGFloat(paddingLeft)
            if Gravity.horizontal(gravity) == 0 { x = box.minX + (box.width - textW) / 2 - w - CGFloat(compoundDrawablePadding) }
            let cy = Gravity.vertical(gravity) == -1 ? box.minY + min(ts.height, box.height) / 2 : CGFloat(height) / 2
            _ = h
            put(d, x, cy - CGFloat(max(0, d.intrinsicHeight)) / 2)
        }
        if let d = drawableEnd {
            let w = CGFloat(max(0, d.intrinsicWidth))
            var x = CGFloat(width - paddingRight) - w
            if Gravity.horizontal(gravity) == 0 { x = box.minX + (box.width + textW) / 2 + CGFloat(compoundDrawablePadding) }
            put(d, x, CGFloat(height) / 2 - CGFloat(max(0, d.intrinsicHeight)) / 2)
        }
        if let d = drawableTop {
            let w = CGFloat(max(0, d.intrinsicWidth))
            put(d, CGFloat(paddingLeft) + (CGFloat(width - paddingLeft - paddingRight) - w) / 2, CGFloat(paddingTop))
        }
        if let d = drawableBottom {
            let w = CGFloat(max(0, d.intrinsicWidth)), h = CGFloat(max(0, d.intrinsicHeight))
            put(d, CGFloat(paddingLeft) + (CGFloat(width - paddingLeft - paddingRight) - w) / 2, CGFloat(height - paddingBottom) - h)
        }
    }

    /// 코틀린 TextView.paint — 글자 크기를 재는 데 쓴다
    var paint: Paint {
        let p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.textSize = effectiveTextSize
        p.typeface = typeface
        p.color = currentTextColor
        return p
    }
}

protocol TextWatcher {
    func afterTextChanged(_ s: String)
}
/// 코틀린 `addTextChangedListener(object : TextWatcher { ... })` 를 클로저로
struct SimpleTextWatcher: TextWatcher {
    let after: (String) -> Void
    init(_ after: @escaping (String) -> Void) { self.after = after }
    func afterTextChanged(_ s: String) { after(s) }
}

// MARK: - Button

/// 안드로이드 Button.
///  - XML <Button> 은 Material3 버튼(알약 모양, 노란 배경)
///  - 코드의 Button(ctx)·<AppCompatButton> 은 AppCompat 버튼(살짝 둥근 네모, 대문자)
class Button: TextView {
    enum Style { case material, appcompat }
    let style: Style

    init(_ context: Context, _ attrs: AttributeSet? = nil, style: Style) {
        self.style = style
        super.init(context, attrs)
        gravity = Gravity.CENTER
        isClickable = true
        isFocusable = true
        textSize = 14
        switch style {
        case .material:
            setTextColor(DroidTheme.colorOnPrimary)
            minimumHeight = 48
            minimumWidth = 88
            setPadding(24, 6 + 10, 24, 6 + 10)
            background = ButtonBackground(insetV: 6, radius: -1, color: DroidTheme.colorPrimary)
            isAllCaps = false
        case .appcompat:
            setTextColor(Color.parseColor("#DE000000"))
            minimumHeight = 48
            minimumWidth = 88
            setPadding(8 + 4, 4 + 6, 8 + 4, 4 + 6)
            background = ButtonBackground(insetH: 4, insetV: 6, radius: 2, color: Color.parseColor("#FFD6D7D7"))
            isAllCaps = true
            elevation = 2
        }
    }
    override convenience init(_ context: Context, _ attrs: AttributeSet? = nil) { self.init(context, attrs, style: .appcompat) }
    required init?(coder: NSCoder) { fatalError() }

    override var background: Drawable? {
        didSet { if !(background is ButtonBackground) { elevation = 0 } }
    }

    var cornerRadius: Int {
        get { Int((background as? ButtonBackground)?.radius ?? 0) }
        set { (background as? ButtonBackground)?.radius = Float(newValue); invalidate() }
    }
    var stateListAnimator: Any? {
        get { nil }
        set { if newValue == nil { elevation = 0 } }
    }
    var insetTop: Int {
        get { Int((background as? ButtonBackground)?.insetV ?? 0) }
        set { (background as? ButtonBackground)?.insetV = Float(newValue); invalidate() }
    }
    var insetBottom: Int { get { insetTop } set { insetTop = newValue } }
    var strokeWidth: Int {
        get { Int((background as? ButtonBackground)?.strokeWidth ?? 0) }
        set { (background as? ButtonBackground)?.strokeWidth = Float(newValue); invalidate() }
    }
    var strokeColor: ColorStateList? {
        get { nil }
        set { (background as? ButtonBackground)?.strokeColor = newValue?.defaultColor ?? 0; invalidate() }
    }
    var iconTint: ColorStateList?
    var rippleColor: ColorStateList?

    override func drawBackground(_ canvas: Canvas) {
        guard let bg = background else { return }
        bg.setBounds(0, 0, width, height)
        let old = bg.tintColor
        if let t = backgroundTintList { bg.tintColor = t.defaultColor }
        if let b = bg as? ButtonBackground { b.enabled = isEnabled }
        bg.draw(canvas)
        bg.tintColor = old
        // 눌림: 살짝 어둡게 (안드로이드 물결 대신)
        if isPressed {
            let p = Paint(Paint.ANTI_ALIAS_FLAG)
            p.color = 0x1F000000
            if let b = bg as? ButtonBackground {
                canvas.drawPath(b.shapePath(width, height), p)
            } else if let g = bg as? GradientDrawable {
                canvas.ctx.addPath(g.path(in: CGRect(x: 0, y: 0, width: width, height: height)))
                canvas.ctx.setFillColor(Color.cg(0x1F000000)); canvas.ctx.fillPath()
            }
        }
    }
    override func refreshDrawableState() { super.refreshDrawableState(); applyEnabledLook() }
    private func applyEnabledLook() { label.alpha = isEnabled ? 1 : 0.38 / 0.87 * 0.87 }
}

/// 버튼 기본 배경: 위아래(와 옆) 여백 안에 둥근 네모. 색은 backgroundTint 로 바뀐다.
final class ButtonBackground: Drawable {
    var insetH: Float, insetV: Float
    var radius: Float           // -1 = 알약
    var color: Int
    var strokeWidth: Float = 0
    var strokeColor: Int = 0
    var enabled = true
    init(insetH: Float = 0, insetV: Float, radius: Float, color: Int) {
        self.insetH = insetH; self.insetV = insetV; self.radius = radius; self.color = color
    }
    func shapePath(_ w: Int, _ h: Int) -> Path {
        let r = RectF(insetH, insetV, Float(w) - insetH, Float(h) - insetV)
        let rad = radius < 0 ? r.height() / 2 : radius
        let p = Path(); p.addRoundRect(r, rad, rad, .CW)
        return p
    }
    override func draw(_ canvas: Canvas) {
        let p = Paint(Paint.ANTI_ALIAS_FLAG)
        var c = tintColor ?? color
        if !enabled { c = (c & 0x00FFFFFF) | (0x1F << 24); c = Color.blendARGB(c, 0x1F1D1B20, 0.5) }
        p.color = c
        p.alpha = Color.alpha(c) * alpha / 255
        canvas.drawPath(shapePath(bounds.width(), bounds.height()), p)
        if strokeWidth > 0 {
            let s = Paint(Paint.ANTI_ALIAS_FLAG); s.style = .STROKE; s.strokeWidth = strokeWidth; s.color = strokeColor
            canvas.drawPath(shapePath(bounds.width(), bounds.height()), s)
        }
    }
}

typealias AppCompatButton = Button
typealias MaterialButton = Button
typealias AppCompatTextView = TextView

// MARK: - ImageView

class ImageView: View {
    enum ScaleType { case FIT_CENTER, CENTER_CROP, CENTER_INSIDE, FIT_XY, CENTER, FIT_START, FIT_END, MATRIX }

    private(set) var drawable: Drawable?
    var scaleType: ScaleType = .FIT_CENTER { didSet { invalidate() } }
    var adjustViewBounds = false
    var imageTintList: ColorStateList? { didSet { invalidate() } }
    var imageAlpha: Int = 255 { didSet { invalidate() } }
    var maxWidth = Int.max, maxHeight = Int.max

    func setImageResource(_ id: Int) { setImageDrawable(id == 0 ? nil : Res.shared.drawable(id)) }
    func setImageDrawable(_ d: Drawable?) {
        (drawable as? AnimationDrawable)?.callback = nil
        drawable = d
        d?.callback = self
        requestLayout(); invalidate()
    }
    func setImageBitmap(_ b: Bitmap?) {
        guard let b, let cg = b.cgImage else { setImageDrawable(nil); return }
        setImageDrawable(BitmapDrawable(UIImage(cgImage: cg, scale: UIScreen.main.scale, orientation: .up)))
    }
    func setColorFilter(_ c: Int) { imageTintList = ColorStateList(c) }
    func clearColorFilter() { imageTintList = nil }
    func getDrawable() -> Drawable? { drawable }

    override func onMeasure(_ widthSpec: Int, _ heightSpec: Int) {
        let dw = max(0, drawable?.intrinsicWidth ?? 0), dh = max(0, drawable?.intrinsicHeight ?? 0)
        var w = dw + paddingLeft + paddingRight
        var h = dh + paddingTop + paddingBottom
        w = max(w, suggestedMinimumWidth); h = max(h, suggestedMinimumHeight)
        var mw = View.resolveSize(w, widthSpec)
        var mh = View.resolveSize(h, heightSpec)
        if adjustViewBounds && dw > 0 && dh > 0 {
            let ratio = CGFloat(dw) / CGFloat(dh)
            if MeasureSpec.getMode(widthSpec) == MeasureSpec.EXACTLY && MeasureSpec.getMode(heightSpec) != MeasureSpec.EXACTLY {
                mh = View.resolveSize(Int(CGFloat(mw - paddingLeft - paddingRight) / ratio) + paddingTop + paddingBottom, heightSpec)
            } else if MeasureSpec.getMode(heightSpec) == MeasureSpec.EXACTLY && MeasureSpec.getMode(widthSpec) != MeasureSpec.EXACTLY {
                mw = View.resolveSize(Int(CGFloat(mh - paddingTop - paddingBottom) * ratio) + paddingLeft + paddingRight, widthSpec)
            }
        }
        setMeasuredDimension(mw, mh)
    }

    override func onDraw(_ canvas: Canvas) {
        guard let d = drawable else { return }
        let box = CGRect(x: paddingLeft, y: paddingTop, width: width - paddingLeft - paddingRight, height: height - paddingTop - paddingBottom)
        guard box.width > 0, box.height > 0 else { return }
        var dw = CGFloat(d.intrinsicWidth), dh = CGFloat(d.intrinsicHeight)
        var r = box
        if dw <= 0 || dh <= 0 || scaleType == .FIT_XY { dw = box.width; dh = box.height } else {
            switch scaleType {
            case .FIT_CENTER, .FIT_START, .FIT_END:
                let s = min(box.width / dw, box.height / dh)
                let w = dw * s, h = dh * s
                let x = scaleType == .FIT_START ? box.minX : scaleType == .FIT_END ? box.maxX - w : box.midX - w / 2
                let y = scaleType == .FIT_START ? box.minY : scaleType == .FIT_END ? box.maxY - h : box.midY - h / 2
                r = CGRect(x: x, y: y, width: w, height: h)
            case .CENTER_CROP:
                let s = max(box.width / dw, box.height / dh)
                r = CGRect(x: box.midX - dw * s / 2, y: box.midY - dh * s / 2, width: dw * s, height: dh * s)
            case .CENTER_INSIDE:
                let s = min(1, min(box.width / dw, box.height / dh))
                r = CGRect(x: box.midX - dw * s / 2, y: box.midY - dh * s / 2, width: dw * s, height: dh * s)
            case .CENTER:
                r = CGRect(x: box.midX - dw / 2, y: box.midY - dh / 2, width: dw, height: dh)
            default: break
            }
        }
        canvas.save()
        canvas.ctx.clip(to: box)
        d.setBounds(Int(r.minX.rounded()), Int(r.minY.rounded()), Int(r.maxX.rounded()), Int(r.maxY.rounded()))
        let oldTint = d.tintColor, oldAlpha = d.alpha
        if let t = imageTintList { d.tintColor = t.defaultColor }
        d.alpha = imageAlpha
        d.draw(canvas)
        d.tintColor = oldTint; d.alpha = oldAlpha
        canvas.restore()
    }
}
typealias AppCompatImageView = ImageView

// MARK: - EditText

class EditText: TextView, UITextFieldDelegate {
    let field = UITextField()
    var inputType: Int = InputType.TYPE_CLASS_TEXT { didSet { applyInputType() } }
    var imeOptions = 0
    private var onEditorAction: ((TextView, Int, Any?) -> Bool)?
    private var syncing = false

    override init(_ context: Context, _ attrs: AttributeSet? = nil) {
        super.init(context, attrs)
        label.isHidden = true
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.delegate = self
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.addTarget(self, action: #selector(changed), for: .editingChanged)
        addSubview(field)
        isClickable = true
        isFocusable = true
        setPadding(4, 10, 4, 10)
        applyField()
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func changed() {
        syncing = true
        text = field.text ?? ""
        syncing = false
    }

    override func styleChanged(relayout: Bool = true) {
        super.styleChanged(relayout: relayout)
        applyField()
    }

    private func applyField() {
        if !syncing && field.text != text { field.text = text }
        field.font = font(size: effectiveTextSize)
        field.textColor = Color.ui(currentTextColor)
        field.attributedPlaceholder = NSAttributedString(string: hint, attributes: [.foregroundColor: Color.ui(hintTextColor), .font: font(size: effectiveTextSize)])
        switch Gravity.horizontal(gravity) { case 0: field.textAlignment = .center; case 1: field.textAlignment = .right; default: field.textAlignment = .left }
        label.isHidden = true
    }

    private func applyInputType() {
        let cls = inputType & 0xF
        if cls == InputType.TYPE_CLASS_NUMBER {
            field.keyboardType = inputType & InputType.TYPE_NUMBER_FLAG_DECIMAL != 0 ? .decimalPad : .numberPad
        } else if cls == InputType.TYPE_CLASS_PHONE {
            field.keyboardType = .phonePad
        } else {
            field.keyboardType = inputType & 0xFF0 == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD ? .asciiCapable : .default
        }
        field.isSecureTextEntry = (cls == InputType.TYPE_CLASS_NUMBER && inputType & 0xFF0 == InputType.TYPE_NUMBER_VARIATION_PASSWORD)
            || (cls == InputType.TYPE_CLASS_TEXT && inputType & 0xFF0 == InputType.TYPE_TEXT_VARIATION_PASSWORD)
        field.returnKeyType = .done
    }

    override func onLayout(_ changed: Bool, _ l: Int, _ t: Int, _ r: Int, _ b: Int) {
        super.onLayout(changed, l, t, r, b)
        field.frame = textRect
        label.isHidden = true
    }

    override func onMeasure(_ widthSpec: Int, _ heightSpec: Int) {
        let keep = text
        if keep.isEmpty && hint.isEmpty { hint = " " }
        super.onMeasure(widthSpec, heightSpec)
        if hint == " " { hint = "" }
        // 한 줄 입력칸
        let h = Int(ceil(font(size: effectiveTextSize).lineHeight)) + paddingTop + paddingBottom
        if MeasureSpec.getMode(heightSpec) != MeasureSpec.EXACTLY {
            setMeasuredDimension(measuredWidth, max(max(h, suggestedMinimumHeight), 0))
        }
    }

    func setOnEditorActionListener(_ f: ((TextView, Int, Any?) -> Bool)?) { onEditorAction = f }
    func textFieldShouldReturn(_ tf: UITextField) -> Bool {
        if let f = onEditorAction, f(self, imeOptions != 0 ? imeOptions : EditorInfo.IME_ACTION_DONE, nil) { return false }
        tf.resignFirstResponder()
        return false
    }

    @discardableResult func requestFocus() -> Bool { field.becomeFirstResponder() }
    func clearFocus() { field.resignFirstResponder() }
    func setSelection(_ i: Int) {
        if let p = field.position(from: field.beginningOfDocument, offset: i) { field.selectedTextRange = field.textRange(from: p, to: p) }
    }
    var selectionStart: Int { field.selectedTextRange.map { field.offset(from: field.beginningOfDocument, to: $0.start) } ?? 0 }
    override var isEnabled: Bool { didSet { field.isEnabled = isEnabled } }
}
typealias AppCompatEditText = EditText

enum InputMethodManagerCompat {
    static func hide() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
}

// MARK: - ProgressBar / SeekBar

class ProgressBar: View {
    var max: Int = 100 { didSet { invalidate() } }
    var min: Int = 0
    var progress: Int = 0 { didSet { if oldValue != progress { invalidate(); progressChanged(fromUser: false) } } }
    var secondaryProgress = 0
    var isIndeterminate = false
    var progressTintList: ColorStateList? { didSet { invalidate() } }
    var progressBackgroundTintList: ColorStateList? { didSet { invalidate() } }
    var progressDrawable: Drawable? { didSet { invalidate() } }
    func setProgress(_ p: Int, _ animate: Bool) { progress = p }
    func getProgress() -> Int { progress }
    func progressChanged(fromUser: Bool) {}

    override init(_ context: Context, _ attrs: AttributeSet? = nil) {
        super.init(context, attrs)
        minimumHeight = 4
    }
    required init?(coder: NSCoder) { fatalError() }

    override func onMeasure(_ widthSpec: Int, _ heightSpec: Int) {
        setMeasuredDimension(View.resolveSize(Swift.max(48, suggestedMinimumWidth), widthSpec),
                             View.resolveSize(Swift.max(4, suggestedMinimumHeight) + paddingTop + paddingBottom, heightSpec))
    }

    override func onDraw(_ canvas: Canvas) {
        let h = Float(height - paddingTop - paddingBottom)
        let barH = Swift.min(h, Swift.max(4, h))
        let top = Float(paddingTop) + (h - barH) / 2
        let rect = RectF(Float(paddingLeft), top, Float(width - paddingRight), top + barH)
        let r = barH / 2
        let p = Paint(Paint.ANTI_ALIAS_FLAG)
        if let pd = progressDrawable {
            pd.setBounds(Int(rect.left), Int(rect.top), Int(rect.right), Int(rect.bottom))
            pd.draw(canvas)
            return
        }
        // 안드로이드 기본 가로 막대: 배경은 같은 색 30%
        let fg = progressTintList?.defaultColor ?? DroidTheme.colorPrimary
        p.color = progressBackgroundTintList?.defaultColor ?? fg
        if progressBackgroundTintList == nil { p.alpha = 77 } else { p.alpha = Color.alpha(p.color) * 77 / 255 }
        canvas.drawRoundRect(rect, r, r, p)
        let frac = max > min ? Float(progress - min) / Float(max - min) : 0
        if frac > 0 {
            p.color = fg
            let pr = RectF(rect.left, rect.top, rect.left + rect.width() * Swift.min(1, frac), rect.bottom)
            canvas.drawRoundRect(pr, r, r, p)
        }
    }
}

class SeekBar: ProgressBar {
    protocol OnSeekBarChangeListener {
        func onProgressChanged(_ seekBar: SeekBar, _ progress: Int, _ fromUser: Bool)
        func onStartTrackingTouch(_ seekBar: SeekBar)
        func onStopTrackingTouch(_ seekBar: SeekBar)
    }
    private var listener: OnSeekBarChangeListener?
    private var fromUser = false
    var thumbTintList: ColorStateList?
    func setOnSeekBarChangeListener(_ l: OnSeekBarChangeListener?) { listener = l }

    override init(_ context: Context, _ attrs: AttributeSet? = nil) {
        super.init(context, attrs)
        setPadding(16, 0, 16, 0)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func onMeasure(_ widthSpec: Int, _ heightSpec: Int) {
        setMeasuredDimension(View.resolveSize(200, widthSpec), View.resolveSize(Swift.max(32, suggestedMinimumHeight), heightSpec))
    }
    override func progressChanged(fromUser: Bool) { listener?.onProgressChanged(self, progress, self.fromUser) }

    override func onDraw(_ canvas: Canvas) {
        let cy = Float(height) / 2
        let l = Float(paddingLeft), r = Float(width - paddingRight)
        let p = Paint(Paint.ANTI_ALIAS_FLAG)
        let fg = progressTintList?.defaultColor ?? DroidTheme.colorPrimary
        p.color = fg; p.alpha = 77
        canvas.drawRoundRect(RectF(l, cy - 2, r, cy + 2), 2, 2, p)
        let frac = max > min ? Float(progress - min) / Float(max - min) : 0
        let x = l + (r - l) * frac
        p.color = fg
        canvas.drawRoundRect(RectF(l, cy - 2, x, cy + 2), 2, 2, p)
        p.color = thumbTintList?.defaultColor ?? fg
        canvas.drawCircle(x, cy, 10, p)
    }

    override func onTouchEvent(_ event: MotionEvent) -> Bool {
        guard isEnabled else { return false }
        func update() {
            let l = Float(paddingLeft), r = Float(width - paddingRight)
            let f = Swift.max(0, Swift.min(1, (event.x - l) / Swift.max(1, r - l)))
            fromUser = true
            progress = min + Int((f * Float(max - min)).rounded())
            fromUser = false
        }
        switch event.action {
        case MotionEvent.ACTION_DOWN:
            requestDisallowInterceptTouchEvent(true)
            listener?.onStartTrackingTouch(self); update()
        case MotionEvent.ACTION_MOVE: update()
        case MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL:
            update(); listener?.onStopTrackingTouch(self)
        default: break
        }
        return true
    }
}

/// 코틀린 `object : SeekBar.OnSeekBarChangeListener { ... }` 를 클로저로
struct SeekBarListener: SeekBar.OnSeekBarChangeListener {
    var changed: (SeekBar, Int, Bool) -> Void = { _, _, _ in }
    var start: (SeekBar) -> Void = { _ in }
    var stop: (SeekBar) -> Void = { _ in }
    func onProgressChanged(_ s: SeekBar, _ p: Int, _ u: Bool) { changed(s, p, u) }
    func onStartTrackingTouch(_ s: SeekBar) { start(s) }
    func onStopTrackingTouch(_ s: SeekBar) { stop(s) }
}

// MARK: - 스위치·체크

class CompoundButton: Button {
    let toggle = UISwitch()
    private var onChecked: ((CompoundButton, Bool) -> Void)?
    var isChecked: Bool {
        get { toggle.isOn }
        set { if toggle.isOn != newValue { toggle.isOn = newValue; onChecked?(self, newValue) } }
    }
    func setOnCheckedChangeListener(_ f: ((CompoundButton, Bool) -> Void)?) { onChecked = f }
    func toggleState() { isChecked.toggle() }

    override init(_ context: Context, _ attrs: AttributeSet? = nil, style: Button.Style) {
        super.init(context, attrs, style: style)
        background = nil
        setPadding(0, 0, 0, 0)
        minimumWidth = 0
        minimumHeight = 48
        gravity = Gravity.START | Gravity.CENTER_VERTICAL
        isAllCaps = false
        setTextColor(DroidTheme.textColor)
        toggle.onTintColor = Color.ui(DroidTheme.colorPrimary)
        toggle.addTarget(self, action: #selector(flipped), for: .valueChanged)
        addSubview(toggle)
        setOnClickListener { [weak self] _ in self?.isChecked.toggle() }
    }
    convenience init(_ context: Context, _ attrs: AttributeSet? = nil) { self.init(context, attrs, style: .material) }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func flipped() { onChecked?(self, toggle.isOn) }

    override var textRect: CGRect {
        var r = super.textRect
        r.size.width -= toggle.intrinsicContentSize.width + 8
        return r
    }
    override func onMeasure(_ widthSpec: Int, _ heightSpec: Int) {
        super.onMeasure(widthSpec, heightSpec)
        if MeasureSpec.getMode(widthSpec) != MeasureSpec.EXACTLY {
            let w = measuredWidth + Int(toggle.intrinsicContentSize.width) + 8
            setMeasuredDimension(View.resolveSize(w, widthSpec), measuredHeight)
        }
    }
    override func onLayout(_ changed: Bool, _ l: Int, _ t: Int, _ r: Int, _ b: Int) {
        super.onLayout(changed, l, t, r, b)
        let s = toggle.intrinsicContentSize
        toggle.frame = CGRect(x: CGFloat(width - paddingRight) - s.width, y: (CGFloat(height) - s.height) / 2, width: s.width, height: s.height)
    }
    override var isEnabled: Bool { didSet { toggle.isEnabled = isEnabled } }
}
typealias SwitchMaterial = CompoundButton
typealias SwitchCompat = CompoundButton
typealias CheckBox = CompoundButton

/// 빈 칸
final class Space: View {}
