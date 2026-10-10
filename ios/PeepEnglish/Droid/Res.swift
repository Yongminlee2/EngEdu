import UIKit

// 안드로이드 res/ 를 아이폰에서 그대로 읽는다.
//
// 빌드 단계(tools/copy-assets.sh)가 안드로이드 app/src/main/res 를 번들의 res/ 로 복사하고,
// 여기서 values*/strings.xml·colors.xml·dimens.xml, drawable XML(shape·layer-list), 그림 파일을 읽는다.
// 문구·색·그림의 원본은 안드로이드 한 벌뿐이다 — 아이폰에 사본을 두지 않는다.
//
// 리소스 번호(R.string.x 등)는 tools/gen-r.py 가 만든 Gen/R.swift 에 있다(안드로이드처럼 Int).

// MARK: - 리소스 번호 ↔ 이름

enum ResType: Int, CaseIterable {
    case string = 1, array, color, dimen, drawable, mipmap, layout, id, anim, raw, xml

    var name: String {
        switch self {
        case .string: return "string"; case .array: return "array"; case .color: return "color"
        case .dimen: return "dimen"; case .drawable: return "drawable"; case .mipmap: return "mipmap"
        case .layout: return "layout"; case .id: return "id"; case .anim: return "anim"
        case .raw: return "raw"; case .xml: return "xml"
        }
    }
    static func of(_ name: String) -> ResType? { allCases.first { $0.name == name } }
}

/// R.swift 의 이름 표를 받아 번호 ↔ 이름을 바꾼다.
enum ResNames {
    static var tables: [ResType: [String]] = [:]       // Gen/R.swift 가 채운다(R.register())
    private static var reverse: [ResType: [String: Int]] = [:]

    static func id(_ type: ResType, _ name: String) -> Int {
        if reverse[type] == nil {
            var m: [String: Int] = [:]
            for (i, n) in (tables[type] ?? []).enumerated() { m[n] = make(type, i) }
            reverse[type] = m
        }
        return reverse[type]?[name] ?? 0
    }
    static func make(_ type: ResType, _ index: Int) -> Int { 0x7f00_0000 | (type.rawValue << 16) | index }
    static func type(_ id: Int) -> ResType? { ResType(rawValue: (id >> 16) & 0xFF) }
    static func name(_ id: Int) -> String? {
        guard id != 0, let t = type(id) else { return nil }
        let i = id & 0xFFFF
        guard let list = tables[t], i < list.count else { return nil }
        return list[i]
    }
}

// MARK: - 언어

/// java.util.Locale 의 필요한 만큼. 이름이 Foundation.Locale 과 겹쳐 JLocale.
struct JLocale: Equatable {
    let language: String
    let country: String
    init(_ language: String, _ country: String = "") { self.language = language; self.country = country }

    static let KOREA = JLocale("ko", "KR"), KOREAN = JLocale("ko")
    static let US = JLocale("en", "US"), ENGLISH = JLocale("en"), UK = JLocale("en", "GB")
    static let JAPAN = JLocale("ja", "JP"), JAPANESE = JLocale("ja")
    static let CHINA = JLocale("zh", "CN"), TAIWAN = JLocale("zh", "TW")
    static let ROOT = JLocale("")

    /// 앱 안에서 고른 언어가 있으면 그것, 없으면 기기 언어(안드로이드 AppCompat 과 같은 동작).
    static func getDefault() -> JLocale { AppLocales.effective }
    static func forLanguageTag(_ tag: String) -> JLocale {
        let p = tag.replacingOccurrences(of: "_", with: "-").split(separator: "-").map(String.init)
        guard let lang = p.first else { return ROOT }
        let country = p.dropFirst().first { $0.count == 2 } ?? ""
        return JLocale(lang.lowercased(), country.uppercased())
    }
    func toLanguageTag() -> String { country.isEmpty ? language : "\(language)-\(country)" }
    func getLanguage() -> String { language }
    var displayLanguage: String { Foundation.Locale(identifier: "en").localizedString(forLanguageCode: language) ?? language }
    func getDisplayName(_ inLocale: JLocale) -> String {
        Foundation.Locale(identifier: inLocale.toLanguageTag()).localizedString(forIdentifier: toLanguageTag()) ?? toLanguageTag()
    }
    var foundation: Foundation.Locale { Foundation.Locale(identifier: country.isEmpty ? language : "\(language)_\(country)") }
}

/// AppCompatDelegate.setApplicationLocales 의 아이폰판 — 고른 언어를 저장하고 리소스를 다시 읽는다.
enum AppLocales {
    private static let key = "droid.app_locale"

    /// 앱 안에서 고른 언어 태그("" = 기기 설정을 따름)
    static var picked: String {
        get { UserDefaults.standard.string(forKey: key) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// 기기 언어를 안드로이드 Locale 로 (zh-Hant-TW → zh-TW, zh-Hans → zh-CN, id → in 은 폴더에서만)
    static var system: JLocale {
        let pref = Foundation.Locale.preferredLanguages.first ?? "en"
        let fl = Foundation.Locale(identifier: pref)
        let lang = fl.language.languageCode?.identifier ?? "en"
        var country = fl.region?.identifier ?? ""
        if lang == "zh" {
            let script = fl.language.script?.identifier ?? ""
            if script == "Hant" && country != "HK" && country != "MO" { country = country.isEmpty ? "TW" : country }
            if script == "Hans" { country = "CN" }
        }
        return JLocale(lang, country)
    }

    static var effective: JLocale { picked.isEmpty ? system : JLocale.forLanguageTag(picked) }

    /// AppCompatDelegate.setApplicationLocales — 바꾼 뒤 화면을 처음부터 다시 띄운다(안드로이드 recreate).
    static func set(_ tag: String) {
        picked = tag
        Res.shared.reload()
        DroidHost.shared.recreateAll()
    }
}

/// LocaleListCompat / AppCompatDelegate 를 그대로 부르는 코드를 위해
enum LocaleListCompat {
    static func forLanguageTags(_ tags: String) -> LocaleList { LocaleList(tags: tags) }
    static func getEmptyLocaleList() -> LocaleList { LocaleList(tags: "") }
}
struct LocaleList {
    let tags: String
    var isEmpty: Bool { tags.isEmpty }
    func size() -> Int { tags.isEmpty ? 0 : tags.split(separator: ",").count }
    func get(_ i: Int) -> JLocale? { isEmpty ? nil : JLocale.forLanguageTag(String(tags.split(separator: ",")[i])) }
    func toLanguageTags() -> String { tags }
}
enum AppCompatDelegate {
    static func getApplicationLocales() -> LocaleList { LocaleList(tags: AppLocales.picked) }
    static func setApplicationLocales(_ l: LocaleList) { AppLocales.set(l.tags) }
}

// MARK: - 리소스 표

final class Res {
    static let shared = Res()

    /// 번들 안 안드로이드 res 폴더
    let root: URL = Bundle.main.bundleURL.appendingPathComponent("res")

    private(set) var strings: [String: String] = [:]
    private(set) var arrays: [String: [String]] = [:]
    private(set) var colors: [String: String] = [:]
    private(set) var dimens: [String: String] = [:]
    private var drawableFiles: [String: URL] = [:]
    private var imageCache: [String: UIImage] = [:]

    private init() { reload() }

    /// 지금 언어에 맞는 values 폴더 순서 (뒤의 것이 앞의 것을 덮어쓴다)
    func valueFolders() -> [String] {
        let loc = AppLocales.effective
        var lang = loc.language
        if lang == "id" { lang = "in" }      // 안드로이드 폴더 이름은 옛 코드 in
        var folders = ["values"]
        if FileManager.default.fileExists(atPath: root.appendingPathComponent("values-\(lang)").path) {
            folders.append("values-\(lang)")
        }
        if !loc.country.isEmpty {
            let f = "values-\(lang)-r\(loc.country)"
            if FileManager.default.fileExists(atPath: root.appendingPathComponent(f).path) { folders.append(f) }
            else if lang == "zh" && loc.country == "MO",
                    FileManager.default.fileExists(atPath: root.appendingPathComponent("values-zh-rHK").path) {
                folders.append("values-zh-rHK")
            }
        }
        return folders
    }

    func reload() {
        strings = [:]; arrays = [:]; colors = [:]; dimens = [:]
        for folder in valueFolders() {
            let dir = root.appendingPathComponent(folder)
            guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for f in files where f.pathExtension == "xml" { parseValues(f) }
        }
        if drawableFiles.isEmpty {
            for folder in ["drawable", "drawable-nodpi", "mipmap-xxxhdpi", "mipmap-anydpi-v26"] {
                let dir = root.appendingPathComponent(folder)
                guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
                for f in files {
                    let name = f.deletingPathExtension().lastPathComponent
                    // 같은 이름이면 XML 보다 그림 파일을, mipmap 보다 drawable 을 먼저
                    if drawableFiles[name] == nil || (drawableFiles[name]!.pathExtension == "xml" && f.pathExtension != "xml") {
                        drawableFiles[name] = f
                    }
                }
            }
        }
    }

    private func parseValues(_ url: URL) {
        guard let node = XmlNode.parse(url) else { return }
        for c in node.children {
            guard let name = c.attrs["name"] else { continue }
            switch c.tag {
            case "string": strings[name] = Res.decodeAndroidString(c.innerXml)
            case "string-array":
                arrays[name] = c.children.filter { $0.tag == "item" }.map { Res.decodeAndroidString($0.innerXml) }
            case "color": colors[name] = c.text.trim()
            case "dimen": dimens[name] = c.text.trim()
            default: break
            }
        }
    }

    /// strings.xml 값 → 화면 문자열 (따옴표·역슬래시·공백 규칙과 꺾쇠 태그 제거는 안드로이드 aapt 와 같게)
    static func decodeAndroidString(_ raw: String) -> String {
        // raw 는 XML 파서가 엔티티를 풀고 서식 태그(<b> 등)를 뗀 글자다 — getString 도 태그를 버린다
        let s = raw
        var out = ""
        var inQuote = false
        var lastSpace = false
        var it = Array(s)
        var i = 0
        while i < it.count {
            let c = it[i]
            if c == "\\" && i + 1 < it.count {
                let n = it[i + 1]
                switch n {
                case "n": out.append("\n")
                case "t": out.append("\t")
                case "u":
                    if i + 5 < it.count, let v = UInt32(String(it[(i + 2)...(i + 5)]), radix: 16), let sc = Unicode.Scalar(v) {
                        out.unicodeScalars.append(sc); i += 4
                    }
                default: out.append(n)
                }
                i += 2; lastSpace = false; continue
            }
            if c == "\"" { inQuote.toggle(); i += 1; continue }
            if !inQuote && (c == " " || c == "\n" || c == "\t" || c == "\r") {
                if !lastSpace { out.append(" ") }
                lastSpace = true; i += 1; continue
            }
            out.append(c); lastSpace = false; i += 1
        }
        it = []
        return inQuote ? out : out.trimmingCharacters(in: .whitespaces)
    }

    // MARK: 값

    func string(_ id: Int) -> String {
        guard let n = ResNames.name(id) else { return "" }
        return strings[n] ?? ""
    }
    func stringArray(_ id: Int) -> [String] {
        guard let n = ResNames.name(id) else { return [] }
        return arrays[n] ?? []
    }

    /// "@color/x" · "#RRGGBB" · "@android:color/white"
    func colorValue(_ ref: String) -> Int? {
        let r = ref.trim()
        if r.hasPrefix("#") { return Color.parseColor(r) }
        if r.hasPrefix("@android:color/") {
            switch r.dropFirst(15) {
            case "white": return Color.WHITE
            case "black": return Color.BLACK
            case "transparent": return Color.TRANSPARENT
            default: return nil
            }
        }
        if r.hasPrefix("@color/") {
            let n = String(r.dropFirst(7))
            guard let v = colors[n] else { return nil }
            return colorValue(v)
        }
        return nil
    }
    func color(_ id: Int) -> Int {
        guard let n = ResNames.name(id), let v = colors[n] else { return Color.BLACK }
        return colorValue(v) ?? Color.BLACK
    }

    /// "16dp" · "14sp" · "@dimen/x" → pt
    func dimenValue(_ ref: String) -> Float? {
        let r = ref.trim()
        if r.hasPrefix("@dimen/") {
            guard let v = dimens[String(r.dropFirst(7))] else { return nil }
            return dimenValue(v)
        }
        for unit in ["dip", "dp", "sp", "px", "pt"] where r.hasSuffix(unit) {
            guard let v = Float(r.dropLast(unit.count)) else { return nil }
            return unit == "px" ? v / Float(UIScreen.main.scale) : v
        }
        return Float(r)
    }
    func dimension(_ id: Int) -> Float {
        guard let n = ResNames.name(id), let v = dimens[n] else { return 0 }
        return dimenValue(v) ?? 0
    }

    /// "@string/x" 나 글자 그대로
    func text(_ ref: String) -> String {
        if ref.hasPrefix("@string/") { return strings[String(ref.dropFirst(8))] ?? "" }
        if ref.hasPrefix("@android:string/") {
            switch ref.dropFirst(16) { case "ok": return "OK"; case "cancel": return "Cancel"; default: return "" }
        }
        return Res.decodeAndroidString(ref)
    }

    // MARK: 그림

    func image(named name: String) -> UIImage? {
        if let c = imageCache[name] { return c }
        guard let url = drawableFiles[name], url.pathExtension != "xml",
              let data = try? Data(contentsOf: url) else { return nil }
        // nodpi 그림은 안드로이드에서 px 그대로다 — 보통 폰(약 3배)과 비슷하게 3배로 본다
        let scale: CGFloat = 3
        guard let img = UIImage(data: data, scale: scale) else { return nil }
        imageCache[name] = img
        return img
    }

    func drawable(named name: String) -> Drawable? {
        guard let url = drawableFiles[name] else { return nil }
        if url.pathExtension != "xml" {
            guard let img = image(named: name) else { return nil }
            return BitmapDrawable(img)
        }
        guard let node = XmlNode.parse(url) else { return nil }
        return Drawables.fromXml(node)
    }
    func drawable(_ id: Int) -> Drawable? {
        guard let n = ResNames.name(id) else { return nil }
        return drawable(named: n)
    }
    /// "@drawable/x" · "@mipmap/x" · "@color/x" · "#..."
    func drawableRef(_ ref: String) -> Drawable? {
        if ref.hasPrefix("@drawable/") { return drawable(named: String(ref.dropFirst(10))) }
        if ref.hasPrefix("@mipmap/") { return drawable(named: String(ref.dropFirst(8))) }
        if let c = colorValue(ref) { return ColorDrawable(c) }
        return nil
    }
    func hasDrawable(_ name: String) -> Bool { drawableFiles[name] != nil }

    /// res/raw 파일 주소 (소리 등) — 아이폰용 사본(m4a)이 있으면 그것
    func rawURL(_ id: Int) -> URL? {
        guard let n = ResNames.name(id) else { return nil }
        for ext in ["m4a", "caf", "mp3", "wav", "ogg"] {
            let u = Bundle.main.bundleURL.appendingPathComponent("sound/\(n).\(ext)")
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        return nil
    }

    func layoutXml(_ id: Int) -> XmlNode? {
        guard let n = ResNames.name(id) else { return nil }
        return layoutCache[n] ?? {
            let node = XmlNode.parse(root.appendingPathComponent("layout/\(n).xml"))
            layoutCache[n] = node
            return node
        }()
    }
    private var layoutCache: [String: XmlNode] = [:]
}

// MARK: - XML

/// 작은 DOM. 안드로이드 리소스 XML 만 읽는다.
final class XmlNode {
    let tag: String
    var attrs: [String: String]
    var children: [XmlNode] = []
    var text: String = ""
    /// 자식 태그 안의 글자까지 이은 것(문자열 리소스의 <b> 안 글자 포함)
    var innerXml: String = ""

    init(tag: String, attrs: [String: String]) { self.tag = tag; self.attrs = attrs }

    /// "android:layout_width" → "layout_width" 처럼 이름공간을 뗀 값도 찾는다
    func attr(_ name: String) -> String? { attrs["android:" + name] ?? attrs["app:" + name] ?? attrs[name] }

    static func parse(_ url: URL) -> XmlNode? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parse(data)
    }
    static func parse(_ data: Data) -> XmlNode? {
        let d = Delegate(raw: String(decoding: data, as: UTF8.self))
        let p = XMLParser(data: data)
        p.delegate = d
        p.shouldProcessNamespaces = false
        _ = p.parse()
        return d.root
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var root: XmlNode?
        var stack: [XmlNode] = []
        init(raw: String) {}

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
            let n = XmlNode(tag: name, attrs: attributes)
            if let top = stack.last { top.children.append(n) }
            stack.append(n)
            if root == nil { root = n }
        }
        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            _ = stack.popLast()
        }
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            stack.last?.text += string
            for n in stack { n.innerXml += string }
        }
        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            let s = String(decoding: CDATABlock, as: UTF8.self)
            stack.last?.text += s
            for n in stack { n.innerXml += s }
        }
    }
}

// MARK: - Drawable

class Drawable {
    let bounds = Rect()
    var alpha: Int = 255 { didSet { invalidateSelf() } }
    weak var callback: View?
    var tintColor: Int? = nil

    func setBounds(_ l: Int, _ t: Int, _ r: Int, _ b: Int) { bounds.set(l, t, r, b) }
    func setBounds(_ r: Rect) { bounds.set(r.left, r.top, r.right, r.bottom) }
    func getBounds() -> Rect { bounds }
    var intrinsicWidth: Int { -1 }
    var intrinsicHeight: Int { -1 }
    func mutate() -> Drawable { self }
    func setTint(_ c: Int) { tintColor = c; invalidateSelf() }
    func setTintList(_ l: ColorStateList?) { tintColor = l?.defaultColor; invalidateSelf() }
    func invalidateSelf() { callback?.invalidate() }

    /// 그린다(bounds 안에)
    func draw(_ canvas: Canvas) {}
}

final class ColorDrawable: Drawable {
    var color: Int
    init(_ color: Int) { self.color = color }
    override func draw(_ canvas: Canvas) {
        let p = Paint(); p.color = tintColor ?? color
        p.alpha = Color.alpha(p.color) * alpha / 255
        canvas.drawRect(bounds.cg.androidRectF, p)
    }
}

final class BitmapDrawable: Drawable {
    let image: UIImage
    var explicitSize: CGSize? = nil
    init(_ image: UIImage) { self.image = image }
    override var intrinsicWidth: Int { Int((explicitSize?.width ?? image.size.width).rounded()) }
    override var intrinsicHeight: Int { Int((explicitSize?.height ?? image.size.height).rounded()) }
    override func draw(_ canvas: Canvas) {
        var img = image
        if let t = tintColor { img = image.withTintColor(Color.ui(t), renderingMode: .alwaysOriginal) }
        canvas.drawUIImage(img, bounds.cg, alpha: CGFloat(alpha) / 255)
    }
}

final class GradientDrawable: Drawable {
    static let RECTANGLE = 0, OVAL = 1, LINE = 2, RING = 3
    enum Orientation { case TOP_BOTTOM, TR_BL, RIGHT_LEFT, BR_TL, BOTTOM_TOP, BL_TR, LEFT_RIGHT, TL_BR }

    var shape = GradientDrawable.RECTANGLE
    var fillColor: Int? = nil
    var colors: [Int]? = nil
    var orientation: Orientation = .TOP_BOTTOM
    var cornerRadius: Float = 0
    var cornerRadii: [Float]? = nil
    var strokeWidth: Float = 0
    var strokeColor: Int = 0
    var dashWidth: Float = 0, dashGap: Float = 0
    var sizeW = -1, sizeH = -1

    override init() {}
    init(_ orientation: Orientation, _ colors: [Int]) { self.orientation = orientation; self.colors = colors }

    func setColor(_ c: Int) { fillColor = c; colors = nil; invalidateSelf() }
    func setColor(_ l: ColorStateList?) { fillColor = l?.defaultColor; colors = nil; invalidateSelf() }
    func setColors(_ cs: [Int]) { colors = cs; invalidateSelf() }
    func setCornerRadius(_ r: Float) { cornerRadius = r; cornerRadii = nil; invalidateSelf() }
    func setCornerRadii(_ r: [Float]) { cornerRadii = r; invalidateSelf() }
    func setStroke(_ width: Int, _ color: Int) { strokeWidth = Float(width); strokeColor = color; invalidateSelf() }
    func setStroke(_ width: Float, _ color: Int) { strokeWidth = width; strokeColor = color; invalidateSelf() }
    func setStroke(_ width: Int, _ color: Int, _ dashWidth: Float, _ dashGap: Float) {
        strokeWidth = Float(width); strokeColor = color; self.dashWidth = dashWidth; self.dashGap = dashGap; invalidateSelf()
    }
    func setShape(_ s: Int) { shape = s; invalidateSelf() }
    func setSize(_ w: Int, _ h: Int) { sizeW = w; sizeH = h }
    func setOrientation(_ o: Orientation) { orientation = o }
    override var intrinsicWidth: Int { sizeW }
    override var intrinsicHeight: Int { sizeH }

    func path(in r: CGRect) -> CGPath {
        if shape == GradientDrawable.OVAL { return CGPath(ellipseIn: r, transform: nil) }
        if let radii = cornerRadii, radii.count >= 8 { return Path.roundRectPath(r, radii.map { CGFloat($0) }) }
        let cr = min(CGFloat(cornerRadius), min(r.width, r.height) / 2)
        if cr <= 0 { return CGPath(rect: r, transform: nil) }
        return CGPath(roundedRect: r, cornerWidth: cr, cornerHeight: cr, transform: nil)
    }

    override func draw(_ canvas: Canvas) {
        let ctx = canvas.ctx
        let full = bounds.cg
        guard full.width > 0, full.height > 0 else { return }
        let inset = CGFloat(strokeWidth) / 2
        let r = full.insetBy(dx: inset, dy: inset)
        let a = CGFloat(alpha) / 255
        ctx.saveGState()
        ctx.setAlpha(a)
        if let cs = colors, cs.count >= 2, tintColor == nil {
            ctx.saveGState()
            ctx.addPath(path(in: r)); ctx.clip()
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cs.map { Color.cg($0) } as CFArray, locations: nil)!
            let (s, e) = endpoints(full)
            ctx.drawLinearGradient(g, start: s, end: e, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            ctx.restoreGState()
        } else if let c = tintColor ?? fillColor ?? colors?.first {
            ctx.addPath(path(in: r))
            ctx.setFillColor(Color.cg(c))
            ctx.fillPath()
        }
        if strokeWidth > 0 {
            ctx.addPath(path(in: r))
            ctx.setStrokeColor(Color.cg(tintColor ?? strokeColor))
            ctx.setLineWidth(CGFloat(strokeWidth))
            if dashWidth > 0 { ctx.setLineDash(phase: 0, lengths: [CGFloat(dashWidth), CGFloat(dashGap)]) }
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    private func endpoints(_ r: CGRect) -> (CGPoint, CGPoint) {
        switch orientation {
        case .TOP_BOTTOM: return (CGPoint(x: r.midX, y: r.minY), CGPoint(x: r.midX, y: r.maxY))
        case .BOTTOM_TOP: return (CGPoint(x: r.midX, y: r.maxY), CGPoint(x: r.midX, y: r.minY))
        case .LEFT_RIGHT: return (CGPoint(x: r.minX, y: r.midY), CGPoint(x: r.maxX, y: r.midY))
        case .RIGHT_LEFT: return (CGPoint(x: r.maxX, y: r.midY), CGPoint(x: r.minX, y: r.midY))
        case .TL_BR: return (CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY))
        case .BR_TL: return (CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.minY))
        case .TR_BL: return (CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.minX, y: r.maxY))
        case .BL_TR: return (CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.minY))
        }
    }
}

/// layer-list
final class LayerDrawable: Drawable {
    struct Layer {
        let drawable: Drawable
        var width = -1, height = -1
        var left: Float = 0, top: Float = 0, right: Float = 0, bottom: Float = 0
        var gravity = 0
    }
    var layers: [Layer]
    init(_ layers: [Layer]) { self.layers = layers }
    convenience init(_ drawables: [Drawable]) { self.init(drawables.map { Layer(drawable: $0) }) }

    override var intrinsicWidth: Int {
        layers.map { l in (l.width >= 0 ? l.width : l.drawable.intrinsicWidth) + Int(l.left + l.right) }.max() ?? -1
    }
    override var intrinsicHeight: Int {
        layers.map { l in (l.height >= 0 ? l.height : l.drawable.intrinsicHeight) + Int(l.top + l.bottom) }.max() ?? -1
    }
    override func draw(_ canvas: Canvas) {
        for l in layers {
            var r = CGRect(x: CGFloat(bounds.left) + CGFloat(l.left), y: CGFloat(bounds.top) + CGFloat(l.top),
                           width: CGFloat(bounds.width()) - CGFloat(l.left + l.right),
                           height: CGFloat(bounds.height()) - CGFloat(l.top + l.bottom))
            if l.width >= 0 || l.height >= 0 {
                let w = l.width >= 0 ? CGFloat(l.width) : r.width, h = l.height >= 0 ? CGFloat(l.height) : r.height
                r = CGRect(x: r.midX - w / 2, y: r.midY - h / 2, width: w, height: h)
            }
            l.drawable.setBounds(Int(r.minX.rounded()), Int(r.minY.rounded()), Int(r.maxX.rounded()), Int(r.maxY.rounded()))
            l.drawable.alpha = alpha
            if let t = tintColor { l.drawable.tintColor = t }
            l.drawable.draw(canvas)
        }
    }
}

/// animation-list / 코드에서 만드는 AnimationDrawable
final class AnimationDrawable: Drawable {
    private(set) var frames: [(Drawable, Int)] = []
    var isOneShot = false
    private var index = 0
    private var timer: Timer?

    func addFrame(_ d: Drawable, _ duration: Int) { frames.append((d, duration)) }
    override var intrinsicWidth: Int { frames.first?.0.intrinsicWidth ?? -1 }
    override var intrinsicHeight: Int { frames.first?.0.intrinsicHeight ?? -1 }
    var isRunning: Bool { timer != nil }

    func start() {
        stop()
        guard frames.count > 1 else { return }
        index = 0
        schedule()
    }
    private func schedule() {
        let d = Double(frames[index].1) / 1000
        timer = Timer.scheduledTimer(withTimeInterval: d, repeats: false) { [weak self] _ in
            guard let self else { return }
            if self.index + 1 >= self.frames.count && self.isOneShot { self.timer = nil; return }
            self.index = (self.index + 1) % self.frames.count
            self.invalidateSelf()
            self.schedule()
        }
    }
    func stop() { timer?.invalidate(); timer = nil }
    func selectDrawable(_ i: Int) { index = i; invalidateSelf() }
    override func draw(_ canvas: Canvas) {
        guard !frames.isEmpty else { return }
        let d = frames[index].0
        d.setBounds(bounds); d.alpha = alpha
        d.draw(canvas)
    }
}

enum Drawables {
    static func fromXml(_ node: XmlNode) -> Drawable? {
        let res = Res.shared
        switch node.tag {
        case "shape":
            let g = GradientDrawable()
            switch node.attr("shape") { case "oval": g.shape = GradientDrawable.OVAL; case "line": g.shape = GradientDrawable.LINE; default: break }
            for c in node.children {
                switch c.tag {
                case "solid": g.fillColor = c.attr("color").flatMap { res.colorValue($0) }
                case "stroke":
                    g.strokeWidth = c.attr("width").flatMap { res.dimenValue($0) } ?? 0
                    g.strokeColor = c.attr("color").flatMap { res.colorValue($0) } ?? 0
                    g.dashWidth = c.attr("dashWidth").flatMap { res.dimenValue($0) } ?? 0
                    g.dashGap = c.attr("dashGap").flatMap { res.dimenValue($0) } ?? 0
                case "corners":
                    let r = c.attr("radius").flatMap { res.dimenValue($0) } ?? 0
                    let tl = c.attr("topLeftRadius").flatMap { res.dimenValue($0) }
                    let tr = c.attr("topRightRadius").flatMap { res.dimenValue($0) }
                    let bl = c.attr("bottomLeftRadius").flatMap { res.dimenValue($0) }
                    let br = c.attr("bottomRightRadius").flatMap { res.dimenValue($0) }
                    if tl != nil || tr != nil || bl != nil || br != nil {
                        let a = tl ?? r, b = tr ?? r, d = br ?? r, e = bl ?? r
                        g.cornerRadii = [a, a, b, b, d, d, e, e]
                    } else { g.cornerRadius = r }
                case "gradient":
                    var cs: [Int] = []
                    if let s = c.attr("startColor").flatMap({ res.colorValue($0) }) { cs.append(s) }
                    if let m = c.attr("centerColor").flatMap({ res.colorValue($0) }) { cs.append(m) }
                    if let e = c.attr("endColor").flatMap({ res.colorValue($0) }) { cs.append(e) }
                    g.colors = cs
                    switch Int(c.attr("angle") ?? "0") ?? 0 {
                    case 0: g.orientation = .LEFT_RIGHT
                    case 45: g.orientation = .BL_TR
                    case 90: g.orientation = .BOTTOM_TOP
                    case 135: g.orientation = .BR_TL
                    case 180: g.orientation = .RIGHT_LEFT
                    case 225: g.orientation = .TR_BL
                    case 270: g.orientation = .TOP_BOTTOM
                    default: g.orientation = .TL_BR
                    }
                case "size":
                    g.sizeW = Int(c.attr("width").flatMap { res.dimenValue($0) } ?? -1)
                    g.sizeH = Int(c.attr("height").flatMap { res.dimenValue($0) } ?? -1)
                default: break
                }
            }
            return g
        case "layer-list":
            let layers: [LayerDrawable.Layer] = node.children.filter { $0.tag == "item" }.compactMap { item in
                let d: Drawable? = item.attr("drawable").flatMap { res.drawableRef($0) } ?? item.children.first.flatMap { fromXml($0) }
                guard let d else { return nil }
                var l = LayerDrawable.Layer(drawable: d)
                l.width = Int(item.attr("width").flatMap { res.dimenValue($0) } ?? -1)
                l.height = Int(item.attr("height").flatMap { res.dimenValue($0) } ?? -1)
                l.left = item.attr("left").flatMap { res.dimenValue($0) } ?? 0
                l.top = item.attr("top").flatMap { res.dimenValue($0) } ?? 0
                l.right = item.attr("right").flatMap { res.dimenValue($0) } ?? 0
                l.bottom = item.attr("bottom").flatMap { res.dimenValue($0) } ?? 0
                return l
            }
            return LayerDrawable(layers)
        case "bitmap":
            return node.attr("src").flatMap { res.drawableRef($0) }
        case "selector":
            // 상태별 그림은 기본(상태 조건 없는 마지막 항목)만 쓴다
            let items = node.children.filter { $0.tag == "item" }
            let plain = items.last { !$0.attrs.keys.contains { $0.contains("state_") } } ?? items.last
            guard let p = plain else { return nil }
            return p.attr("drawable").flatMap { res.drawableRef($0) } ?? p.children.first.flatMap { fromXml($0) }
        case "animation-list":
            let a = AnimationDrawable()
            a.isOneShot = node.attr("oneshot") == "true"
            for it in node.children where it.tag == "item" {
                if let d = it.attr("drawable").flatMap({ res.drawableRef($0) }) { a.addFrame(d, Int(it.attr("duration") ?? "100") ?? 100) }
            }
            return a
        case "inset":
            guard let d = node.attr("drawable").flatMap({ res.drawableRef($0) }) else { return nil }
            var l = LayerDrawable.Layer(drawable: d)
            let all = node.attr("inset").flatMap { res.dimenValue($0) } ?? 0
            l.left = node.attr("insetLeft").flatMap { res.dimenValue($0) } ?? all
            l.top = node.attr("insetTop").flatMap { res.dimenValue($0) } ?? all
            l.right = node.attr("insetRight").flatMap { res.dimenValue($0) } ?? all
            l.bottom = node.attr("insetBottom").flatMap { res.dimenValue($0) } ?? all
            return LayerDrawable([l])
        case "color":
            return node.attr("color").flatMap { res.colorValue($0) }.map { ColorDrawable($0) }
        case "adaptive-icon":
            let bg = node.children.first { $0.tag == "background" }?.attr("drawable").flatMap { res.drawableRef($0) }
            let fg = node.children.first { $0.tag == "foreground" }?.attr("drawable").flatMap { res.drawableRef($0) }
            return LayerDrawable([bg, fg].compactMap { $0 })
        default:
            return nil
        }
    }
}

final class ColorStateList {
    let defaultColor: Int
    init(_ c: Int) { defaultColor = c }
    static func valueOf(_ c: Int) -> ColorStateList { ColorStateList(c) }
    func getDefaultColor() -> Int { defaultColor }
}

extension CGRect {
    var androidRectF: RectF { RectF(Float(minX), Float(minY), Float(maxX), Float(maxY)) }
}

// MARK: - Context / Resources

final class DisplayMetrics {
    let density: Float = 1
    let scaledDensity: Float = 1
    var densityDpi: Int { 160 }
    var widthPixels: Int { Int(UIScreen.main.bounds.width) }
    var heightPixels: Int { Int(UIScreen.main.bounds.height) }
}

final class Configuration {
    var fontScale: Float = 1
    var screenWidthDp: Int { Int(UIScreen.main.bounds.width) }
    var screenHeightDp: Int { Int(UIScreen.main.bounds.height) }
    var smallestScreenWidthDp: Int { Int(min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)) }
    var locales: LocaleList { LocaleList(tags: AppLocales.effective.toLanguageTag()) }
    var locale: JLocale { AppLocales.effective }
}

final class Resources {
    static let shared = Resources()
    let displayMetrics = DisplayMetrics()
    let configuration = Configuration()

    func getString(_ id: Int) -> String { Res.shared.string(id) }
    func getString(_ id: Int, _ args: Any...) -> String { JavaFormat.format(Res.shared.string(id), args) }
    func getText(_ id: Int) -> String { Res.shared.string(id) }
    func getStringArray(_ id: Int) -> [String] { Res.shared.stringArray(id) }
    func getColor(_ id: Int) -> Int { Res.shared.color(id) }
    func getColor(_ id: Int, _ theme: Any?) -> Int { Res.shared.color(id) }
    func getDimension(_ id: Int) -> Float { Res.shared.dimension(id) }
    func getDimensionPixelSize(_ id: Int) -> Int { Int(Res.shared.dimension(id).rounded()) }
    func getDrawable(_ id: Int) -> Drawable? { Res.shared.drawable(id) }
    func getDrawable(_ id: Int, _ theme: Any?) -> Drawable? { Res.shared.drawable(id) }
    /// 이름으로 리소스 번호 찾기 — 없으면 0
    func getIdentifier(_ name: String, _ type: String, _ pkg: String?) -> Int {
        guard let t = ResType.of(type) else { return 0 }
        let id = ResNames.id(t, name)
        if id == 0 && (t == .drawable || t == .mipmap), Res.shared.hasDrawable(name) {
            return ResNames.id(.drawable, name)
        }
        return id
    }
    func getResourceEntryName(_ id: Int) -> String { ResNames.name(id) ?? "" }
}

/// 안드로이드 Context. Activity 와 앱(AppContext)이 따른다.
protocol Context: AnyObject {}

extension Context {
    var resources: Resources { Resources.shared }
    func getResources() -> Resources { Resources.shared }
    var applicationContext: Context { AppContext.shared }
    var packageName: String { Bundle.main.bundleIdentifier ?? "" }
    func getString(_ id: Int) -> String { Res.shared.string(id) }
    func getString(_ id: Int, _ args: Any...) -> String { JavaFormat.format(Res.shared.string(id), args) }
    func getText(_ id: Int) -> String { Res.shared.string(id) }
    func getColor(_ id: Int) -> Int { Res.shared.color(id) }
    func getDrawable(_ id: Int) -> Drawable? { Res.shared.drawable(id) }
    var filesDir: URL { AppContext.filesDir }
    var assets: AssetManager { AssetManager.shared }
    var layoutInflater: LayoutInflater { LayoutInflater(self) }
}

final class AppContext: Context {
    static let shared = AppContext()
    static let filesDir: URL = {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("files")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()
}

enum ContextCompat {
    static func getColor(_ ctx: Context, _ id: Int) -> Int { Res.shared.color(id) }
    static func getDrawable(_ ctx: Context, _ id: Int) -> Drawable? { Res.shared.drawable(id) }
}

/// assets/ — 빌드 단계가 안드로이드 app/src/main/assets 를 번들 assets/ 로 복사한다.
final class AssetManager {
    static let shared = AssetManager()
    let root = Bundle.main.bundleURL.appendingPathComponent("assets")
    func open(_ path: String) -> InputStream { InputStream(url: root.appendingPathComponent(path)) }
    func readText(_ path: String) -> String {
        (try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)) ?? ""
    }
    func list(_ path: String) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent(path).path).sorted()) ?? []
    }
}

final class InputStream {
    let url: URL
    init(url: URL) { self.url = url }
    /// 코틀린 `bufferedReader().use { it.readText() }`
    func readText() -> String { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }
    func readBytes() -> Data { (try? Data(contentsOf: url)) ?? Data() }
}
