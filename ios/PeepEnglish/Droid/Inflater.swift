import UIKit

// 안드로이드 레이아웃 XML(res/layout/*.xml)을 그대로 읽어 화면을 만든다.
// 이 앱이 쓰는 태그·속성만 안다(LinearLayout·FrameLayout·ScrollView·GridLayout·TextView·Button…).

final class LayoutInflater {
    let context: Context
    init(_ context: Context) { self.context = context }
    static func from(_ context: Context) -> LayoutInflater { LayoutInflater(context) }

    /// 직접 만든 화면 부품(com.piyak.english.ui.ChickView 등) — Gen/Bindings.swift 가 채운다
    static var customViews: [String: (Context) -> View] = [:]

    func inflate(_ layoutId: Int, _ root: ViewGroup?, _ attachToRoot: Bool = false) -> View {
        guard let node = Res.shared.layoutXml(layoutId) else { fatalError("레이아웃 없음: \(ResNames.name(layoutId) ?? "\(layoutId)")") }
        let v = build(node, parent: root)
        if attachToRoot, let r = root { r.addView(v) }
        return v
    }

    private func build(_ node: XmlNode, parent: ViewGroup?) -> View {
        let v = make(node.tag)
        let lp = makeLayoutParams(for: parent, node)
        v.layoutParams = lp
        apply(node, to: v)
        if let g = v as? ViewGroup {
            for c in node.children where c.tag != "requestFocus" {
                let child = build(c, parent: g)
                g.addView(child, child.layoutParams!)
            }
        }
        return v
    }

    private func make(_ tag: String) -> View {
        switch tag {
        case "LinearLayout": return LinearLayout(context)
        case "FrameLayout": return FrameLayout(context)
        case "ScrollView", "androidx.core.widget.NestedScrollView": return ScrollView(context)
        case "GridLayout", "androidx.gridlayout.widget.GridLayout": return GridLayout(context)
        case "TextView", "androidx.appcompat.widget.AppCompatTextView", "com.google.android.material.textview.MaterialTextView":
            return TextView(context)
        case "Button", "com.google.android.material.button.MaterialButton": return Button(context, nil, style: .material)
        case "androidx.appcompat.widget.AppCompatButton": return Button(context, nil, style: .appcompat)
        case "ImageView", "androidx.appcompat.widget.AppCompatImageView", "ImageButton": return ImageView(context)
        case "EditText", "androidx.appcompat.widget.AppCompatEditText": return EditText(context)
        case "ProgressBar": return ProgressBar(context)
        case "SeekBar": return SeekBar(context)
        case "com.google.android.material.switchmaterial.SwitchMaterial", "Switch", "androidx.appcompat.widget.SwitchCompat", "CheckBox":
            return CompoundButton(context)
        case "Space": return Space(context)
        case "View": return View(context)
        default:
            if let f = LayoutInflater.customViews[tag] { return f(context) }
            fatalError("레이아웃 태그를 모름: \(tag)")
        }
    }

    private func dim(_ s: String?) -> Int? {
        guard let s else { return nil }
        switch s {
        case "match_parent", "fill_parent": return BaseLayoutParams.MATCH_PARENT
        case "wrap_content": return BaseLayoutParams.WRAP_CONTENT
        default: return Res.shared.dimenValue(s).map { Int($0.rounded()) }
        }
    }

    private func makeLayoutParams(for parent: ViewGroup?, _ n: XmlNode) -> BaseLayoutParams {
        let w = dim(n.attr("layout_width")) ?? BaseLayoutParams.WRAP_CONTENT
        let h = dim(n.attr("layout_height")) ?? BaseLayoutParams.WRAP_CONTENT
        let lp: DroidMarginLayoutParams
        switch parent {
        case is LinearLayout:
            let l = LinearLayout.LayoutParams(w, h)
            if let wt = n.attr("layout_weight").flatMap({ Float($0) }) { l.weight = wt }
            if let g = n.attr("layout_gravity") { l.gravity = Gravity.parse(g) }
            lp = l
        case is GridLayout:
            let g = GridLayout.LayoutParams(w, h)
            if let gr = n.attr("layout_gravity") { g.gravity = Gravity.parse(gr) }
            if let c = n.attr("layout_column").flatMap({ Int($0) }) { g.columnSpec.start = c }
            if let c = n.attr("layout_columnSpan").flatMap({ Int($0) }) { g.columnSpec.size = c }
            if let c = n.attr("layout_columnWeight").flatMap({ Float($0) }) { g.columnSpec.weight = c }
            if let r = n.attr("layout_row").flatMap({ Int($0) }) { g.rowSpec.start = r }
            lp = g
        default:
            let f = FrameLayout.LayoutParams(w, h)
            if let g = n.attr("layout_gravity") { f.gravity = Gravity.parse(g) }
            lp = f
        }
        let m = dim(n.attr("layout_margin"))
        let mh = dim(n.attr("layout_marginHorizontal")), mv = dim(n.attr("layout_marginVertical"))
        lp.leftMargin = dim(n.attr("layout_marginStart")) ?? dim(n.attr("layout_marginLeft")) ?? mh ?? m ?? 0
        lp.rightMargin = dim(n.attr("layout_marginEnd")) ?? dim(n.attr("layout_marginRight")) ?? mh ?? m ?? 0
        lp.topMargin = dim(n.attr("layout_marginTop")) ?? mv ?? m ?? 0
        lp.bottomMargin = dim(n.attr("layout_marginBottom")) ?? mv ?? m ?? 0
        return lp
    }

    private func apply(_ n: XmlNode, to v: View) {
        let res = Res.shared
        if let id = n.attr("id") {
            let name = id.replacingOccurrences(of: "@+id/", with: "").replacingOccurrences(of: "@id/", with: "")
            v.id = ResNames.id(.id, name)
        }
        // 여백
        let p = dim(n.attr("padding"))
        let ph = dim(n.attr("paddingHorizontal")), pv = dim(n.attr("paddingVertical"))
        let defaults = (v.paddingLeft, v.paddingTop, v.paddingRight, v.paddingBottom)
        let hasPad = [n.attr("padding"), n.attr("paddingHorizontal"), n.attr("paddingVertical"), n.attr("paddingStart"), n.attr("paddingLeft"),
                      n.attr("paddingEnd"), n.attr("paddingRight"), n.attr("paddingTop"), n.attr("paddingBottom")].contains { $0 != nil }
        if hasPad {
            v.setPadding(dim(n.attr("paddingStart")) ?? dim(n.attr("paddingLeft")) ?? ph ?? p ?? defaults.0,
                         dim(n.attr("paddingTop")) ?? pv ?? p ?? defaults.1,
                         dim(n.attr("paddingEnd")) ?? dim(n.attr("paddingRight")) ?? ph ?? p ?? defaults.2,
                         dim(n.attr("paddingBottom")) ?? pv ?? p ?? defaults.3)
        }
        if let vis = n.attr("visibility") { v.visibility = vis == "gone" ? View.GONE : vis == "invisible" ? View.INVISIBLE : View.VISIBLE }
        if let bg = n.attr("background") {
            if bg.hasPrefix("?") { v.background = nil } else { v.background = res.drawableRef(bg) }
        }
        if let t = n.attr("backgroundTint") {
            v.backgroundTintList = t == "@null" ? nil : res.colorValue(t).map { ColorStateList($0) }
        }
        if let mw = dim(n.attr("minWidth")) { v.minimumWidth = mw }
        if let mh = dim(n.attr("minHeight")) { v.minimumHeight = mh }
        if let c = n.attr("clickable") { v.isClickable = c == "true" }
        if let d = n.attr("contentDescription") { v.contentDescription = res.text(d) }
        if let a = n.attr("alpha").flatMap({ Float($0) }) { v.alphaF = a }
        if let e = dim(n.attr("elevation")) { v.elevation = Float(e) }
        if let c = n.attr("clipChildren") { (v as? ViewGroup)?.clipChildren = c == "true" }
        if let c = n.attr("clipToPadding") { (v as? ViewGroup)?.clipToPadding = c == "true" }

        if let ll = v as? LinearLayout {
            if let o = n.attr("orientation") { ll.orientation = o == "vertical" ? LinearLayout.VERTICAL : LinearLayout.HORIZONTAL }
            if let g = n.attr("gravity") { ll.gravity = Gravity.parse(g) }
            if let b = n.attr("baselineAligned") { ll.isBaselineAligned = b == "true" }
            if let ws = n.attr("weightSum").flatMap({ Float($0) }) { ll.weightSum = ws }
        }
        if let sv = v as? ScrollView {
            if let f = n.attr("fillViewport") { sv.isFillViewport = f == "true" }
            if n.attr("scrollbars") == "none" { sv.isVerticalScrollBarEnabled = false }
        }
        if let gl = v as? GridLayout, let c = n.attr("columnCount").flatMap({ Int($0) }) { gl.columnCount = c }

        if let tv = v as? TextView { applyText(n, tv) }
        if let iv = v as? ImageView {
            if let s = n.attr("src") { iv.setImageDrawable(res.drawableRef(s)) }
            if let st = n.attr("scaleType") {
                switch st {
                case "centerCrop": iv.scaleType = .CENTER_CROP
                case "centerInside": iv.scaleType = .CENTER_INSIDE
                case "fitXY": iv.scaleType = .FIT_XY
                case "center": iv.scaleType = .CENTER
                case "fitStart": iv.scaleType = .FIT_START
                case "fitEnd": iv.scaleType = .FIT_END
                default: iv.scaleType = .FIT_CENTER
                }
            }
            if n.attr("adjustViewBounds") == "true" { iv.adjustViewBounds = true }
            if let t = n.attr("tint").flatMap({ res.colorValue($0) }) { iv.imageTintList = ColorStateList(t) }
        }
        if let pb = v as? ProgressBar {
            if let m = n.attr("max").flatMap({ Int($0) }) { pb.max = m }
            if let pr = n.attr("progress").flatMap({ Int($0) }) { pb.progress = pr }
            if let t = n.attr("progressTint").flatMap({ res.colorValue($0) }) { pb.progressTintList = ColorStateList(t) }
            if let t = n.attr("progressBackgroundTint").flatMap({ res.colorValue($0) }) { pb.progressBackgroundTintList = ColorStateList(t) }
            if let h = dim(n.attr("minHeight")) { pb.minimumHeight = h }
        }
    }

    private func applyText(_ n: XmlNode, _ tv: TextView) {
        let res = Res.shared
        if let t = n.attr("text") { tv.text = res.text(t) }
        if let s = n.attr("textSize").flatMap({ res.dimenValue($0) }) { tv.textSize = s }
        if let c = n.attr("textColor").flatMap({ res.colorValue($0) }) { tv.setTextColor(c) }
        if let g = n.attr("gravity") { tv.gravity = Gravity.parse(g) }
        if let st = n.attr("textStyle") {
            var style = 0
            if st.contains("bold") { style |= Typeface.BOLD }
            if st.contains("italic") { style |= Typeface.ITALIC }
            tv.setTypeface(tv.typeface, style)
        }
        if let ff = n.attr("fontFamily") { tv.typeface = Typeface(family: ff, style: tv.typeface?.style ?? 0) }
        if let m = n.attr("maxLines").flatMap({ Int($0) }) { tv.maxLines = m }
        if let m = n.attr("minLines").flatMap({ Int($0) }) { tv.minLines = m }
        if let l = n.attr("lines").flatMap({ Int($0) }) { tv.setLines(l) }
        if n.attr("singleLine") == "true" { tv.isSingleLine = true }
        if let mh = dim(n.attr("maxHeight")) { tv.maxHeight = mh }
        if let e = n.attr("ellipsize") {
            switch e { case "end": tv.ellipsize = .END; case "start": tv.ellipsize = .START; case "middle": tv.ellipsize = .MIDDLE; case "marquee": tv.ellipsize = .MARQUEE; default: break }
        }
        if let m = n.attr("lineSpacingMultiplier").flatMap({ Float($0) }) { tv.setLineSpacing(tv.lineSpacingExtra, m) }
        if let e = dim(n.attr("lineSpacingExtra")) { tv.setLineSpacing(Float(e), tv.lineSpacingMultiplier) }
        if let ls = n.attr("letterSpacing").flatMap({ Float($0) }) { tv.letterSpacing = ls }
        if let h = n.attr("hint") { tv.hint = res.text(h) }
        if let hc = n.attr("textColorHint").flatMap({ res.colorValue($0) }) { tv.hintTextColor = hc }
        if let caps = n.attr("textAllCaps") { tv.isAllCaps = caps == "true" }
        if let pad = dim(n.attr("drawablePadding")) { tv.compoundDrawablePadding = pad }
        let ds = n.attr("drawableStart") ?? n.attr("drawableLeft"), de = n.attr("drawableEnd") ?? n.attr("drawableRight")
        let dt = n.attr("drawableTop"), db = n.attr("drawableBottom")
        if ds != nil || de != nil || dt != nil || db != nil {
            tv.setCompoundDrawablesRelativeWithIntrinsicBounds(ds.flatMap { res.drawableRef($0) }, dt.flatMap { res.drawableRef($0) },
                                                               de.flatMap { res.drawableRef($0) }, db.flatMap { res.drawableRef($0) })
        }
        if let t = n.attr("drawableTint"), t != "@null", let c = res.colorValue(t) { tv.compoundDrawableTint = c }
        if n.attr("autoSizeTextType") == "uniform" {
            let mn = n.attr("autoSizeMinTextSize").flatMap { res.dimenValue($0) } ?? 12
            let mx = n.attr("autoSizeMaxTextSize").flatMap { res.dimenValue($0) } ?? 112
            tv.setAutoSizeTextTypeUniformWithConfiguration(Int(mn), Int(mx), 1, TypedValue.COMPLEX_UNIT_SP)
        }
        if n.attr("scrollbars") == "vertical" && tv.maxLines != Int.max && !(tv is EditText) {
            // maxLines + scrollbars 는 코드에서 movementMethod 를 걸어야 스크롤된다 — 안드로이드와 같게 둔다
        }
        if let b = tv as? Button {
            // Material 아이콘·글자 버튼: 배경 없이 colorPrimary 글자
            if let st = n.attrs["style"], st.contains("IconButton") || st.contains("TextButton") || st.contains("borderless") {
                b.background = nil
                b.minimumWidth = 48
                if n.attr("textColor") == nil { b.setTextColor(DroidTheme.colorPrimary) }
                if n.attr("padding") == nil && n.attr("paddingHorizontal") == nil { b.setPadding(12, 12, 12, 12) }
            }
            if let s = n.attr("stateListAnimator"), s == "@null" { b.elevation = 0 }
            if let it = dim(n.attr("insetTop")) { (b.background as? ButtonBackground)?.insetV = Float(it) }
            if let il = dim(n.attr("insetLeft")) { (b.background as? ButtonBackground)?.insetH = Float(il) }
            if let r = dim(n.attr("cornerRadius")) { (b.background as? ButtonBackground)?.radius = Float(r) }
            if b.style == .material && n.attr("backgroundTint") == nil && n.attr("background") == nil {
                // Material 버튼 기본색 = colorPrimary (ButtonBackground 가 이미 그 색)
            }
        }
        if let et = tv as? EditText, let it = n.attr("inputType") {
            var t = InputType.TYPE_CLASS_TEXT
            if it.contains("number") { t = InputType.TYPE_CLASS_NUMBER }
            if it.contains("numberDecimal") { t |= InputType.TYPE_NUMBER_FLAG_DECIMAL }
            if it.contains("numberPassword") { t = InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_VARIATION_PASSWORD }
            if it.contains("textVisiblePassword") { t |= InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD }
            if it.contains("textPassword") { t |= InputType.TYPE_TEXT_VARIATION_PASSWORD }
            et.inputType = t
        }
    }
}
