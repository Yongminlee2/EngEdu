import UIKit

// 안드로이드 View 의 아이폰판.
//
// 크기 재기(measure)·자리 잡기(layout)를 안드로이드와 같은 규칙(MeasureSpec)으로 직접 한다.
// UIKit 의 자동 배치는 쓰지 않는다 — 그래야 안드로이드 레이아웃 XML 과 화면 코드를 그대로 옮길 수 있다.
// 단위는 pt(=dp). 위치·크기는 안드로이드처럼 Int.

typealias AttributeSet = [String: String]

enum Gravity {
    static let NO_GRAVITY = 0
    static let CENTER_HORIZONTAL = 0x01
    static let LEFT = 0x03
    static let RIGHT = 0x05
    static let FILL_HORIZONTAL = 0x07
    static let CENTER_VERTICAL = 0x10
    static let TOP = 0x30
    static let BOTTOM = 0x50
    static let FILL_VERTICAL = 0x70
    static let CENTER = 0x11
    static let FILL = 0x77
    static let START = 0x0080_0003
    static let END = 0x0080_0005
    static let HORIZONTAL_GRAVITY_MASK = 0x07
    static let VERTICAL_GRAVITY_MASK = 0x70
    static let RELATIVE_HORIZONTAL_GRAVITY_MASK = 0x0080_0007

    /// 가로 정렬: -1 왼쪽, 0 가운데, 1 오른쪽, 2 채우기
    static func horizontal(_ g: Int) -> Int {
        switch g & HORIZONTAL_GRAVITY_MASK {
        case CENTER_HORIZONTAL: return 0
        case RIGHT: return 1
        case FILL_HORIZONTAL: return 2
        default: return -1
        }
    }
    static func vertical(_ g: Int) -> Int {
        switch g & VERTICAL_GRAVITY_MASK {
        case CENTER_VERTICAL: return 0
        case BOTTOM: return 1
        case FILL_VERTICAL: return 2
        default: return -1
        }
    }
    /// "center_vertical|end" 같은 XML 값
    static func parse(_ s: String) -> Int {
        var g = 0
        for p in s.split(separator: "|") {
            switch p.trimmingCharacters(in: .whitespaces) {
            case "center": g |= CENTER
            case "center_vertical": g |= CENTER_VERTICAL
            case "center_horizontal": g |= CENTER_HORIZONTAL
            case "top": g |= TOP
            case "bottom": g |= BOTTOM
            case "left": g |= LEFT
            case "right": g |= RIGHT
            case "start": g |= START
            case "end": g |= END
            case "fill": g |= FILL
            case "fill_vertical": g |= FILL_VERTICAL
            case "fill_horizontal": g |= FILL_HORIZONTAL
            default: break
            }
        }
        return g
    }
}

enum MeasureSpec {
    static let UNSPECIFIED = 0
    static let EXACTLY = 1 << 30
    static let AT_MOST = 2 << 30
    private static let MODE_MASK = 3 << 30

    static func makeMeasureSpec(_ size: Int, _ mode: Int) -> Int { (max(0, size) & ~MODE_MASK) | (mode & MODE_MASK) }
    static func getMode(_ spec: Int) -> Int { spec & MODE_MASK }
    static func getSize(_ spec: Int) -> Int { spec & ~MODE_MASK }
}

// MARK: - BaseLayoutParams

class BaseLayoutParams {
    static let MATCH_PARENT = -1
    static let FILL_PARENT = -1
    static let WRAP_CONTENT = -2

    var width: Int
    var height: Int
    init(_ width: Int, _ height: Int) { self.width = width; self.height = height }
    init(_ src: BaseLayoutParams) { width = src.width; height = src.height }
}

class DroidMarginLayoutParams: BaseLayoutParams {
    var leftMargin = 0, topMargin = 0, rightMargin = 0, bottomMargin = 0
    var marginStart: Int { get { leftMargin } set { leftMargin = newValue } }
    var marginEnd: Int { get { rightMargin } set { rightMargin = newValue } }

    override init(_ width: Int, _ height: Int) { super.init(width, height) }
    override init(_ src: BaseLayoutParams) {
        super.init(src)
        if let m = src as? DroidMarginLayoutParams {
            leftMargin = m.leftMargin; topMargin = m.topMargin; rightMargin = m.rightMargin; bottomMargin = m.bottomMargin
        }
    }
    func setMargins(_ l: Int, _ t: Int, _ r: Int, _ b: Int) { leftMargin = l; topMargin = t; rightMargin = r; bottomMargin = b }
    func setMarginStart(_ v: Int) { leftMargin = v }
    func setMarginEnd(_ v: Int) { rightMargin = v }
}

// MARK: - MotionEvent

final class MotionEvent {
    static let ACTION_DOWN = 0, ACTION_UP = 1, ACTION_MOVE = 2, ACTION_CANCEL = 3
    static let ACTION_OUTSIDE = 4, ACTION_POINTER_DOWN = 5, ACTION_POINTER_UP = 6

    let action: Int
    var x: Float
    var y: Float
    let rawX: Float
    let rawY: Float
    let eventTime: Int
    let downTime: Int
    var historySize: Int { 0 }
    var pointerCount: Int { 1 }

    init(action: Int, x: Float, y: Float, rawX: Float, rawY: Float, downTime: Int) {
        self.action = action; self.x = x; self.y = y; self.rawX = rawX; self.rawY = rawY
        self.downTime = downTime; eventTime = SystemClock.uptimeMillis()
    }
    var actionMasked: Int { action }
    func getX() -> Float { x }
    func getY() -> Float { y }
    func getX(_ i: Int) -> Float { x }
    func getY(_ i: Int) -> Float { y }
    func getHistoricalX(_ i: Int) -> Float { x }
    func getHistoricalY(_ i: Int) -> Float { y }
    func offsetLocation(_ dx: Float, _ dy: Float) { x += dx; y += dy }
}

// MARK: - Runnable / Handler

/// 같은 일을 나중에 취소(removeCallbacks)할 수 있게 상자에 담는다 — 안드로이드 Runnable.
final class Runnable {
    let block: () -> Void
    init(_ block: @escaping () -> Void) { self.block = block }
    func run() { block() }
}

final class Looper {
    static let main = Looper()
    static func getMainLooper() -> Looper { main }
    static func myLooper() -> Looper? { main }
}

final class Handler {
    private static var pending: [ObjectIdentifier: [DispatchWorkItem]] = [:]

    init() {}
    init(_ looper: Looper) {}

    @discardableResult func post(_ r: Runnable) -> Bool { postDelayed(r, 0) }
    @discardableResult func post(_ block: @escaping () -> Void) -> Bool { postDelayed(Runnable(block), 0) }
    @discardableResult func postDelayed(_ block: @escaping () -> Void, _ delayMillis: Int) -> Bool { postDelayed(Runnable(block), delayMillis) }
    @discardableResult func postDelayed(_ r: Runnable, _ delayMillis: Int) -> Bool {
        let key = ObjectIdentifier(r)
        var item: DispatchWorkItem!
        item = DispatchWorkItem { [weak item] in
            if let it = item { Handler.pending[key]?.removeAll { $0 === it } }
            r.run()
        }
        Handler.pending[key, default: []].append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(0, delayMillis)), execute: item)
        return true
    }
    func removeCallbacks(_ r: Runnable) {
        let key = ObjectIdentifier(r)
        Handler.pending[key]?.forEach { $0.cancel() }
        Handler.pending[key] = nil
    }
    func removeCallbacksAndMessages(_ token: Any?) {
        Handler.pending.values.forEach { $0.forEach { $0.cancel() } }
        Handler.pending = [:]
    }
}

// MARK: - View

class View: UIView {
    static let VISIBLE = 0, INVISIBLE = 4, GONE = 8
    static let NO_ID = -1
    static let LAYOUT_DIRECTION_LTR = 0
    static let TEXT_ALIGNMENT_CENTER = 4
    static let LAYER_TYPE_NONE = 0, LAYER_TYPE_SOFTWARE = 1, LAYER_TYPE_HARDWARE = 2
    static let OVER_SCROLL_NEVER = 2
    static let IMPORTANT_FOR_ACCESSIBILITY_NO = 2

    let context: Context
    var id: Int = View.NO_ID
    /// 안드로이드 View.tag (UIView.tag 는 Int 라 이름을 바꿈)
    var tagAny: Any?
    func getTag() -> Any? { tagAny }
    func setTag(_ t: Any?) { tagAny = t }

    // 크기·자리
    private(set) var measuredWidth = 0
    private(set) var measuredHeight = 0
    private(set) var left = 0
    private(set) var top = 0
    private(set) var right = 0
    private(set) var bottom = 0
    var width: Int { right - left }
    var height: Int { bottom - top }
    var x: Float { Float(left) + translationX }
    var y: Float { Float(top) + translationY }
    func getWidth() -> Int { width }
    func getHeight() -> Int { height }
    func getMeasuredWidth() -> Int { measuredWidth }
    func getMeasuredHeight() -> Int { measuredHeight }

    private(set) var paddingLeft = 0, paddingTop = 0, paddingRight = 0, paddingBottom = 0
    var paddingStart: Int { paddingLeft }
    var paddingEnd: Int { paddingRight }
    var minimumWidth = 0 { didSet { requestLayout() } }
    var minimumHeight = 0 { didSet { requestLayout() } }
    func setMinimumWidth(_ v: Int) { minimumWidth = v }
    func setMinimumHeight(_ v: Int) { minimumHeight = v }

    var layoutParams: BaseLayoutParams? { didSet { requestLayout() } }
    func getLayoutParams() -> BaseLayoutParams? { layoutParams }

    fileprivate(set) weak var parentGroup: ViewGroup?
    /// 안드로이드 getParent()
    var parent: ViewGroup? { parentGroup }

    var visibility: Int = View.VISIBLE {
        didSet {
            guard oldValue != visibility else { return }
            isHidden = visibility != View.VISIBLE
            if oldValue == View.GONE || visibility == View.GONE { requestLayout() }
        }
    }
    var isShown: Bool {
        var v: View? = self
        while let c = v { if c.visibility != View.VISIBLE { return false }; v = c.parentGroup }
        return window != nil
    }

    var isEnabled: Bool = true { didSet { if oldValue != isEnabled { refreshDrawableState() } } }
    var isClickable = false
    var isLongClickable = false
    var isFocusable = false
    var isFocusableInTouchMode = false
    var isSelected = false { didSet { if oldValue != isSelected { refreshDrawableState() } } }
    var isActivated = false
    var isPressed = false { didSet { if oldValue != isPressed { refreshDrawableState() } } }
    var isSoundEffectsEnabled = true
    var isHapticFeedbackEnabled = true
    var contentDescription: String? { get { accessibilityLabel } set { accessibilityLabel = newValue; isAccessibilityElement = newValue != nil } }
    var importantForAccessibility = 0
    var layoutDirection = 0
    var textAlignment = 0
    var overScrollMode = 0
    var elevation: Float = 0 { didSet { applyElevation() } }
    var translationZ: Float = 0
    var clipChildren = true
    var clipToPadding = true
    var willNotDraw = false

    // 변형 (안드로이드는 가운데를 기준으로 돈다·커진다)
    var translationX: Float = 0 { didSet { applyTransform() } }
    var translationY: Float = 0 { didSet { applyTransform() } }
    var scaleX: Float = 1 { didSet { applyTransform() } }
    var scaleY: Float = 1 { didSet { applyTransform() } }
    var rotation: Float = 0 { didSet { applyTransform() } }
    var pivotX: Float = .nan { didSet { applyPivot() } }
    var pivotY: Float = .nan { didSet { applyPivot() } }
    /// 안드로이드 alpha (Float)
    var alphaF: Float { get { Float(alpha) } set { alpha = CGFloat(newValue) } }

    // 배경
    var background: Drawable? {
        didSet { oldValue?.callback = nil; background?.callback = self; setNeedsDisplay(); requestLayout() }
    }
    var backgroundTintList: ColorStateList? { didSet { setNeedsDisplay() } }
    var foreground: Drawable? { didSet { foreground?.callback = self; setNeedsDisplay() } }
    var clipToOutline = false { didSet { applyOutline() } }
    var outlineProvider: ViewOutlineProvider? { didSet { applyOutline() } }

    // 듣는 이
    private var onClick: ((View) -> Void)?
    private var onLongClick: ((View) -> Bool)?
    private var onTouch: ((View, MotionEvent) -> Bool)?
    private var layoutChangeListeners: [(View, Int, Int, Int, Int, Int, Int, Int, Int) -> Void] = []

    // MARK: 만들기

    init(_ context: Context, _ attrs: AttributeSet? = nil) {
        self.context = context
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        clipsToBounds = false
        isMultipleTouchEnabled = false
    }
    convenience init(_ context: Context, _ attrs: AttributeSet?, _ defStyleAttr: Int) { self.init(context, attrs) }
    required init?(coder: NSCoder) { fatalError("코드로만 만든다") }

    // MARK: 여백

    func setPadding(_ l: Int, _ t: Int, _ r: Int, _ b: Int) {
        paddingLeft = l; paddingTop = t; paddingRight = r; paddingBottom = b
        requestLayout(); invalidate()
    }
    func setPaddingRelative(_ s: Int, _ t: Int, _ e: Int, _ b: Int) { setPadding(s, t, e, b) }

    // MARK: 재기

    final func measure(_ widthMeasureSpec: Int, _ heightMeasureSpec: Int) {
        onMeasure(widthMeasureSpec, heightMeasureSpec)
    }

    func onMeasure(_ widthMeasureSpec: Int, _ heightMeasureSpec: Int) {
        setMeasuredDimension(View.getDefaultSize(suggestedMinimumWidth, widthMeasureSpec),
                             View.getDefaultSize(suggestedMinimumHeight, heightMeasureSpec))
    }

    final func setMeasuredDimension(_ w: Int, _ h: Int) { measuredWidth = max(0, w); measuredHeight = max(0, h) }

    var suggestedMinimumWidth: Int { max(minimumWidth, background?.intrinsicWidth ?? 0) }
    var suggestedMinimumHeight: Int { max(minimumHeight, background?.intrinsicHeight ?? 0) }

    static func getDefaultSize(_ size: Int, _ spec: Int) -> Int {
        switch MeasureSpec.getMode(spec) {
        case MeasureSpec.AT_MOST, MeasureSpec.EXACTLY: return MeasureSpec.getSize(spec)
        default: return size
        }
    }
    static func resolveSize(_ size: Int, _ spec: Int) -> Int { resolveSizeAndState(size, spec, 0) }
    static func resolveSizeAndState(_ size: Int, _ spec: Int, _ childState: Int) -> Int {
        let s = MeasureSpec.getSize(spec)
        switch MeasureSpec.getMode(spec) {
        case MeasureSpec.AT_MOST: return min(size, s)
        case MeasureSpec.EXACTLY: return s
        default: return size
        }
    }

    // MARK: 자리

    final func layout(_ l: Int, _ t: Int, _ r: Int, _ b: Int) {
        let oldW = width, oldH = height
        let oldL = left, oldT = top, oldR = right, oldB = bottom
        let changed = l != left || t != top || r != right || b != bottom
        left = l; top = t; right = r; bottom = b
        // 변형이 있어도 맞도록 frame 대신 bounds·center 로
        bounds = CGRect(x: bounds.origin.x, y: bounds.origin.y, width: CGFloat(r - l), height: CGFloat(b - t))
        applyPivot()
        if oldW != width || oldH != height {
            onSizeChanged(width, height, oldW, oldH)
            setNeedsDisplay()
            applyOutline()
        }
        onLayout(changed, l, t, r, b)
        needsDroidLayout = false
        if changed { for f in layoutChangeListeners { f(self, l, t, r, b, oldL, oldT, oldR, oldB) } }
    }

    func onLayout(_ changed: Bool, _ l: Int, _ t: Int, _ r: Int, _ b: Int) {}
    func onSizeChanged(_ w: Int, _ h: Int, _ oldw: Int, _ oldh: Int) {}

    func addOnLayoutChangeListener(_ f: @escaping (View, Int, Int, Int, Int, Int, Int, Int, Int) -> Void) {
        layoutChangeListeners.append(f)
    }

    fileprivate var needsDroidLayout = true

    /// 다시 재고 배치해 달라고 맨 위까지 알린다
    func requestLayout() {
        needsDroidLayout = true
        if let p = parentGroup { p.requestLayout(); return }
        if isInsideDroidLayout { relayoutAfterPass = true } else { setNeedsLayout() }
    }
    var isLayoutRequested: Bool { needsDroidLayout }
    func forceLayout() { needsDroidLayout = true }

    /// 맨 위 View(부모가 안드로이드 View 가 아닌 것)는 UIKit 이 준 크기로 스스로 재고 배치한다.
    override func layoutSubviews() {
        super.layoutSubviews()
        guard parentGroup == nil, !isInsideDroidLayout else { return }
        let w = Int(bounds.width.rounded()), h = Int(bounds.height.rounded())
        guard w > 0 || h > 0 else { return }
        isInsideDroidLayout = true
        relayoutAfterPass = false
        measure(MeasureSpec.makeMeasureSpec(w, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(h, MeasureSpec.EXACTLY))
        let c = center
        layout(0, 0, w, h)
        center = c
        isInsideDroidLayout = false
        // 배치하는 동안 누가 다시 요청했으면 한 번만 더 (무한 반복 막기)
        if relayoutAfterPass && extraPasses < 3 {
            extraPasses += 1
            setNeedsLayout()
        } else { extraPasses = 0 }
    }
    private var isInsideDroidLayout = false
    private var relayoutAfterPass = false
    private var extraPasses = 0

    /// 부모 안에서의 위치 반영 (ViewGroup 이 layout 뒤에 부른다)
    fileprivate func placeInParent() {
        let cx = CGFloat(left) + CGFloat(width) / 2, cy = CGFloat(top) + CGFloat(height) / 2
        // 피벗이 가운데가 아니면 anchorPoint 만큼 옮긴다
        let ax = layer.anchorPoint.x, ay = layer.anchorPoint.y
        center = CGPoint(x: cx + (ax - 0.5) * CGFloat(width), y: cy + (ay - 0.5) * CGFloat(height))
    }

    // MARK: 그리기

    func invalidate() { setNeedsDisplay() }
    func postInvalidate() { DispatchQueue.main.async { self.setNeedsDisplay() } }
    func postInvalidateOnAnimation() { postInvalidate() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let canvas = Canvas(ctx: ctx, width: width, height: height)
        drawBackground(canvas)
        onDraw(canvas)
        dispatchDraw(canvas)
        if let f = foreground {
            f.setBounds(0, 0, width, height)
            f.draw(canvas)
        }
    }

    func drawBackground(_ canvas: Canvas) {
        guard let bg = background else { return }
        bg.setBounds(0, 0, width, height)
        let old = bg.tintColor
        if let t = backgroundTintList { bg.tintColor = t.defaultColor }
        bg.draw(canvas)
        bg.tintColor = old
    }

    func onDraw(_ canvas: Canvas) {}
    func dispatchDraw(_ canvas: Canvas) {}

    func setBackgroundColor(_ c: Int) { background = ColorDrawable(c) }
    func setBackgroundResource(_ id: Int) { background = id == 0 ? nil : Res.shared.drawable(id) }
    func setBackgroundDrawable(_ d: Drawable?) { background = d }
    func setLayerType(_ type: Int, _ paint: Paint?) {}
    func setWillNotDraw(_ b: Bool) { willNotDraw = b }

    /// 눌림·사용 안 함 같은 상태가 바뀌면 다시 그린다
    func refreshDrawableState() { setNeedsDisplay() }
    func drawableStateChanged() {}
    func jumpDrawablesToCurrentState() {}

    private func applyTransform() {
        var t = CGAffineTransform(translationX: CGFloat(translationX), y: CGFloat(translationY))
        t = t.rotated(by: CGFloat(rotation) * .pi / 180)
        t = t.scaledBy(x: CGFloat(scaleX), y: CGFloat(scaleY))
        transform = t
    }
    private func applyPivot() {
        guard width > 0, height > 0 else { placeInParent(); return }
        let ax = pivotX.isNaN ? 0.5 : CGFloat(pivotX) / CGFloat(width)
        let ay = pivotY.isNaN ? 0.5 : CGFloat(pivotY) / CGFloat(height)
        if layer.anchorPoint != CGPoint(x: ax, y: ay) { layer.anchorPoint = CGPoint(x: ax, y: ay) }
        placeInParent()
    }
    private func applyElevation() {
        if elevation > 0 {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.18
            layer.shadowRadius = CGFloat(elevation) * 0.8
            layer.shadowOffset = CGSize(width: 0, height: CGFloat(elevation) * 0.5)
        } else { layer.shadowOpacity = 0 }
    }
    private func applyOutline() {
        guard clipToOutline, let p = outlineProvider else { layer.cornerRadius = 0; clipsToBounds = false; return }
        let o = Outline()
        p.getOutline(self, o)
        layer.cornerRadius = CGFloat(o.radius)
        clipsToBounds = true
    }

    // MARK: 만지기

    @discardableResult func setOnClickListener(_ f: ((View) -> Void)?) -> View {
        onClick = f
        if f != nil { isClickable = true }
        return self
    }
    func setOnLongClickListener(_ f: ((View) -> Bool)?) { onLongClick = f; if f != nil { isLongClickable = true } }
    func setOnTouchListener(_ f: ((View, MotionEvent) -> Bool)?) { onTouch = f }
    var hasOnClickListeners: Bool { onClick != nil }

    @discardableResult func performClick() -> Bool {
        guard let f = onClick else { return false }
        f(self)
        return true
    }
    @discardableResult func callOnClick() -> Bool { performClick() }
    @discardableResult func performLongClick() -> Bool { onLongClick?(self) ?? false }
    func performHapticFeedback(_ type: Int) -> Bool { UIImpactFeedbackGenerator(style: .light).impactOccurred(); return true }

    /// 기본: 누를 수 있으면 눌림을 보이고, 손을 떼면 performClick.
    func onTouchEvent(_ event: MotionEvent) -> Bool {
        let clickable = isClickable || isLongClickable
        if !isEnabled { return clickable }
        guard clickable else { return false }
        switch event.action {
        case MotionEvent.ACTION_DOWN:
            isPressed = true
            longPressTimer?.invalidate()
            if isLongClickable {
                longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                    guard let s = self, s.isPressed else { return }
                    if s.performLongClick() { s.isPressed = false; s.longPressFired = true }
                }
            }
            longPressFired = false
        case MotionEvent.ACTION_MOVE:
            let inside = event.x >= -8 && event.y >= -8 && event.x < Float(width) + 8 && event.y < Float(height) + 8
            if !inside { isPressed = false; longPressTimer?.invalidate() }
        case MotionEvent.ACTION_UP:
            longPressTimer?.invalidate()
            if isPressed && !longPressFired {
                isPressed = false
                playClickFeedback()
                performClick()
            }
            isPressed = false
        case MotionEvent.ACTION_CANCEL:
            longPressTimer?.invalidate()
            isPressed = false
        default: break
        }
        return true
    }
    private var longPressTimer: Timer?
    private var longPressFired = false

    func playClickFeedback() {}

    /// 부모(스크롤)가 손가락 움직임을 가로채지 못하게 한다 — 끌기 조작용
    func requestDisallowInterceptTouchEvent(_ disallow: Bool) {
        parentGroup?.requestDisallowInterceptTouchEvent(disallow)
    }

    func dispatchTouchEvent(_ e: MotionEvent) -> Bool {
        if let t = onTouch, isEnabled, t(self, e) { return true }
        return onTouchEvent(e)
    }

    // UIKit 터치 → 안드로이드 MotionEvent
    private var forwardingTouches = false
    private var touchDownTime = 0

    private func motion(_ action: Int, _ touches: Set<UITouch>) -> MotionEvent? {
        guard let t = touches.first else { return nil }
        let p = t.location(in: self)
        let w = t.location(in: nil)
        // bounds 원점이 0 이 아닐 수 있다(스크롤 안) — 안드로이드 좌표는 뷰 왼쪽 위 기준
        return MotionEvent(action: action, x: Float(p.x - bounds.origin.x), y: Float(p.y - bounds.origin.y),
                           rawX: Float(w.x), rawY: Float(w.y), downTime: touchDownTime)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchDownTime = SystemClock.uptimeMillis()
        guard let e = motion(MotionEvent.ACTION_DOWN, touches) else { return }
        if dispatchTouchEvent(e) { forwardingTouches = false } else {
            forwardingTouches = true
            super.touchesBegan(touches, with: event)
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if forwardingTouches { super.touchesMoved(touches, with: event); return }
        if let e = motion(MotionEvent.ACTION_MOVE, touches) { _ = dispatchTouchEvent(e) }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if forwardingTouches { super.touchesEnded(touches, with: event); forwardingTouches = false; return }
        if let e = motion(MotionEvent.ACTION_UP, touches) { _ = dispatchTouchEvent(e) }
        ScrollView.releaseDisallow(from: self)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if forwardingTouches { super.touchesCancelled(touches, with: event); forwardingTouches = false; return }
        if let e = motion(MotionEvent.ACTION_CANCEL, touches) { _ = dispatchTouchEvent(e) }
        ScrollView.releaseDisallow(from: self)
    }

    /// 보이지 않는(GONE/INVISIBLE) 뷰나 꺼진 뷰는 손가락을 받지 않는다
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if visibility != View.VISIBLE || alpha < 0.01 { return nil }
        return super.hitTest(point, with: event)
    }

    // MARK: 미루기·움직이기

    @discardableResult func post(_ r: Runnable) -> Bool { Handler().post(r) }
    @discardableResult func post(_ block: @escaping () -> Void) -> Bool { Handler().post(block) }
    @discardableResult func postDelayed(_ r: Runnable, _ ms: Int) -> Bool { Handler().postDelayed(r, ms) }
    @discardableResult func postDelayed(_ block: @escaping () -> Void, _ ms: Int) -> Bool { Handler().postDelayed(block, ms) }
    @discardableResult func removeCallbacks(_ r: Runnable) -> Bool { Handler().removeCallbacks(r); return true }
    func postOnAnimation(_ block: @escaping () -> Void) { Handler().postDelayed(block, 16) }

    private var propertyAnimator: ViewPropertyAnimator?
    func animate() -> ViewPropertyAnimator {
        if let a = propertyAnimator { return a }
        let a = ViewPropertyAnimator(self)
        propertyAnimator = a
        return a
    }
    func clearAnimation() { activeAnimation?.cancel(); activeAnimation = nil }
    var activeAnimation: Animation?
    func startAnimation(_ a: Animation) { clearAnimation(); activeAnimation = a; a.start(on: self) }

    // MARK: 붙고 떨어짐

    var isAttachedToWindow: Bool { window != nil }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { onAttachedToWindow() } else { onDetachedFromWindow() }
    }
    func onAttachedToWindow() {}
    func onDetachedFromWindow() {}
    func onVisibilityChanged(_ changedView: View, _ visibility: Int) {}
    func onWindowFocusChanged(_ hasFocus: Bool) {}

    // MARK: 찾기·위치

    func findViewById<T: View>(_ id: Int) -> T? {
        if self.id == id { return self as? T }
        if let g = self as? ViewGroup {
            for c in g.children { if let f: T = c.findViewById(id) { return f } }
        }
        return nil
    }
    func findViewWithTag(_ tag: AnyHashable) -> View? {
        if let t = tagAny as? AnyHashable, t == tag { return self }
        if let g = self as? ViewGroup { for c in g.children { if let f = c.findViewWithTag(tag) { return f } } }
        return nil
    }

    func getLocationOnScreen(_ out: inout [Int]) {
        let p = convert(CGPoint(x: bounds.minX, y: bounds.minY), to: nil)
        out[0] = Int(p.x.rounded()); out[1] = Int(p.y.rounded())
    }
    func getLocationInWindow(_ out: inout [Int]) { getLocationOnScreen(&out) }
    func getGlobalVisibleRect(_ r: Rect) -> Bool {
        let f = convert(bounds, to: nil)
        r.set(Int(f.minX), Int(f.minY), Int(f.maxX), Int(f.maxY))
        return window != nil
    }
    func getHitRect(_ r: Rect) { r.set(left, top, right, bottom) }
    func getDrawingRect(_ r: Rect) { r.set(0, 0, width, height) }

    var rootView: View {
        var v: View = self
        while let p = v.parentGroup { v = p }
        return v
    }

    func bringToFront() {
        guard let p = parentGroup else { return }
        p.bringChildToFront(self)
    }
}

final class Outline {
    var radius: Float = 0
    var rect = Rect()
    func setRoundRect(_ l: Int, _ t: Int, _ r: Int, _ b: Int, _ radius: Float) { rect.set(l, t, r, b); self.radius = radius }
    func setRect(_ l: Int, _ t: Int, _ r: Int, _ b: Int) { rect.set(l, t, r, b); radius = 0 }
    func setOval(_ l: Int, _ t: Int, _ r: Int, _ b: Int) { rect.set(l, t, r, b); radius = Float(min(r - l, b - t)) / 2 }
}

class ViewOutlineProvider {
    static let BACKGROUND = ViewOutlineProvider()
    static let BOUNDS = ViewOutlineProvider()
    private let block: ((View, Outline) -> Void)?
    init(_ block: ((View, Outline) -> Void)? = nil) { self.block = block }
    func getOutline(_ view: View, _ outline: Outline) {
        if let b = block { b(view, outline) } else { outline.setRect(0, 0, view.width, view.height) }
    }
}

// MARK: - ViewGroup

class ViewGroup: View {
    private(set) var children: [View] = []
    /// 자식 UIView 를 넣을 곳 (ScrollView 는 안쪽 UIScrollView)
    var childContainer: UIView { self }

    var childCount: Int { children.count }
    func getChildCount() -> Int { children.count }
    func getChildAt(_ i: Int) -> View? { i >= 0 && i < children.count ? children[i] : nil }
    func indexOfChild(_ v: View) -> Int { children.firstIndex { $0 === v } ?? -1 }

    func generateDefaultLayoutParams() -> BaseLayoutParams { DroidMarginLayoutParams(BaseLayoutParams.WRAP_CONTENT, BaseLayoutParams.WRAP_CONTENT) }
    func generateLayoutParams(_ p: BaseLayoutParams) -> BaseLayoutParams { DroidMarginLayoutParams(p) }
    func checkLayoutParams(_ p: BaseLayoutParams) -> Bool { p is DroidMarginLayoutParams }

    func addView(_ child: View) { addView(child, -1) }
    func addView(_ child: View, _ index: Int) {
        let lp = child.layoutParams ?? generateDefaultLayoutParams()
        addView(child, index, lp)
    }
    func addView(_ child: View, _ width: Int, _ height: Int) {
        let lp = generateDefaultLayoutParams(); lp.width = width; lp.height = height
        addView(child, -1, lp)
    }
    func addView(_ child: View, _ params: BaseLayoutParams) { addView(child, -1, params) }
    func addView(_ child: View, _ index: Int, _ params: BaseLayoutParams) {
        precondition(child.parentGroup == nil, "The specified child already has a parent. You must call removeView() on the child's parent first.")
        child.layoutParams = checkLayoutParams(params) ? params : generateLayoutParams(params)
        let i = index < 0 || index > children.count ? children.count : index
        children.insert(child, at: i)
        child.parentGroup = self
        child.needsDroidLayout = true
        childContainer.insertSubview(child, at: subviewIndex(forChildIndex: i))
        onViewAdded(child)
        requestLayout()
        invalidate()
    }
    private func subviewIndex(forChildIndex i: Int) -> Int {
        // 안쪽 UIKit 부품(글자 라벨 등)이 앞에 있을 수 있어 뒤에서부터 센다
        if i >= children.count - 1 { return childContainer.subviews.count }
        let next = children[i + 1]
        return childContainer.subviews.firstIndex(of: next) ?? childContainer.subviews.count
    }
    func onViewAdded(_ child: View) {}
    func onViewRemoved(_ child: View) {}

    func removeView(_ child: View) {
        guard let i = children.firstIndex(where: { $0 === child }) else { return }
        removeViewAt(i)
    }
    func removeViewAt(_ i: Int) {
        let c = children.remove(at: i)
        c.parentGroup = nil
        c.removeFromSuperview()
        onViewRemoved(c)
        requestLayout()
    }
    func removeAllViews() {
        let old = children
        children.removeAll()
        for c in old { c.parentGroup = nil; c.removeFromSuperview(); onViewRemoved(c) }
        requestLayout()
        invalidate()
    }
    func removeViews(_ start: Int, _ count: Int) {
        for _ in 0..<count where start < children.count { removeViewAt(start) }
    }
    func bringChildToFront(_ child: View) {
        guard let i = children.firstIndex(where: { $0 === child }) else { return }
        children.remove(at: i); children.append(child)
        childContainer.bringSubviewToFront(child)
        requestLayout()
    }

    /// 자식 배치 뒤 UIKit 위치 맞추기는 View.layout 이 한다.
    override func requestDisallowInterceptTouchEvent(_ disallow: Bool) {
        parentGroup?.requestDisallowInterceptTouchEvent(disallow)
    }

    func shouldDelayChildPressedState() -> Bool { false }

    // MARK: 안드로이드 ViewGroup 의 재기 도우미 (원본과 같은 규칙)

    static func getChildMeasureSpec(_ spec: Int, _ padding: Int, _ childDimension: Int) -> Int {
        let specMode = MeasureSpec.getMode(spec)
        let specSize = MeasureSpec.getSize(spec)
        let size = max(0, specSize - padding)
        var resultSize = 0
        var resultMode = 0
        switch specMode {
        case MeasureSpec.EXACTLY:
            if childDimension >= 0 { resultSize = childDimension; resultMode = MeasureSpec.EXACTLY }
            else if childDimension == BaseLayoutParams.MATCH_PARENT { resultSize = size; resultMode = MeasureSpec.EXACTLY }
            else { resultSize = size; resultMode = MeasureSpec.AT_MOST }
        case MeasureSpec.AT_MOST:
            if childDimension >= 0 { resultSize = childDimension; resultMode = MeasureSpec.EXACTLY }
            else if childDimension == BaseLayoutParams.MATCH_PARENT { resultSize = size; resultMode = MeasureSpec.AT_MOST }
            else { resultSize = size; resultMode = MeasureSpec.AT_MOST }
        default:
            if childDimension >= 0 { resultSize = childDimension; resultMode = MeasureSpec.EXACTLY }
            else { resultSize = size; resultMode = MeasureSpec.UNSPECIFIED }
        }
        return MeasureSpec.makeMeasureSpec(resultSize, resultMode)
    }

    func measureChild(_ child: View, _ parentWidthMeasureSpec: Int, _ parentHeightMeasureSpec: Int) {
        let lp = child.layoutParams ?? generateDefaultLayoutParams()
        child.measure(
            ViewGroup.getChildMeasureSpec(parentWidthMeasureSpec, paddingLeft + paddingRight, lp.width),
            ViewGroup.getChildMeasureSpec(parentHeightMeasureSpec, paddingTop + paddingBottom, lp.height))
    }

    func measureChildWithMargins(_ child: View, _ parentWidthMeasureSpec: Int, _ widthUsed: Int,
                                 _ parentHeightMeasureSpec: Int, _ heightUsed: Int) {
        let lp = child.layoutParams ?? generateDefaultLayoutParams()
        let m = lp as? DroidMarginLayoutParams
        child.measure(
            ViewGroup.getChildMeasureSpec(parentWidthMeasureSpec,
                                          paddingLeft + paddingRight + (m?.leftMargin ?? 0) + (m?.rightMargin ?? 0) + widthUsed, lp.width),
            ViewGroup.getChildMeasureSpec(parentHeightMeasureSpec,
                                          paddingTop + paddingBottom + (m?.topMargin ?? 0) + (m?.bottomMargin ?? 0) + heightUsed, lp.height))
    }

    func measureChildren(_ w: Int, _ h: Int) {
        for c in children where c.visibility != View.GONE { measureChild(c, w, h) }
    }

    /// 코틀린 `children` 시퀀스와 `forEach`
    var childrenSequence: [View] { children }
}

/// 코틀린 `androidx.core.view.isVisible`
extension View {
    var isVisible: Bool {
        get { visibility == View.VISIBLE }
        set { visibility = newValue ? View.VISIBLE : View.GONE }
    }
    var isGone: Bool {
        get { visibility == View.GONE }
        set { visibility = newValue ? View.GONE : View.VISIBLE }
    }
    var isInvisible: Bool {
        get { visibility == View.INVISIBLE }
        set { visibility = newValue ? View.INVISIBLE : View.VISIBLE }
    }
}
