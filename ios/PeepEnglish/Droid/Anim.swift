import UIKit

// 안드로이드 애니메이터(ValueAnimator·ObjectAnimator·view.animate())와 보간기.
// 화면 새로고침(CADisplayLink)마다 값을 계산해 콜백을 부른다 — 안드로이드와 같은 방식.

// MARK: - 보간기

protocol TimeInterpolator { func getInterpolation(_ t: Float) -> Float }
typealias Interpolator = TimeInterpolator

final class LinearInterpolator: TimeInterpolator { init() {}; func getInterpolation(_ t: Float) -> Float { t } }
final class AccelerateDecelerateInterpolator: TimeInterpolator {
    init() {}
    func getInterpolation(_ t: Float) -> Float { Float(cos(Double(t + 1) * .pi) / 2 + 0.5) }
}
final class AccelerateInterpolator: TimeInterpolator {
    let f: Float
    init(_ factor: Float = 1) { f = factor }
    func getInterpolation(_ t: Float) -> Float { f == 1 ? t * t : powf(t, 2 * f) }
}
final class DecelerateInterpolator: TimeInterpolator {
    let f: Float
    init(_ factor: Float = 1) { f = factor }
    func getInterpolation(_ t: Float) -> Float { f == 1 ? 1 - (1 - t) * (1 - t) : 1 - powf(1 - t, 2 * f) }
}
final class OvershootInterpolator: TimeInterpolator {
    let tension: Float
    init(_ tension: Float = 2) { self.tension = tension }
    func getInterpolation(_ t: Float) -> Float { let u = t - 1; return u * u * ((tension + 1) * u + tension) + 1 }
}
final class AnticipateInterpolator: TimeInterpolator {
    let tension: Float
    init(_ tension: Float = 2) { self.tension = tension }
    func getInterpolation(_ t: Float) -> Float { t * t * ((tension + 1) * t - tension) }
}
final class BounceInterpolator: TimeInterpolator {
    init() {}
    private func b(_ t: Float) -> Float { t * t * 8 }
    func getInterpolation(_ t0: Float) -> Float {
        let t = t0 * 1.1226
        if t < 0.3535 { return b(t) }
        if t < 0.7408 { return b(t - 0.54719) + 0.7 }
        if t < 0.9644 { return b(t - 0.8526) + 0.9 }
        return b(t - 1.0435) + 0.95
    }
}
final class CycleInterpolator: TimeInterpolator {
    let cycles: Float
    init(_ cycles: Float) { self.cycles = cycles }
    func getInterpolation(_ t: Float) -> Float { sinf(2 * cycles * .pi * t) }
}
final class FastOutSlowInInterpolator: TimeInterpolator {
    init() {}
    func getInterpolation(_ t: Float) -> Float { DecelerateInterpolator(1.5).getInterpolation(t) }
}

// MARK: - 프레임 시계

final class FrameClock: NSObject {
    static let shared = FrameClock()
    private var link: CADisplayLink?
    private var animators: [ValueAnimator] = []

    func add(_ a: ValueAnimator) {
        if !animators.contains(where: { $0 === a }) { animators.append(a) }
        if link == nil {
            let l = CADisplayLink(target: self, selector: #selector(tick))
            l.add(to: .main, forMode: .common)
            link = l
        }
    }
    func remove(_ a: ValueAnimator) { animators.removeAll { $0 === a } }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        for a in animators { a.step(now) }
        animators.removeAll { !$0.isRunning }
        if animators.isEmpty { link?.invalidate(); link = nil }
    }
}

// MARK: - Animator

class Animator {
    protocol AnimatorListener {
        func onAnimationStart(_ animation: Animator)
        func onAnimationEnd(_ animation: Animator)
        func onAnimationCancel(_ animation: Animator)
        func onAnimationRepeat(_ animation: Animator)
    }
    var listeners: [AnimatorListener] = []
    func addListener(_ l: AnimatorListener) { listeners.append(l) }
    func removeAllListeners() { listeners.removeAll() }
    func start() {}
    func cancel() {}
    func end() {}
    var isRunning: Bool { false }
    var isStarted: Bool { isRunning }
    var duration: Int = 300
    var startDelay: Int = 0
    var interpolator: TimeInterpolator = AccelerateDecelerateInterpolator()
    @discardableResult func setDuration(_ d: Int) -> Animator { duration = d; return self }
    func setInterpolator(_ i: TimeInterpolator?) { interpolator = i ?? LinearInterpolator() }
    func setStartDelay(_ d: Int) { startDelay = d }
}

/// 코틀린 `object : AnimatorListenerAdapter() { override fun onAnimationEnd ... }` 를 클로저로
struct AnimatorListenerAdapter: Animator.AnimatorListener {
    var onStart: (Animator) -> Void = { _ in }
    var onEnd: (Animator) -> Void = { _ in }
    var onCancel: (Animator) -> Void = { _ in }
    var onRepeat: (Animator) -> Void = { _ in }
    init(onStart: @escaping (Animator) -> Void = { _ in }, onEnd: @escaping (Animator) -> Void = { _ in },
         onCancel: @escaping (Animator) -> Void = { _ in }, onRepeat: @escaping (Animator) -> Void = { _ in }) {
        self.onStart = onStart; self.onEnd = onEnd; self.onCancel = onCancel; self.onRepeat = onRepeat
    }
    func onAnimationStart(_ a: Animator) { onStart(a) }
    func onAnimationEnd(_ a: Animator) { onEnd(a) }
    func onAnimationCancel(_ a: Animator) { onCancel(a) }
    func onAnimationRepeat(_ a: Animator) { onRepeat(a) }
}

final class PropertyValuesHolder {
    let property: ViewProperty
    let values: [Float]
    init(_ p: ViewProperty, _ v: [Float]) { property = p; values = v }
    static func ofFloat(_ p: ViewProperty, _ values: Float...) -> PropertyValuesHolder { PropertyValuesHolder(p, values) }
    static func ofFloat(_ name: String, _ values: Float...) -> PropertyValuesHolder { PropertyValuesHolder(ViewProperty(name), values) }
}

/// View.SCALE_X 같은 속성 이름
struct ViewProperty {
    let name: String
    init(_ name: String) { self.name = name }
    func set(_ v: View, _ value: Float) {
        switch name {
        case "scaleX": v.scaleX = value
        case "scaleY": v.scaleY = value
        case "alpha": v.alphaF = value
        case "translationX": v.translationX = value
        case "translationY": v.translationY = value
        case "rotation": v.rotation = value
        default: break
        }
    }
    func get(_ v: View) -> Float {
        switch name {
        case "scaleX": return v.scaleX
        case "scaleY": return v.scaleY
        case "alpha": return v.alphaF
        case "translationX": return v.translationX
        case "translationY": return v.translationY
        case "rotation": return v.rotation
        default: return 0
        }
    }
}
extension View {
    static let SCALE_X = ViewProperty("scaleX")
    static let SCALE_Y = ViewProperty("scaleY")
    static let ALPHA = ViewProperty("alpha")
    static let TRANSLATION_X = ViewProperty("translationX")
    static let TRANSLATION_Y = ViewProperty("translationY")
    static let ROTATION = ViewProperty("rotation")
}

class ValueAnimator: Animator {
    static let INFINITE = -1
    static let RESTART = 1, REVERSE = 2

    var values: [Float] = [0, 1]
    var holders: [PropertyValuesHolder] = []
    var repeatCount = 0
    var repeatMode = ValueAnimator.RESTART
    private var updateListeners: [(ValueAnimator) -> Void] = []
    private var startTime: CFTimeInterval = 0
    private var running = false
    private var startedCallbacks = false
    private(set) var animatedFraction: Float = 0
    private var currentValue: Float = 0
    private var holderValues: [String: Float] = [:]
    private var lastIteration = 0

    override init() { super.init() }

    static func ofFloat(_ values: Float...) -> ValueAnimator { let a = ValueAnimator(); a.values = values; return a }
    static func ofInt(_ values: Int...) -> ValueAnimator { let a = ValueAnimator(); a.values = values.map { Float($0) }; a.isInt = true; return a }
    var isInt = false

    /// 코틀린 `it.animatedValue as Float`
    var animatedValue: Any { isInt ? Int(currentValue.rounded()) : currentValue }
    var animatedFloat: Float { currentValue }
    func getAnimatedValue(_ name: String) -> Any? { holderValues[name] }

    func addUpdateListener(_ l: @escaping (ValueAnimator) -> Void) { updateListeners.append(l) }
    func removeAllUpdateListeners() { updateListeners.removeAll() }
    func setFloatValues(_ v: Float...) { values = v }
    @discardableResult override func setDuration(_ d: Int) -> ValueAnimator { duration = d; return self }

    override var isRunning: Bool { running }

    override func start() {
        if running { cancel() }
        running = true
        startedCallbacks = false
        lastIteration = 0
        startTime = CACurrentMediaTime() + Double(startDelay) / 1000
        apply(0)
        FrameClock.shared.add(self)
    }

    override func cancel() {
        guard running else { return }
        running = false
        FrameClock.shared.remove(self)
        for l in listeners { l.onAnimationCancel(self) }
        for l in listeners { l.onAnimationEnd(self) }
    }

    override func end() {
        guard running else { return }
        running = false
        FrameClock.shared.remove(self)
        apply(repeatMode == ValueAnimator.REVERSE && repeatCount > 0 && repeatCount % 2 == 1 ? 0 : 1)
        for l in listeners { l.onAnimationEnd(self) }
    }

    fileprivate func step(_ now: CFTimeInterval) {
        guard running else { return }
        if now < startTime { return }
        if !startedCallbacks { startedCallbacks = true; for l in listeners { l.onAnimationStart(self) } }
        let d = max(1, Double(duration)) / 1000
        let elapsed = now - startTime
        var iteration = Int(elapsed / d)
        var frac = Float((elapsed - Double(iteration) * d) / d)
        var done = false
        if repeatCount != ValueAnimator.INFINITE && iteration > repeatCount {
            iteration = repeatCount; frac = 1; done = true
        }
        if iteration != lastIteration && !done {
            lastIteration = iteration
            for l in listeners { l.onAnimationRepeat(self) }
        }
        if repeatMode == ValueAnimator.REVERSE && iteration % 2 == 1 { frac = 1 - frac }
        apply(frac)
        if done {
            running = false
            for l in listeners { l.onAnimationEnd(self) }
        }
    }

    private func apply(_ rawFrac: Float) {
        animatedFraction = rawFrac
        let f = interpolator.getInterpolation(rawFrac)
        currentValue = ValueAnimator.lerp(values, f)
        for h in holders { holderValues[h.property.name] = ValueAnimator.lerp(h.values, f) }
        applyToTarget()
        for u in updateListeners { u(self) }
    }

    func applyToTarget() {}

    static func lerp(_ vs: [Float], _ f: Float) -> Float {
        guard vs.count > 1 else { return vs.first ?? 0 }
        let seg = Float(vs.count - 1)
        let pos = max(0, min(seg, f * seg))
        var i = Int(pos)
        if i >= vs.count - 1 { i = vs.count - 2 }
        let local = f * seg - Float(i)
        return vs[i] + (vs[i + 1] - vs[i]) * local
    }

    func holderValue(_ name: String) -> Float { holderValues[name] ?? 0 }
}

final class ObjectAnimator: ValueAnimator {
    weak var target: View?
    private var property: ViewProperty?

    static func ofFloat(_ target: View, _ property: ViewProperty, _ values: Float...) -> ObjectAnimator {
        let a = ObjectAnimator(); a.target = target; a.property = property; a.values = values
        if values.count == 1 { a.values = [property.get(target), values[0]] }
        return a
    }
    static func ofFloat(_ target: View, _ name: String, _ values: Float...) -> ObjectAnimator {
        let p = ViewProperty(name)
        let a = ObjectAnimator(); a.target = target; a.property = p; a.values = values
        if values.count == 1 { a.values = [p.get(target), values[0]] }
        return a
    }
    static func ofPropertyValuesHolder(_ target: View, _ holders: PropertyValuesHolder...) -> ObjectAnimator {
        let a = ObjectAnimator(); a.target = target; a.holders = holders
        return a
    }
    @discardableResult override func setDuration(_ d: Int) -> ObjectAnimator { duration = d; return self }
    func setTarget(_ t: View?) { target = t }

    override func applyToTarget() {
        guard let t = target else { return }
        if let p = property { p.set(t, animatedFloat) }
        for h in holders { h.property.set(t, holderValue(h.property.name)) }
    }
}

final class AnimatorSet: Animator {
    private var items: [Animator] = []
    private var sequential = false
    func playTogether(_ a: Animator...) { items = a; sequential = false }
    func playTogether(_ a: [Animator]) { items = a; sequential = false }
    func playSequentially(_ a: Animator...) { items = a; sequential = true }
    @discardableResult override func setDuration(_ d: Int) -> AnimatorSet { duration = d; for i in items { i.duration = d }; return self }
    override func setInterpolator(_ i: TimeInterpolator?) { for a in items { a.setInterpolator(i) } }
    override var isRunning: Bool { items.contains { $0.isRunning } }
    override func start() {
        for l in listeners { l.onAnimationStart(self) }
        if sequential {
            var delay = startDelay
            for a in items { a.startDelay = delay; delay += a.duration; a.start() }
        } else { for a in items { a.startDelay = startDelay; a.start() } }
        if let last = sequential ? items.last : items.max(by: { $0.duration < $1.duration }) {
            last.addListener(AnimatorListenerAdapter(onEnd: { [weak self] _ in
                guard let self else { return }
                for l in self.listeners { l.onAnimationEnd(self) }
            }))
        }
    }
    override func cancel() { for a in items { a.cancel() } }
    override func end() { for a in items { a.end() } }
}

// MARK: - view.animate()

final class ViewPropertyAnimator {
    private weak var view: View?
    private var targets: [(ViewProperty, Float, Bool)] = []   // (속성, 값, By 인가)
    private var duration = 300
    private var delay = 0
    private var interpolator: TimeInterpolator = AccelerateDecelerateInterpolator()
    private var endAction: (() -> Void)?
    private var startAction: (() -> Void)?
    private var listener: Animator.AnimatorListener?
    private var updateListener: ((ValueAnimator) -> Void)?
    private var running: ValueAnimator?
    private var pendingStart = false

    init(_ v: View) { view = v }

    private func add(_ p: ViewProperty, _ value: Float, by: Bool) -> ViewPropertyAnimator {
        targets.removeAll { $0.0.name == p.name }
        targets.append((p, value, by))
        scheduleStart()
        return self
    }
    @discardableResult func alpha(_ v: Float) -> ViewPropertyAnimator { add(View.ALPHA, v, by: false) }
    @discardableResult func alphaBy(_ v: Float) -> ViewPropertyAnimator { add(View.ALPHA, v, by: true) }
    @discardableResult func scaleX(_ v: Float) -> ViewPropertyAnimator { add(View.SCALE_X, v, by: false) }
    @discardableResult func scaleY(_ v: Float) -> ViewPropertyAnimator { add(View.SCALE_Y, v, by: false) }
    @discardableResult func scaleXBy(_ v: Float) -> ViewPropertyAnimator { add(View.SCALE_X, v, by: true) }
    @discardableResult func scaleYBy(_ v: Float) -> ViewPropertyAnimator { add(View.SCALE_Y, v, by: true) }
    @discardableResult func translationX(_ v: Float) -> ViewPropertyAnimator { add(View.TRANSLATION_X, v, by: false) }
    @discardableResult func translationY(_ v: Float) -> ViewPropertyAnimator { add(View.TRANSLATION_Y, v, by: false) }
    @discardableResult func translationXBy(_ v: Float) -> ViewPropertyAnimator { add(View.TRANSLATION_X, v, by: true) }
    @discardableResult func translationYBy(_ v: Float) -> ViewPropertyAnimator { add(View.TRANSLATION_Y, v, by: true) }
    @discardableResult func rotation(_ v: Float) -> ViewPropertyAnimator { add(View.ROTATION, v, by: false) }
    @discardableResult func rotationBy(_ v: Float) -> ViewPropertyAnimator { add(View.ROTATION, v, by: true) }
    @discardableResult func setDuration(_ d: Int) -> ViewPropertyAnimator { duration = d; return self }
    @discardableResult func setStartDelay(_ d: Int) -> ViewPropertyAnimator { delay = d; return self }
    @discardableResult func setInterpolator(_ i: TimeInterpolator?) -> ViewPropertyAnimator { interpolator = i ?? LinearInterpolator(); return self }
    @discardableResult func withEndAction(_ r: @escaping () -> Void) -> ViewPropertyAnimator { endAction = r; return self }
    @discardableResult func withEndAction(_ r: Runnable) -> ViewPropertyAnimator { endAction = r.block; return self }
    @discardableResult func withStartAction(_ r: @escaping () -> Void) -> ViewPropertyAnimator { startAction = r; return self }
    @discardableResult func setListener(_ l: Animator.AnimatorListener?) -> ViewPropertyAnimator { listener = l; return self }
    @discardableResult func setUpdateListener(_ l: ((ValueAnimator) -> Void)?) -> ViewPropertyAnimator { updateListener = l; return self }
    @discardableResult func withLayer() -> ViewPropertyAnimator { self }

    /// 안드로이드는 start() 를 안 불러도 다음 프레임에 시작한다
    private func scheduleStart() {
        guard !pendingStart else { return }
        pendingStart = true
        DispatchQueue.main.async { [weak self] in
            guard let self, self.pendingStart else { return }
            self.start()
        }
    }

    func start() {
        pendingStart = false
        guard let v = view, !targets.isEmpty else { return }
        running?.cancelSilently()
        let specs = targets.map { (p, val, by) -> (ViewProperty, Float, Float) in
            let from = p.get(v)
            return (p, from, by ? from + val : val)
        }
        targets = []
        let end = endAction, startA = startAction, lis = listener, upd = updateListener
        endAction = nil; startAction = nil
        let a = ValueAnimator.ofFloat(0, 1)
        a.duration = duration
        a.startDelay = delay
        a.interpolator = interpolator
        delay = 0
        a.addUpdateListener { [weak v] anim in
            guard let v else { return }
            let f = anim.animatedFloat
            for (p, from, to) in specs { p.set(v, from + (to - from) * f) }
            upd?(anim)
        }
        a.addListener(AnimatorListenerAdapter(onStart: { an in startA?(); lis?.onAnimationStart(an) },
                                              onEnd: { [weak self, weak a] an in
            if !(a?.wasCanceled ?? false) { end?() }
            lis?.onAnimationEnd(an)
            if let a, self?.running === a { self?.running = nil }
        }, onCancel: { an in lis?.onAnimationCancel(an) }))
        running = a
        a.start()
    }

    func cancel() {
        pendingStart = false
        targets = []
        running?.cancelSilently()
        running = nil
    }
}

extension ValueAnimator {
    private static var canceledSet = NSHashTable<AnyObject>.weakObjects()
    var wasCanceled: Bool { ValueAnimator.canceledSet.contains(self) }
    func cancelSilently() {
        ValueAnimator.canceledSet.add(self)
        cancel()
    }
}

// MARK: - Animation (res/anim XML)

/// AnimationUtils.loadAnimation 으로 읽는 옛 방식 애니메이션 — 이 앱은 흔들기(translate)만 쓴다.
class Animation {
    var duration = 300
    var repeatCount = 0
    var repeatMode = 1
    var fromXDelta: Float = 0, toXDelta: Float = 0, fromYDelta: Float = 0, toYDelta: Float = 0
    var xIsPercent = false, yIsPercent = false
    var fromAlpha: Float? = nil, toAlpha: Float? = nil
    var interpolator: TimeInterpolator = LinearInterpolator()
    private var animator: ValueAnimator?
    private var onEnd: (() -> Void)?

    func setAnimationListener(onEnd: @escaping () -> Void) { self.onEnd = onEnd }

    func start(on v: View) {
        let a = ValueAnimator.ofFloat(0, 1)
        a.duration = duration
        a.repeatCount = repeatCount
        a.repeatMode = repeatMode == 2 ? ValueAnimator.REVERSE : ValueAnimator.RESTART
        a.interpolator = interpolator
        let baseTX = v.translationX, baseTY = v.translationY, baseAlpha = v.alphaF
        a.addUpdateListener { [weak v] an in
            guard let v else { return }
            let f = an.animatedFloat
            let fx = self.xIsPercent ? Float(v.width) / 100 : 1
            let fy = self.yIsPercent ? Float(v.height) / 100 : 1
            v.translationX = baseTX + (self.fromXDelta + (self.toXDelta - self.fromXDelta) * f) * fx
            v.translationY = baseTY + (self.fromYDelta + (self.toYDelta - self.fromYDelta) * f) * fy
            if let fa = self.fromAlpha, let ta = self.toAlpha { v.alphaF = fa + (ta - fa) * f }
        }
        a.addListener(AnimatorListenerAdapter(onEnd: { [weak v] _ in
            v?.translationX = baseTX; v?.translationY = baseTY
            if self.fromAlpha != nil { v?.alphaF = baseAlpha }
            self.onEnd?()
        }))
        animator = a
        a.start()
    }
    func cancel() { animator?.cancel() }
}

enum AnimationUtils {
    static func loadAnimation(_ ctx: Context, _ id: Int) -> Animation {
        let a = Animation()
        guard let name = ResNames.name(id),
              let node = XmlNode.parse(Res.shared.root.appendingPathComponent("anim/\(name).xml")) else { return a }
        let n = node.tag == "set" ? (node.children.first ?? node) : node
        a.duration = Int(n.attr("duration") ?? node.attr("duration") ?? "300") ?? 300
        a.repeatCount = Int(n.attr("repeatCount") ?? "0") ?? 0
        a.repeatMode = n.attr("repeatMode") == "reverse" ? 2 : 1
        func val(_ s: String?, _ pct: inout Bool) -> Float {
            guard var s else { return 0 }
            if s.hasSuffix("%") { pct = true; s.removeLast() }
            return Float(s) ?? 0
        }
        a.fromXDelta = val(n.attr("fromXDelta"), &a.xIsPercent)
        a.toXDelta = val(n.attr("toXDelta"), &a.xIsPercent)
        a.fromYDelta = val(n.attr("fromYDelta"), &a.yIsPercent)
        a.toYDelta = val(n.attr("toYDelta"), &a.yIsPercent)
        if let fa = n.attr("fromAlpha").flatMap({ Float($0) }) { a.fromAlpha = fa; a.toAlpha = n.attr("toAlpha").flatMap { Float($0) } ?? 1 }
        if let i = n.attr("interpolator") {
            if i.contains("cycle") { a.interpolator = CycleInterpolator(1) }
            else if i.contains("accelerate_decelerate") { a.interpolator = AccelerateDecelerateInterpolator() }
            else if i.contains("decelerate") { a.interpolator = DecelerateInterpolator() }
            else if i.contains("overshoot") { a.interpolator = OvershootInterpolator() }
        }
        return a
    }
}
