import UIKit

// 안드로이드 android.graphics 의 아이폰판.
//
// 안드로이드 화면 코드(onDraw)를 한 줄씩 옮길 수 있게 이름·인자·단위를 안드로이드와 같게 둔다.
// 좌표는 안드로이드 px 대신 아이폰 pt 를 쓴다(1dp = 1pt, density = 1).
// 색은 안드로이드처럼 Int(0xAARRGGBB) 로 다룬다.

// MARK: - Color

enum Color {
    static let BLACK = 0xFF000000
    static let DKGRAY = 0xFF444444
    static let GRAY = 0xFF888888
    static let LTGRAY = 0xFFCCCCCC
    static let WHITE = 0xFFFFFFFF
    static let RED = 0xFFFF0000
    static let GREEN = 0xFF00FF00
    static let BLUE = 0xFF0000FF
    static let YELLOW = 0xFFFFFF00
    static let CYAN = 0xFF00FFFF
    static let MAGENTA = 0xFFFF00FF
    static let TRANSPARENT = 0

    static func parseColor(_ s: String) -> Int {
        var h = s.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h.removeFirst() }
        guard let v = UInt64(h, radix: 16) else {
            // 안드로이드는 이름 색(red 등)도 받지만 이 앱은 # 만 쓴다
            fatalError("Unknown color: \(s)")
        }
        switch h.count {
        case 6: return Int(0xFF000000 | v)
        case 8: return Int(v)
        case 3:  // #RGB (리소스 XML 에서만)
            let r = (v >> 8) & 0xF, g = (v >> 4) & 0xF, b = v & 0xF
            return Int(0xFF000000 | (r * 17) << 16 | (g * 17) << 8 | b * 17)
        case 4:
            let a = (v >> 12) & 0xF, r = (v >> 8) & 0xF, g = (v >> 4) & 0xF, b = v & 0xF
            return Int((a * 17) << 24 | (r * 17) << 16 | (g * 17) << 8 | b * 17)
        default: fatalError("Unknown color: \(s)")
        }
    }

    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> Int { argb(255, r, g, b) }
    static func argb(_ a: Int, _ r: Int, _ g: Int, _ b: Int) -> Int {
        ((a & 0xFF) << 24) | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF)
    }
    static func rgb(_ r: Float, _ g: Float, _ b: Float) -> Int {
        rgb(Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
    static func alpha(_ c: Int) -> Int { (c >> 24) & 0xFF }
    static func red(_ c: Int) -> Int { (c >> 16) & 0xFF }
    static func green(_ c: Int) -> Int { (c >> 8) & 0xFF }
    static func blue(_ c: Int) -> Int { c & 0xFF }

    static func ui(_ c: Int) -> UIColor {
        UIColor(red: CGFloat(red(c)) / 255, green: CGFloat(green(c)) / 255,
                blue: CGFloat(blue(c)) / 255, alpha: CGFloat(alpha(c)) / 255)
    }
    static func cg(_ c: Int) -> CGColor { ui(c).cgColor }

    /// ColorUtils.blendARGB
    static func blendARGB(_ c1: Int, _ c2: Int, _ ratio: Float) -> Int {
        let inv = 1 - ratio
        func mix(_ a: Int, _ b: Int) -> Int { Int((Float(a) * inv + Float(b) * ratio).rounded()) }
        return argb(mix(alpha(c1), alpha(c2)), mix(red(c1), red(c2)), mix(green(c1), green(c2)), mix(blue(c1), blue(c2)))
    }
}

// MARK: - 기하

final class PointF {
    var x: Float
    var y: Float
    init() { x = 0; y = 0 }
    init(_ x: Float, _ y: Float) { self.x = x; self.y = y }
    func set(_ x: Float, _ y: Float) { self.x = x; self.y = y }
}

final class Rect {
    var left: Int, top: Int, right: Int, bottom: Int
    init() { left = 0; top = 0; right = 0; bottom = 0 }
    init(_ l: Int, _ t: Int, _ r: Int, _ b: Int) { left = l; top = t; right = r; bottom = b }
    func width() -> Int { right - left }
    func height() -> Int { bottom - top }
    func set(_ l: Int, _ t: Int, _ r: Int, _ b: Int) { left = l; top = t; right = r; bottom = b }
    var cg: CGRect { CGRect(x: left, y: top, width: right - left, height: bottom - top) }
}

final class RectF: CustomStringConvertible {
    var left: Float, top: Float, right: Float, bottom: Float
    init() { left = 0; top = 0; right = 0; bottom = 0 }
    init(_ l: Float, _ t: Float, _ r: Float, _ b: Float) { left = l; top = t; right = r; bottom = b }
    init(_ r: RectF) { left = r.left; top = r.top; right = r.right; bottom = r.bottom }
    func width() -> Float { right - left }
    func height() -> Float { bottom - top }
    func centerX() -> Float { (left + right) / 2 }
    func centerY() -> Float { (top + bottom) / 2 }
    func set(_ l: Float, _ t: Float, _ r: Float, _ b: Float) { left = l; top = t; right = r; bottom = b }
    func set(_ r: RectF) { set(r.left, r.top, r.right, r.bottom) }
    func contains(_ x: Float, _ y: Float) -> Bool { left < right && top < bottom && x >= left && x < right && y >= top && y < bottom }
    func inset(_ dx: Float, _ dy: Float) { left += dx; top += dy; right -= dx; bottom -= dy }
    func offset(_ dx: Float, _ dy: Float) { left += dx; right += dx; top += dy; bottom += dy }
    func offsetTo(_ x: Float, _ y: Float) { let w = width(), h = height(); left = x; top = y; right = x + w; bottom = y + h }
    func intersects(_ l: Float, _ t: Float, _ r: Float, _ b: Float) -> Bool { left < r && l < right && top < b && t < bottom }
    func isEmpty() -> Bool { left >= right || top >= bottom }
    var cg: CGRect { CGRect(x: CGFloat(left), y: CGFloat(top), width: CGFloat(right - left), height: CGFloat(bottom - top)) }
    var description: String { "RectF(\(left), \(top), \(right), \(bottom))" }
}

// MARK: - Typeface

final class Typeface: Equatable {
    static let NORMAL = 0, BOLD = 1, ITALIC = 2, BOLD_ITALIC = 3

    let style: Int
    let family: String       // "sans-serif", "sans-serif-medium", "monospace", "serif"
    init(family: String, style: Int) { self.family = family; self.style = style }

    static let DEFAULT = Typeface(family: "sans-serif", style: NORMAL)
    static let DEFAULT_BOLD = Typeface(family: "sans-serif", style: BOLD)
    static let SANS_SERIF = Typeface(family: "sans-serif", style: NORMAL)
    static let SERIF = Typeface(family: "serif", style: NORMAL)
    static let MONOSPACE = Typeface(family: "monospace", style: NORMAL)

    static func create(_ family: Typeface?, _ style: Int) -> Typeface { Typeface(family: family?.family ?? "sans-serif", style: style) }
    static func create(_ familyName: String?, _ style: Int) -> Typeface { Typeface(family: familyName ?? "sans-serif", style: style) }

    var isBold: Bool { style & Typeface.BOLD != 0 }
    var isItalic: Bool { style & Typeface.ITALIC != 0 }

    func font(size: CGFloat, fakeBold: Bool = false) -> UIFont {
        let bold = isBold || fakeBold
        var f: UIFont
        switch family {
        case "monospace":
            f = UIFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
        case "serif":
            f = UIFont(name: bold ? "Georgia-Bold" : "Georgia", size: size) ?? .systemFont(ofSize: size)
        case "sans-serif-medium":
            f = UIFont.systemFont(ofSize: size, weight: bold ? .bold : .medium)
        case "sans-serif-black":
            f = UIFont.systemFont(ofSize: size, weight: .black)
        default:
            f = UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
        }
        if isItalic, let d = f.fontDescriptor.withSymbolicTraits(.traitItalic) { f = UIFont(descriptor: d, size: size) }
        return f
    }

    static func == (a: Typeface, b: Typeface) -> Bool { a.style == b.style && a.family == b.family }
}

// MARK: - Paint

class PathEffect {}
final class DashPathEffect: PathEffect {
    let intervals: [Float]
    let phase: Float
    init(_ intervals: [Float], _ phase: Float) { self.intervals = intervals; self.phase = phase }
}

enum PorterDuff {
    enum Mode { case CLEAR, SRC, SRC_OVER, SRC_IN, SRC_ATOP, DST_IN, DST_OUT, MULTIPLY, SCREEN, ADD }
}
class Xfermode {}
final class PorterDuffXfermode: Xfermode {
    let mode: PorterDuff.Mode
    init(_ mode: PorterDuff.Mode) { self.mode = mode }
}

final class Paint {
    static let ANTI_ALIAS_FLAG = 1
    static let FILTER_BITMAP_FLAG = 2
    static let DITHER_FLAG = 4
    static let UNDERLINE_TEXT_FLAG = 8
    static let STRIKE_THRU_TEXT_FLAG = 16
    static let FAKE_BOLD_TEXT_FLAG = 32

    enum Style { case FILL, STROKE, FILL_AND_STROKE }
    enum Cap { case BUTT, ROUND, SQUARE }
    enum Join { case MITER, ROUND, BEVEL }
    enum Align { case LEFT, CENTER, RIGHT }

    final class FontMetrics {
        var top: Float = 0, ascent: Float = 0, descent: Float = 0, bottom: Float = 0, leading: Float = 0
    }

    var flags: Int = 0
    var color: Int = Color.BLACK
    var style: Style = .FILL
    var strokeWidth: Float = 0
    var strokeCap: Cap = .BUTT
    var strokeJoin: Join = .MITER
    var textSize: Float = 12
    var textAlign: Align = .LEFT
    var typeface: Typeface? = nil
    var pathEffect: PathEffect? = nil
    var xfermode: Xfermode? = nil
    var letterSpacing: Float = 0
    var isAntiAlias: Bool = true
    var isFilterBitmap: Bool = true
    var isDither: Bool = false
    var shadowRadius: Float = 0, shadowDx: Float = 0, shadowDy: Float = 0, shadowColor: Int = 0

    init() {}
    init(_ flags: Int) { self.flags = flags }
    init(_ other: Paint) { set(other) }

    func set(_ o: Paint) {
        flags = o.flags; color = o.color; style = o.style; strokeWidth = o.strokeWidth
        strokeCap = o.strokeCap; strokeJoin = o.strokeJoin; textSize = o.textSize; textAlign = o.textAlign
        typeface = o.typeface; pathEffect = o.pathEffect; xfermode = o.xfermode; letterSpacing = o.letterSpacing
        shadowRadius = o.shadowRadius; shadowDx = o.shadowDx; shadowDy = o.shadowDy; shadowColor = o.shadowColor
    }

    /// 0~255. 안드로이드처럼 색의 알파 바이트를 바꾼다.
    var alpha: Int {
        get { Color.alpha(color) }
        set { color = (color & 0x00FFFFFF) | ((max(0, min(255, newValue))) << 24) }
    }

    var isFakeBoldText: Bool {
        get { flags & Paint.FAKE_BOLD_TEXT_FLAG != 0 }
        set { if newValue { flags |= Paint.FAKE_BOLD_TEXT_FLAG } else { flags &= ~Paint.FAKE_BOLD_TEXT_FLAG } }
    }
    var isStrikeThruText: Bool {
        get { flags & Paint.STRIKE_THRU_TEXT_FLAG != 0 }
        set { if newValue { flags |= Paint.STRIKE_THRU_TEXT_FLAG } else { flags &= ~Paint.STRIKE_THRU_TEXT_FLAG } }
    }
    var isUnderlineText: Bool {
        get { flags & Paint.UNDERLINE_TEXT_FLAG != 0 }
        set { if newValue { flags |= Paint.UNDERLINE_TEXT_FLAG } else { flags &= ~Paint.UNDERLINE_TEXT_FLAG } }
    }

    func setARGB(_ a: Int, _ r: Int, _ g: Int, _ b: Int) { color = Color.argb(a, r, g, b) }
    func setShadowLayer(_ radius: Float, _ dx: Float, _ dy: Float, _ shadowColor: Int) {
        shadowRadius = radius; shadowDx = dx; shadowDy = dy; self.shadowColor = shadowColor
    }
    func clearShadowLayer() { shadowRadius = 0 }

    // MARK: 글자

    var uiFont: UIFont { (typeface ?? .DEFAULT).font(size: CGFloat(max(0.1, textSize)), fakeBold: isFakeBoldText) }

    func attributes(color c: Int? = nil) -> [NSAttributedString.Key: Any] {
        var a: [NSAttributedString.Key: Any] = [.font: uiFont, .foregroundColor: Color.ui(c ?? color)]
        if letterSpacing != 0 { a[.kern] = CGFloat(letterSpacing * textSize) }
        if isStrikeThruText { a[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if isUnderlineText { a[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        return a
    }

    func measureText(_ text: String) -> Float {
        if text.isEmpty { return 0 }
        return Float(NSAttributedString(string: text, attributes: attributes()).size().width)
    }
    func measureText(_ text: String, _ start: Int, _ end: Int) -> Float {
        measureText(text.substring(start, end))
    }

    var fontMetrics: FontMetrics {
        let f = uiFont
        let m = FontMetrics()
        m.ascent = -Float(f.ascender)
        m.descent = -Float(f.descender)
        m.top = m.ascent * 1.1
        m.bottom = m.descent * 1.1
        m.leading = Float(f.leading)
        return m
    }
    func getFontMetrics() -> FontMetrics { fontMetrics }
    func ascent() -> Float { -Float(uiFont.ascender) }
    func descent() -> Float { -Float(uiFont.descender) }
    func getFontSpacing() -> Float { Float(uiFont.lineHeight) }

    func getTextBounds(_ text: String, _ start: Int, _ end: Int, _ bounds: Rect) {
        let s = text.substring(start, end)
        let w = measureText(s)
        let f = uiFont
        bounds.set(0, Int(-f.capHeight.rounded()), Int(w.rounded()), Int((-f.descender * 0.2).rounded()))
    }

    /// 안드로이드 breakText — maxWidth 안에 들어가는 글자 수.
    func breakText(_ text: String, _ measureForwards: Bool, _ maxWidth: Float, _ measuredWidth: [Float]?) -> Int {
        let chars = Array(text)
        var n = 0
        while n < chars.count && measureText(String(chars[0...n])) <= maxWidth { n += 1 }
        return n
    }
}

// MARK: - Path

final class Path {
    enum Direction { case CW, CCW }
    enum FillType { case WINDING, EVEN_ODD }

    private(set) var cg = CGMutablePath()
    var fillType: FillType = .WINDING

    init() {}
    init(_ src: Path) { cg = src.cg.mutableCopy() ?? CGMutablePath(); fillType = src.fillType }

    func reset() { cg = CGMutablePath() }
    func rewind() { reset() }
    func isEmpty() -> Bool { cg.isEmpty }
    func set(_ src: Path) { cg = src.cg.mutableCopy() ?? CGMutablePath(); fillType = src.fillType }

    private var current: CGPoint { cg.isEmpty ? .zero : cg.currentPoint }

    func moveTo(_ x: Float, _ y: Float) { cg.move(to: CGPoint(x: CGFloat(x), y: CGFloat(y))) }
    func rMoveTo(_ dx: Float, _ dy: Float) { let p = current; cg.move(to: CGPoint(x: p.x + CGFloat(dx), y: p.y + CGFloat(dy))) }
    func lineTo(_ x: Float, _ y: Float) {
        if cg.isEmpty { cg.move(to: .zero) }
        cg.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
    }
    func rLineTo(_ dx: Float, _ dy: Float) { let p = current; lineTo(Float(p.x) + dx, Float(p.y) + dy) }
    func quadTo(_ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float) {
        if cg.isEmpty { cg.move(to: .zero) }
        cg.addQuadCurve(to: CGPoint(x: CGFloat(x2), y: CGFloat(y2)), control: CGPoint(x: CGFloat(x1), y: CGFloat(y1)))
    }
    func rQuadTo(_ dx1: Float, _ dy1: Float, _ dx2: Float, _ dy2: Float) {
        let p = current
        quadTo(Float(p.x) + dx1, Float(p.y) + dy1, Float(p.x) + dx2, Float(p.y) + dy2)
    }
    func cubicTo(_ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float, _ x3: Float, _ y3: Float) {
        if cg.isEmpty { cg.move(to: .zero) }
        cg.addCurve(to: CGPoint(x: CGFloat(x3), y: CGFloat(y3)),
                    control1: CGPoint(x: CGFloat(x1), y: CGFloat(y1)), control2: CGPoint(x: CGFloat(x2), y: CGFloat(y2)))
    }
    func close() { if !cg.isEmpty { cg.closeSubpath() } }

    func addCircle(_ x: Float, _ y: Float, _ radius: Float, _ dir: Direction) {
        cg.addEllipse(in: CGRect(x: CGFloat(x - radius), y: CGFloat(y - radius), width: CGFloat(radius * 2), height: CGFloat(radius * 2)))
    }
    func addOval(_ oval: RectF, _ dir: Direction) { cg.addEllipse(in: oval.cg) }
    func addOval(_ l: Float, _ t: Float, _ r: Float, _ b: Float, _ dir: Direction) { addOval(RectF(l, t, r, b), dir) }
    func addRect(_ rect: RectF, _ dir: Direction) { cg.addRect(rect.cg) }
    func addRect(_ l: Float, _ t: Float, _ r: Float, _ b: Float, _ dir: Direction) { cg.addRect(RectF(l, t, r, b).cg) }
    func addRoundRect(_ rect: RectF, _ rx: Float, _ ry: Float, _ dir: Direction) {
        let r = rect.cg
        let cw = min(CGFloat(rx), r.width / 2), ch = min(CGFloat(ry), r.height / 2)
        if cw <= 0 || ch <= 0 { cg.addRect(r) } else { cg.addRoundedRect(in: r, cornerWidth: cw, cornerHeight: ch) }
    }
    func addRoundRect(_ l: Float, _ t: Float, _ r: Float, _ b: Float, _ rx: Float, _ ry: Float, _ dir: Direction) {
        addRoundRect(RectF(l, t, r, b), rx, ry, dir)
    }
    /// radii: 8개 (좌상 x,y, 우상 x,y, 우하 x,y, 좌하 x,y)
    func addRoundRect(_ rect: RectF, _ radii: [Float], _ dir: Direction) {
        cg.addPath(Path.roundRectPath(rect.cg, radii.map { CGFloat($0) }))
    }

    static func roundRectPath(_ r: CGRect, _ radii: [CGFloat]) -> CGPath {
        let p = CGMutablePath()
        let maxR = min(r.width, r.height) / 2
        let tl = min(radii[0], maxR), tr = min(radii[2], maxR), br = min(radii[4], maxR), bl = min(radii[6], maxR)
        p.move(to: CGPoint(x: r.minX + tl, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - tr, y: r.minY))
        if tr > 0 { p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY + tr), radius: tr) }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - br))
        if br > 0 { p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.maxX - br, y: r.maxY), radius: br) }
        p.addLine(to: CGPoint(x: r.minX + bl, y: r.maxY))
        if bl > 0 { p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY - bl), radius: bl) }
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + tl))
        if tl > 0 { p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.minX + tl, y: r.minY), radius: tl) }
        p.closeSubpath()
        return p
    }

    /// 안드로이드 각도(도, 3시 방향에서 시계 방향)로 타원 호.
    static func arcPath(_ oval: CGRect, _ startAngle: Float, _ sweepAngle: Float, moveTo: Bool, into p: CGMutablePath, center: Bool = false) {
        let cx = oval.midX, cy = oval.midY, rx = oval.width / 2, ry = oval.height / 2
        let steps = max(4, Int(abs(sweepAngle) / 4))
        for i in 0...steps {
            let a = CGFloat(startAngle + sweepAngle * Float(i) / Float(steps)) * .pi / 180
            let pt = CGPoint(x: cx + rx * cos(a), y: cy + ry * sin(a))
            if i == 0 {
                if center { p.move(to: CGPoint(x: cx, y: cy)); p.addLine(to: pt) }
                else if moveTo || p.isEmpty { p.move(to: pt) } else { p.addLine(to: pt) }
            } else { p.addLine(to: pt) }
        }
        if center { p.closeSubpath() }
    }

    func arcTo(_ oval: RectF, _ startAngle: Float, _ sweepAngle: Float, _ forceMoveTo: Bool) {
        Path.arcPath(oval.cg, startAngle, sweepAngle, moveTo: forceMoveTo, into: cg)
    }
    func arcTo(_ oval: RectF, _ startAngle: Float, _ sweepAngle: Float) { arcTo(oval, startAngle, sweepAngle, false) }
    func arcTo(_ l: Float, _ t: Float, _ r: Float, _ b: Float, _ startAngle: Float, _ sweepAngle: Float, _ forceMoveTo: Bool) {
        arcTo(RectF(l, t, r, b), startAngle, sweepAngle, forceMoveTo)
    }
    func addArc(_ oval: RectF, _ startAngle: Float, _ sweepAngle: Float) {
        Path.arcPath(oval.cg, startAngle, sweepAngle, moveTo: true, into: cg)
    }
    func addPath(_ src: Path) { cg.addPath(src.cg) }
    func addPath(_ src: Path, _ dx: Float, _ dy: Float) {
        cg.addPath(src.cg, transform: CGAffineTransform(translationX: CGFloat(dx), y: CGFloat(dy)))
    }
    func offset(_ dx: Float, _ dy: Float) {
        var t = CGAffineTransform(translationX: CGFloat(dx), y: CGFloat(dy))
        cg = cg.mutableCopy(using: &t) ?? cg
    }
    func computeBounds(_ bounds: RectF, _ exact: Bool) {
        let b = cg.isEmpty ? .zero : cg.boundingBoxOfPath
        bounds.set(Float(b.minX), Float(b.minY), Float(b.maxX), Float(b.maxY))
    }
}

// MARK: - Bitmap

final class Bitmap {
    enum Config { case ARGB_8888, RGB_565, ALPHA_8 }
    let width: Int
    let height: Int
    let context: CGContext

    private init(width: Int, height: Int) {
        self.width = max(1, width); self.height = max(1, height)
        let scale = Int(UIScreen.main.scale)
        context = CGContext(data: nil, width: self.width * scale, height: self.height * scale, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // 안드로이드처럼 왼쪽 위가 원점, 아래로 y 증가
        context.translateBy(x: 0, y: CGFloat(self.height * scale))
        context.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
    }

    static func createBitmap(_ width: Int, _ height: Int, _ config: Config) -> Bitmap { Bitmap(width: width, height: height) }

    var cgImage: CGImage? { context.makeImage() }

    func eraseColor(_ c: Int) {
        context.saveGState()
        context.setBlendMode(.copy)
        context.setFillColor(Color.cg(c))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.restoreGState()
    }
    func recycle() {}
    var isRecycled: Bool { false }
}

// MARK: - Canvas

final class Canvas {
    let ctx: CGContext
    private(set) var width: Int
    private(set) var height: Int
    private var saveCount = 0

    init(ctx: CGContext, width: Int, height: Int) {
        self.ctx = ctx; self.width = width; self.height = height
    }
    convenience init(_ bitmap: Bitmap) {
        self.init(ctx: bitmap.context, width: bitmap.width, height: bitmap.height)
    }

    // MARK: 상태
    @discardableResult func save() -> Int { ctx.saveGState(); saveCount += 1; return saveCount }
    func restore() { if saveCount > 0 { ctx.restoreGState(); saveCount -= 1 } }
    func restoreToCount(_ n: Int) { while saveCount >= n && saveCount > 0 { restore() } }
    func translate(_ dx: Float, _ dy: Float) { ctx.translateBy(x: CGFloat(dx), y: CGFloat(dy)) }
    func scale(_ sx: Float, _ sy: Float) { ctx.scaleBy(x: CGFloat(sx), y: CGFloat(sy)) }
    func scale(_ sx: Float, _ sy: Float, _ px: Float, _ py: Float) { translate(px, py); scale(sx, sy); translate(-px, -py) }
    func rotate(_ degrees: Float) { ctx.rotate(by: CGFloat(degrees) * .pi / 180) }
    func rotate(_ degrees: Float, _ px: Float, _ py: Float) { translate(px, py); rotate(degrees); translate(-px, -py) }
    @discardableResult func clipRect(_ r: RectF) -> Bool { ctx.clip(to: r.cg); return true }
    @discardableResult func clipRect(_ l: Float, _ t: Float, _ r: Float, _ b: Float) -> Bool { clipRect(RectF(l, t, r, b)) }
    @discardableResult func clipPath(_ p: Path) -> Bool {
        ctx.addPath(p.cg); if p.fillType == .EVEN_ODD { ctx.clip(using: .evenOdd) } else { ctx.clip() }; return true
    }

    // MARK: 칠하기 도우미
    private func withPaint(_ paint: Paint, _ body: () -> Void) {
        ctx.saveGState()
        ctx.setShouldAntialias(paint.flags & Paint.ANTI_ALIAS_FLAG != 0 || paint.isAntiAlias)
        if let x = paint.xfermode as? PorterDuffXfermode {
            switch x.mode {
            case .CLEAR: ctx.setBlendMode(.clear)
            case .SRC: ctx.setBlendMode(.copy)
            case .SRC_IN: ctx.setBlendMode(.sourceIn)
            case .SRC_ATOP: ctx.setBlendMode(.sourceAtop)
            case .DST_IN: ctx.setBlendMode(.destinationIn)
            case .DST_OUT: ctx.setBlendMode(.destinationOut)
            case .MULTIPLY: ctx.setBlendMode(.multiply)
            case .SCREEN: ctx.setBlendMode(.screen)
            case .ADD: ctx.setBlendMode(.plusLighter)
            case .SRC_OVER: break
            }
        }
        if paint.shadowRadius > 0 {
            ctx.setShadow(offset: CGSize(width: CGFloat(paint.shadowDx), height: CGFloat(paint.shadowDy)),
                          blur: CGFloat(paint.shadowRadius) * 1.4, color: Color.cg(paint.shadowColor))
        }
        body()
        ctx.restoreGState()
    }

    private func applyStroke(_ paint: Paint) {
        ctx.setLineWidth(CGFloat(paint.strokeWidth <= 0 ? 1 : paint.strokeWidth))
        switch paint.strokeCap { case .BUTT: ctx.setLineCap(.butt); case .ROUND: ctx.setLineCap(.round); case .SQUARE: ctx.setLineCap(.square) }
        switch paint.strokeJoin { case .MITER: ctx.setLineJoin(.miter); case .ROUND: ctx.setLineJoin(.round); case .BEVEL: ctx.setLineJoin(.bevel) }
        if let d = paint.pathEffect as? DashPathEffect {
            ctx.setLineDash(phase: CGFloat(d.phase), lengths: d.intervals.map { CGFloat($0) })
        }
        ctx.setStrokeColor(Color.cg(paint.color))
    }

    private func drawCG(_ path: CGPath, _ paint: Paint, evenOdd: Bool = false) {
        withPaint(paint) {
            if paint.style == .FILL || paint.style == .FILL_AND_STROKE {
                ctx.addPath(path)
                ctx.setFillColor(Color.cg(paint.color))
                ctx.fillPath(using: evenOdd ? .evenOdd : .winding)
            }
            if paint.style == .STROKE || paint.style == .FILL_AND_STROKE {
                ctx.addPath(path)
                applyStroke(paint)
                ctx.strokePath()
            }
        }
    }

    // MARK: 도형
    func drawColor(_ color: Int) {
        ctx.saveGState()
        ctx.setFillColor(Color.cg(color))
        ctx.fill(CGRect(x: -10000, y: -10000, width: 30000, height: 30000))
        ctx.restoreGState()
    }
    func drawColor(_ color: Int, _ mode: PorterDuff.Mode) {
        ctx.saveGState()
        if mode == .CLEAR { ctx.setBlendMode(.clear) } else if mode == .SRC { ctx.setBlendMode(.copy) }
        ctx.setFillColor(Color.cg(color))
        ctx.fill(CGRect(x: -10000, y: -10000, width: 30000, height: 30000))
        ctx.restoreGState()
    }
    func drawARGB(_ a: Int, _ r: Int, _ g: Int, _ b: Int) { drawColor(Color.argb(a, r, g, b)) }
    func drawPaint(_ paint: Paint) { drawColor(paint.color) }

    func drawLine(_ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float, _ paint: Paint) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: CGFloat(x1), y: CGFloat(y1)))
        p.addLine(to: CGPoint(x: CGFloat(x2), y: CGFloat(y2)))
        withPaint(paint) {
            ctx.addPath(p)
            applyStroke(paint)
            ctx.strokePath()
        }
    }
    func drawLines(_ pts: [Float], _ paint: Paint) {
        var i = 0
        while i + 3 < pts.count { drawLine(pts[i], pts[i + 1], pts[i + 2], pts[i + 3], paint); i += 4 }
    }
    func drawPoint(_ x: Float, _ y: Float, _ paint: Paint) {
        let r = max(0.5, paint.strokeWidth / 2)
        let fill = Paint(paint); fill.style = .FILL
        if paint.strokeCap == .ROUND { drawCircle(x, y, r, fill) } else { drawRect(x - r, y - r, x + r, y + r, fill) }
    }
    func drawCircle(_ cx: Float, _ cy: Float, _ radius: Float, _ paint: Paint) {
        guard radius > 0 else { return }
        drawCG(CGPath(ellipseIn: CGRect(x: CGFloat(cx - radius), y: CGFloat(cy - radius), width: CGFloat(radius * 2), height: CGFloat(radius * 2)), transform: nil), paint)
    }
    func drawRect(_ r: RectF, _ paint: Paint) { drawCG(CGPath(rect: r.cg, transform: nil), paint) }
    func drawRect(_ r: Rect, _ paint: Paint) { drawCG(CGPath(rect: r.cg, transform: nil), paint) }
    func drawRect(_ l: Float, _ t: Float, _ r: Float, _ b: Float, _ paint: Paint) { drawRect(RectF(l, t, r, b), paint) }
    func drawOval(_ r: RectF, _ paint: Paint) { drawCG(CGPath(ellipseIn: r.cg, transform: nil), paint) }
    func drawOval(_ l: Float, _ t: Float, _ r: Float, _ b: Float, _ paint: Paint) { drawOval(RectF(l, t, r, b), paint) }
    func drawRoundRect(_ r: RectF, _ rx: Float, _ ry: Float, _ paint: Paint) {
        let p = Path(); p.addRoundRect(r, rx, ry, .CW)
        drawCG(p.cg, paint)
    }
    func drawRoundRect(_ l: Float, _ t: Float, _ r: Float, _ b: Float, _ rx: Float, _ ry: Float, _ paint: Paint) {
        drawRoundRect(RectF(l, t, r, b), rx, ry, paint)
    }
    func drawArc(_ oval: RectF, _ startAngle: Float, _ sweepAngle: Float, _ useCenter: Bool, _ paint: Paint) {
        let p = CGMutablePath()
        Path.arcPath(oval.cg, startAngle, sweepAngle, moveTo: true, into: p, center: useCenter)
        drawCG(p, paint)
    }
    func drawArc(_ l: Float, _ t: Float, _ r: Float, _ b: Float, _ startAngle: Float, _ sweepAngle: Float, _ useCenter: Bool, _ paint: Paint) {
        drawArc(RectF(l, t, r, b), startAngle, sweepAngle, useCenter, paint)
    }
    func drawPath(_ path: Path, _ paint: Paint) { drawCG(path.cg, paint, evenOdd: path.fillType == .EVEN_ODD) }

    // MARK: 글자
    /// y 는 글자 기준선(baseline). 정렬은 paint.textAlign.
    func drawText(_ text: String, _ x: Float, _ y: Float, _ paint: Paint) {
        if text.isEmpty { return }
        let font = paint.uiFont
        withPaint(paint) {
            UIGraphicsPushContext(ctx)
            defer { UIGraphicsPopContext() }
            if paint.style == .FILL || paint.style == .FILL_AND_STROKE {
                let s = NSAttributedString(string: text, attributes: paint.attributes())
                let w = s.size().width
                let dx: CGFloat = paint.textAlign == .CENTER ? w / 2 : (paint.textAlign == .RIGHT ? w : 0)
                if paint.style == .FILL_AND_STROKE && paint.strokeWidth > 0 {
                    var a = paint.attributes()
                    a[.strokeColor] = Color.ui(paint.color)
                    a[.strokeWidth] = -CGFloat(paint.strokeWidth / max(1, paint.textSize) * 100)
                    NSAttributedString(string: text, attributes: a).draw(at: CGPoint(x: CGFloat(x) - dx, y: CGFloat(y) - font.ascender))
                } else {
                    s.draw(at: CGPoint(x: CGFloat(x) - dx, y: CGFloat(y) - font.ascender))
                }
            } else {
                // 외곽선 글자
                var a = paint.attributes()
                a[.strokeColor] = Color.ui(paint.color)
                a[.foregroundColor] = UIColor.clear
                a[.strokeWidth] = CGFloat(paint.strokeWidth / max(1, paint.textSize) * 100)
                let s = NSAttributedString(string: text, attributes: a)
                let w = s.size().width
                let dx: CGFloat = paint.textAlign == .CENTER ? w / 2 : (paint.textAlign == .RIGHT ? w : 0)
                s.draw(at: CGPoint(x: CGFloat(x) - dx, y: CGFloat(y) - font.ascender))
            }
        }
    }
    func drawText(_ text: String, _ start: Int, _ end: Int, _ x: Float, _ y: Float, _ paint: Paint) {
        drawText(text.substring(start, end), x, y, paint)
    }

    // MARK: 그림
    func drawBitmap(_ bitmap: Bitmap, _ left: Float, _ top: Float, _ paint: Paint?) {
        guard let img = bitmap.cgImage else { return }
        drawImage(img, CGRect(x: CGFloat(left), y: CGFloat(top), width: CGFloat(bitmap.width), height: CGFloat(bitmap.height)), paint)
    }
    func drawBitmap(_ bitmap: Bitmap, _ src: Rect?, _ dst: RectF, _ paint: Paint?) {
        guard let img = bitmap.cgImage else { return }
        drawImage(img, dst.cg, paint)
    }
    func drawImage(_ img: CGImage, _ rect: CGRect, _ paint: Paint?) {
        ctx.saveGState()
        if let p = paint { ctx.setAlpha(CGFloat(p.alpha) / 255) }
        // CGImage 는 아래가 원점이라 뒤집어 그린다
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        ctx.restoreGState()
    }
    func drawUIImage(_ img: UIImage, _ rect: CGRect, alpha: CGFloat = 1) {
        UIGraphicsPushContext(ctx)
        img.draw(in: rect, blendMode: .normal, alpha: alpha)
        UIGraphicsPopContext()
    }
}

// 코틀린 `Paint(...).apply { }` 처럼 쓸 수 있게
extension Paint: KotlinScope {}
extension Path: KotlinScope {}
extension RectF: KotlinScope {}
extension PointF: KotlinScope {}
extension Rect: KotlinScope {}
extension Drawable: KotlinScope {}
extension BaseLayoutParams: KotlinScope {}
extension ValueAnimator: KotlinScope {}
