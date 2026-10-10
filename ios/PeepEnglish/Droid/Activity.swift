import UIKit
import AVFoundation
import Speech

// 안드로이드 Activity·Intent·Toast·AlertDialog 의 아이폰판.
// 화면 하나 = UIViewController 하나. 안드로이드처럼 쌓고(startActivity) 빼낸다(finish).

// MARK: - Intent / Bundle

/// 안드로이드 onCreate(savedInstanceState: Bundle?) 의 Bundle — 이 앱은 늘 nil 로 시작한다
final class SavedState {
    var values: [String: Any] = [:]
}

final class Intent {
    static let FLAG_ACTIVITY_CLEAR_TOP = 0x0400_0000
    static let FLAG_ACTIVITY_SINGLE_TOP = 0x2000_0000
    static let FLAG_ACTIVITY_NEW_TASK = 0x1000_0000
    static let FLAG_ACTIVITY_CLEAR_TASK = 0x0000_8000

    let target: Activity.Type?
    private(set) var extras: [String: Any] = [:]
    var flags = 0

    init(_ context: Context?, _ target: Activity.Type) { self.target = target }
    init() { target = nil }

    @discardableResult func putExtra(_ key: String, _ value: Any?) -> Intent { extras[key] = value; return self }
    @discardableResult func addFlags(_ f: Int) -> Intent { flags |= f; return self }
    @discardableResult func setFlags(_ f: Int) -> Intent { flags = f; return self }
    func hasExtra(_ key: String) -> Bool { extras[key] != nil }
    // 실행 인자(DEBUG)로 넘긴 값은 글자라서, 숫자·참거짓도 글자에서 읽어 준다
    func getStringExtra(_ key: String) -> String? {
        switch extras[key] { case let s as String: return s; case let n as Int: return String(n); default: return nil }
    }
    func getIntExtra(_ key: String, _ def: Int) -> Int {
        switch extras[key] { case let n as Int: return n; case let s as String: return Int(s) ?? def; default: return def }
    }
    func getLongExtra(_ key: String, _ def: Int) -> Int { getIntExtra(key, def) }
    func getFloatExtra(_ key: String, _ def: Float) -> Float {
        switch extras[key] { case let f as Float: return f; case let s as String: return Float(s) ?? def; default: return def }
    }
    func getDoubleExtra(_ key: String, _ def: Double) -> Double {
        switch extras[key] { case let f as Double: return f; case let s as String: return Double(s) ?? def; default: return def }
    }
    func getBooleanExtra(_ key: String, _ def: Bool) -> Bool {
        switch extras[key] { case let b as Bool: return b; case let s as String: return s == "true" || s == "1"; default: return def }
    }
    func getStringArrayListExtra(_ key: String) -> [String]? { extras[key] as? [String] }
    func getStringArrayExtra(_ key: String) -> [String]? { extras[key] as? [String] }
    func getIntArrayExtra(_ key: String) -> [Int]? { extras[key] as? [Int] }
}

// MARK: - 화면 쌓기

final class DroidHost: NSObject, UINavigationControllerDelegate {
    static let shared = DroidHost()
    let nav = UINavigationController()
    var launcher: Activity.Type?

    func start(in window: UIWindow, launcher: Activity.Type, intent: Intent = Intent()) {
        self.launcher = launcher
        nav.setNavigationBarHidden(true, animated: false)
        nav.interactivePopGestureRecognizer?.isEnabled = false
        nav.delegate = self
        let a = launcher.init()
        a.intent = intent
        nav.setViewControllers([a], animated: false)
        window.rootViewController = nav
        window.makeKeyAndVisible()
    }

    var stack: [Activity] { nav.viewControllers.compactMap { $0 as? Activity } }
    var top: Activity? { stack.last }

    func push(_ a: Activity, from: Activity?) {
        if a.intent.flags & Intent.FLAG_ACTIVITY_CLEAR_TOP != 0,
           let i = stack.lastIndex(where: { type(of: $0) == type(of: a) }) {
            let keep = Array(stack.prefix(i))
            for gone in stack.suffix(from: i) { gone.markFinishing() }
            nav.setViewControllers(keep + [a], animated: true)
            return
        }
        nav.pushViewController(a, animated: true)
    }

    func finish(_ a: Activity) {
        guard let i = nav.viewControllers.firstIndex(of: a) else { return }
        a.markFinishing()
        if i == nav.viewControllers.count - 1 {
            if nav.viewControllers.count > 1 { nav.popViewController(animated: true) }
            else {
                // 첫 화면을 닫으면 안드로이드는 앱이 내려간다 — 아이폰은 앱을 끄지 않고 새 첫 화면으로
                if let l = launcher { let n = l.init(); nav.setViewControllers([n], animated: false) }
            }
        } else {
            var vcs = nav.viewControllers
            vcs.remove(at: i)
            nav.setViewControllers(vcs, animated: false)
        }
    }

    /// 언어를 바꾸면 쌓인 화면을 모두 새로 만든다 (안드로이드 recreate 와 같음)
    func recreateAll() {
        let fresh: [Activity] = stack.map { old in
            let n = type(of: old).init()
            n.intent = old.intent
            old.markFinishing()
            return n
        }
        nav.setViewControllers(fresh, animated: false)
    }

    func navigationController(_ nc: UINavigationController, didShow vc: UIViewController, animated: Bool) {
        // 스택에서 빠진 화면은 onDestroy
        for a in Activity.alive where !nc.viewControllers.contains(a) && !a.destroyed { a.performDestroy() }
    }
}

// MARK: - Activity

class Activity: UIViewController, Context {
    static var alive: [Activity] { liveSet.allObjects }
    private static let liveSet = NSHashTable<Activity>.weakObjects()

    var intent = Intent()
    func getIntent() -> Intent { intent }
    let decor: FrameLayout
    private(set) var contentView: View?
    let window: Window
    let onBackPressedDispatcher = OnBackPressedDispatcher()
    private(set) var isFinishing = false
    fileprivate(set) var destroyed = false
    var isDestroyed: Bool { destroyed }
    private var created = false
    private var resumed = false
    private let bottomBand = UIView()
    private var keyboardHeight: CGFloat = 0

    required init() {
        decor = FrameLayout(AppContext.shared)
        window = Window()
        super.init(nibName: nil, bundle: nil)
        window.activity = self
        Activity.liveSet.add(self)
    }
    required init?(coder: NSCoder) { fatalError() }

    // 수명 — 하위 화면이 덮어쓴다
    func onCreate(_ savedInstanceState: SavedState?) {}
    func onStart() {}
    func onResume() {}
    func onPause() {}
    func onStop() {}
    func onDestroy() {}
    func onPostCreate(_ savedInstanceState: SavedState?) {}
    func onWindowFocusChanged(_ hasFocus: Bool) {}
    func onRequestPermissionsResult(_ requestCode: Int, _ permissions: [String], _ grantResults: [Int]) {}

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Color.ui(DroidTheme.windowBackground)
        bottomBand.backgroundColor = Color.ui(DroidTheme.windowBackground)
        view.addSubview(bottomBand)
        view.addSubview(decor)
        let edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgeBack(_:)))
        edge.edges = .left
        view.addGestureRecognizer(edge)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboard(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appPaused), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appResumed), name: UIApplication.didBecomeActiveNotification, object: nil)
        created = true
        onCreate(nil)
        onPostCreate(nil)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let safe = view.safeAreaInsets
        let bottom = max(safe.bottom, keyboardHeight)
        decor.frame = CGRect(x: safe.left, y: safe.top, width: view.bounds.width - safe.left - safe.right,
                             height: view.bounds.height - safe.top - bottom)
        bottomBand.frame = CGRect(x: 0, y: view.bounds.height - safe.bottom, width: view.bounds.width, height: safe.bottom)
        decor.setNeedsLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        onStart()
        if !resumed { resumed = true; onResume() }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onWindowFocusChanged(true)
        #if DEBUG
        // 스크린샷용: -scroll bottom 이면 화면의 스크롤을 끝까지 내린다
        if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-scroll"), i + 1 < ProcessInfo.processInfo.arguments.count,
           ProcessInfo.processInfo.arguments[i + 1] == "bottom" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                func walk(_ v: View) {
                    if let s = v as? ScrollView { s.scrollTo(0, Int(s.scroller.contentSize.height)) }
                    if let g = v as? ViewGroup { g.children.forEach(walk) }
                }
                walk(self.decor)
            }
        }
        #endif
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
        if resumed { resumed = false; onPause() }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        onStop()
        if isMovingFromParent || isFinishing { performDestroy() }
    }
    @objc private func appPaused() { if resumed && DroidHost.shared.top === self { resumed = false; onPause() } }
    @objc private func appResumed() { if !resumed && DroidHost.shared.top === self && view.window != nil { resumed = true; onResume() } }

    fileprivate func performDestroy() {
        guard !destroyed else { return }
        destroyed = true
        NotificationCenter.default.removeObserver(self)
        onDestroy()
    }
    fileprivate func markFinishing() { isFinishing = true }

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    @objc private func keyboard(_ n: Notification) {
        guard let end = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let local = view.convert(end, from: nil)
        keyboardHeight = max(0, view.bounds.height - local.minY)
        view.setNeedsLayout()
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }

    @objc private func edgeBack(_ g: UIScreenEdgePanGestureRecognizer) {
        if g.state == .ended && g.translation(in: view).x > 60 { onBackPressed() }
    }

    // MARK: 화면

    func setContentView(_ v: View) {
        decor.removeAllViews()
        decor.addView(v, FrameLayout.LayoutParams(BaseLayoutParams.MATCH_PARENT, BaseLayoutParams.MATCH_PARENT))
        contentView = v
    }
    func setContentView(_ layoutId: Int) { setContentView(layoutInflater.inflate(layoutId, decor, false)) }
    func findViewById<T: View>(_ id: Int) -> T? { decor.findViewById(id) }

    func startActivity(_ i: Intent) {
        guard let t = i.target else { return }
        let a = t.init()
        a.intent = i
        DroidHost.shared.push(a, from: self)
    }
    func finish() {
        isFinishing = true
        DroidHost.shared.finish(self)
    }
    func recreate() {
        let n = type(of: self).init()
        n.intent = intent
        guard let i = DroidHost.shared.nav.viewControllers.firstIndex(of: self) else { return }
        var vcs = DroidHost.shared.nav.viewControllers
        vcs[i] = n
        markFinishing()
        DroidHost.shared.nav.setViewControllers(vcs, animated: false)
    }
    func onBackPressed() {
        if onBackPressedDispatcher.dispatch() { return }
        finish()
    }
    func runOnUiThread(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }
    func overridePendingTransition(_ a: Int, _ b: Int) {}

    var windowBackground: Int = DroidTheme.windowBackground

    fileprivate func applyWindowColors() {
        guard isViewLoaded else { return }
        view.backgroundColor = Color.ui(window.statusBarColor)
        bottomBand.backgroundColor = Color.ui(window.navigationBarColor)
    }

    // 권한 (영어 앱 말하기)
    func requestPermissions(_ perms: [String], _ code: Int) {
        Permissions.request(perms) { granted in
            self.onRequestPermissionsResult(code, perms, perms.map { _ in granted ? PackageManager.PERMISSION_GRANTED : PackageManager.PERMISSION_DENIED })
        }
    }
}

typealias AppCompatActivity = Activity
typealias ComponentActivity = Activity

final class Window {
    static let FLAG_KEEP_SCREEN_ON = 128
    weak var activity: Activity?
    var statusBarColor: Int = DroidTheme.windowBackground { didSet { activity?.applyWindowColors() } }
    var navigationBarColor: Int = DroidTheme.windowBackground { didSet { activity?.applyWindowColors() } }
    var decorView: View { activity!.decor }
    func addFlags(_ f: Int) { if f & Window.FLAG_KEEP_SCREEN_ON != 0 { UIApplication.shared.isIdleTimerDisabled = true } }
    func clearFlags(_ f: Int) { if f & Window.FLAG_KEEP_SCREEN_ON != 0 { UIApplication.shared.isIdleTimerDisabled = false } }
    func setSoftInputMode(_ m: Int) {}
}

// MARK: - 뒤로 가기

class OnBackPressedCallback {
    var isEnabled: Bool
    private let block: ((OnBackPressedCallback) -> Void)?
    init(_ enabled: Bool, _ block: ((OnBackPressedCallback) -> Void)? = nil) { isEnabled = enabled; self.block = block }
    func handleOnBackPressed() { block?(self) }
    func remove() { isEnabled = false }
}

final class OnBackPressedDispatcher {
    private var callbacks: [OnBackPressedCallback] = []
    func addCallback(_ owner: Any?, _ cb: OnBackPressedCallback) { callbacks.append(cb) }
    func addCallback(_ cb: OnBackPressedCallback) { callbacks.append(cb) }
    /// 처리했으면 true
    func dispatch() -> Bool {
        if let cb = callbacks.last(where: { $0.isEnabled }) { cb.handleOnBackPressed(); return true }
        return false
    }
    func onBackPressed() {
        if !dispatch(), let top = DroidHost.shared.top { top.finish() }
    }
    var hasEnabledCallbacks: Bool { callbacks.contains { $0.isEnabled } }
}

// MARK: - 권한

enum PackageManager { static let PERMISSION_GRANTED = 0, PERMISSION_DENIED = -1 }
enum Manifest { enum permission { static let RECORD_AUDIO = "android.permission.RECORD_AUDIO" } }

enum Permissions {
    static func isGranted(_ perm: String) -> Bool {
        if perm == Manifest.permission.RECORD_AUDIO {
            return AVAudioSession.sharedInstance().recordPermission == .granted
                && SFSpeechRecognizer.authorizationStatus() == .authorized
        }
        return true
    }
    static func request(_ perms: [String], _ done: @escaping (Bool) -> Void) {
        guard perms.contains(Manifest.permission.RECORD_AUDIO) else { done(true); return }
        AVAudioSession.sharedInstance().requestRecordPermission { mic in
            SFSpeechRecognizer.requestAuthorization { s in
                DispatchQueue.main.async { done(mic && s == .authorized) }
            }
        }
    }
}

enum ActivityCompat {
    static func checkSelfPermission(_ ctx: Context, _ perm: String) -> Int {
        Permissions.isGranted(perm) ? PackageManager.PERMISSION_GRANTED : PackageManager.PERMISSION_DENIED
    }
    static func requestPermissions(_ a: Activity, _ perms: [String], _ code: Int) { a.requestPermissions(perms, code) }
}
typealias ContextCompatPermission = ActivityCompat

// MARK: - Toast

final class Toast {
    static let LENGTH_SHORT = 0, LENGTH_LONG = 1
    private let text: String
    private let duration: Int
    private init(_ text: String, _ duration: Int) { self.text = text; self.duration = duration }
    static func makeText(_ ctx: Context, _ text: String, _ duration: Int) -> Toast { Toast(text, duration) }
    static func makeText(_ ctx: Context, _ resId: Int, _ duration: Int) -> Toast { Toast(Res.shared.string(resId), duration) }

    private static weak var current: UIView?

    func show() {
        guard let win = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
        Toast.current?.removeFromSuperview()
        let pad: CGFloat = 16
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .center
        let maxW = win.bounds.width - 64
        let s = label.sizeThatFits(CGSize(width: maxW - pad * 2, height: .greatestFiniteMagnitude))
        let box = UIView(frame: CGRect(x: 0, y: 0, width: min(maxW, s.width + pad * 2), height: s.height + 24))
        box.backgroundColor = UIColor(white: 0.2, alpha: 0.92)
        box.layer.cornerRadius = min(22, box.bounds.height / 2)
        box.isUserInteractionEnabled = false
        label.frame = box.bounds.insetBy(dx: pad, dy: 12)
        box.addSubview(label)
        box.center = CGPoint(x: win.bounds.midX, y: win.bounds.height - win.safeAreaInsets.bottom - 80)
        box.alpha = 0
        win.addSubview(box)
        Toast.current = box
        UIView.animate(withDuration: 0.2) { box.alpha = 1 }
        let d = duration == Toast.LENGTH_LONG ? 3.5 : 2.0
        UIView.animate(withDuration: 0.3, delay: d, options: []) { box.alpha = 0 } completion: { _ in box.removeFromSuperview() }
    }
}

// MARK: - AlertDialog

typealias DialogInterface = AlertDialog

/// 머티리얼3 대화상자 모양을 안드로이드 View 로 그린다.
final class AlertDialog {
    static let BUTTON_POSITIVE = -1, BUTTON_NEGATIVE = -2, BUTTON_NEUTRAL = -3

    final class Builder {
        let context: Context
        fileprivate var title: String?
        fileprivate var message: String?
        fileprivate var items: [String]?
        fileprivate var itemsListener: ((DialogInterface, Int) -> Void)?
        fileprivate var singleChecked = -1
        fileprivate var isSingleChoice = false
        fileprivate var view: View?
        fileprivate var positive: (String, ((DialogInterface, Int) -> Void)?)?
        fileprivate var negative: (String, ((DialogInterface, Int) -> Void)?)?
        fileprivate var neutral: (String, ((DialogInterface, Int) -> Void)?)?
        fileprivate var cancelable = true
        fileprivate var onDismiss: ((DialogInterface) -> Void)?
        fileprivate var onCancel: ((DialogInterface) -> Void)?

        init(_ context: Context) { self.context = context }
        init(_ context: Context, _ theme: Int) { self.context = context }

        @discardableResult func setTitle(_ t: String?) -> Builder { title = t; return self }
        @discardableResult func setTitle(_ id: Int) -> Builder { title = Res.shared.string(id); return self }
        @discardableResult func setMessage(_ m: String?) -> Builder { message = m; return self }
        @discardableResult func setMessage(_ id: Int) -> Builder { message = Res.shared.string(id); return self }
        @discardableResult func setItems(_ items: [String], _ l: ((DialogInterface, Int) -> Void)?) -> Builder {
            self.items = items; itemsListener = l; return self
        }
        @discardableResult func setSingleChoiceItems(_ items: [String], _ checked: Int, _ l: ((DialogInterface, Int) -> Void)?) -> Builder {
            self.items = items; singleChecked = checked; isSingleChoice = true; itemsListener = l; return self
        }
        @discardableResult func setView(_ v: View) -> Builder { view = v; return self }
        @discardableResult func setPositiveButton(_ t: String, _ l: ((DialogInterface, Int) -> Void)?) -> Builder { positive = (t, l); return self }
        @discardableResult func setPositiveButton(_ id: Int, _ l: ((DialogInterface, Int) -> Void)?) -> Builder { positive = (Res.shared.string(id), l); return self }
        @discardableResult func setNegativeButton(_ t: String, _ l: ((DialogInterface, Int) -> Void)?) -> Builder { negative = (t, l); return self }
        @discardableResult func setNegativeButton(_ id: Int, _ l: ((DialogInterface, Int) -> Void)?) -> Builder { negative = (Res.shared.string(id), l); return self }
        @discardableResult func setNeutralButton(_ t: String, _ l: ((DialogInterface, Int) -> Void)?) -> Builder { neutral = (t, l); return self }
        @discardableResult func setNeutralButton(_ id: Int, _ l: ((DialogInterface, Int) -> Void)?) -> Builder { neutral = (Res.shared.string(id), l); return self }
        @discardableResult func setCancelable(_ c: Bool) -> Builder { cancelable = c; return self }
        @discardableResult func setOnDismissListener(_ l: ((DialogInterface) -> Void)?) -> Builder { onDismiss = l; return self }
        @discardableResult func setOnCancelListener(_ l: ((DialogInterface) -> Void)?) -> Builder { onCancel = l; return self }

        func create() -> AlertDialog { AlertDialog(self) }
        @discardableResult func show() -> AlertDialog { let d = create(); d.show(); return d }
    }

    private let b: Builder
    private var host: DialogHostView?
    private var buttons: [Int: Button] = [:]
    var isShowing: Bool { host != nil }
    private var canceledOnTouchOutside = true
    private var onDismiss: ((DialogInterface) -> Void)?

    private init(_ b: Builder) { self.b = b; onDismiss = b.onDismiss; canceledOnTouchOutside = b.cancelable }

    func setCanceledOnTouchOutside(_ c: Bool) { canceledOnTouchOutside = c }
    func setCancelable(_ c: Bool) { b.cancelable = c; canceledOnTouchOutside = c }
    func setOnDismissListener(_ l: ((DialogInterface) -> Void)?) { onDismiss = l }
    func getButton(_ which: Int) -> Button? { buttons[which] }

    func show() {
        guard host == nil, let win = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
        let ctx = b.context
        let h = DialogHostView(ctx)
        h.onOutside = { [weak self] in
            guard let self, self.canceledOnTouchOutside, self.b.cancelable else { return }
            self.b.onCancel?(self)
            self.dismiss()
        }
        let card = LinearLayout(ctx)
        card.orientation = LinearLayout.VERTICAL
        let bg = GradientDrawable(); bg.setColor(Color.parseColor("#FFF7F2FA")); bg.setCornerRadius(28)
        card.background = bg
        card.setPadding(0, 24, 0, 18)

        if let t = b.title, !t.isEmpty {
            let tv = TextView(ctx)
            tv.text = t
            tv.textSize = 22
            tv.typeface = Typeface(family: "sans-serif", style: Typeface.NORMAL)
            tv.setTextColor(Color.parseColor("#FF1D1B20"))
            tv.setPadding(24, 0, 24, 16)
            card.addView(tv, LinearLayout.LayoutParams(BaseLayoutParams.MATCH_PARENT, BaseLayoutParams.WRAP_CONTENT))
        }
        let body = LinearLayout(ctx)
        body.orientation = LinearLayout.VERTICAL
        let scroll = ScrollView(ctx)
        scroll.addView(body, FrameLayout.LayoutParams(BaseLayoutParams.MATCH_PARENT, BaseLayoutParams.WRAP_CONTENT))
        let scrollLp = LinearLayout.LayoutParams(BaseLayoutParams.MATCH_PARENT, BaseLayoutParams.WRAP_CONTENT)
        card.addView(scroll, scrollLp)
        h.scroll = scroll

        if let m = b.message, !m.isEmpty {
            let tv = TextView(ctx)
            tv.text = m
            tv.textSize = 14
            tv.typeface = Typeface(family: "sans-serif", style: Typeface.NORMAL)
            tv.setTextColor(Color.parseColor("#FF49454F"))
            tv.setLineSpacing(0, 1.2)
            tv.setPadding(24, 0, 24, 8)
            body.addView(tv, LinearLayout.LayoutParams(BaseLayoutParams.MATCH_PARENT, BaseLayoutParams.WRAP_CONTENT))
        }
        if let items = b.items {
            var rows: [TextView] = []
            for (i, it) in items.enumerated() {
                let tv = TextView(ctx)
                tv.textSize = 16
                tv.typeface = Typeface(family: "sans-serif", style: Typeface.NORMAL)
                tv.setTextColor(Color.parseColor("#FF1D1B20"))
                tv.setPadding(24, 13, 24, 13)
                tv.gravity = Gravity.CENTER_VERTICAL
                tv.minimumHeight = 48
                rows.append(tv)
                func paint() {
                    tv.text = b.isSingleChoice ? ((b.singleChecked == i ? "◉  " : "○  ") + it) : it
                }
                paint()
                tv.setOnClickListener { [weak self] _ in
                    guard let self else { return }
                    if self.b.isSingleChoice {
                        self.b.singleChecked = i
                        for (j, r) in rows.enumerated() { r.text = (j == i ? "◉  " : "○  ") + items[j] }
                        self.b.itemsListener?(self, i)
                    } else {
                        self.b.itemsListener?(self, i)
                        self.dismiss()
                    }
                }
                body.addView(tv, LinearLayout.LayoutParams(BaseLayoutParams.MATCH_PARENT, BaseLayoutParams.WRAP_CONTENT))
            }
        }
        if let v = b.view {
            let lp = (v.layoutParams as? LinearLayout.LayoutParams) ?? LinearLayout.LayoutParams(BaseLayoutParams.MATCH_PARENT, BaseLayoutParams.WRAP_CONTENT)
            if v.parent != nil { v.parent?.removeView(v) }
            body.addView(v, lp)
        }

        let row = LinearLayout(ctx)
        row.orientation = LinearLayout.HORIZONTAL
        row.gravity = Gravity.END | Gravity.CENTER_VERTICAL
        row.setPadding(16, 8, 16, 0)
        func addButton(_ spec: (String, ((DialogInterface, Int) -> Void)?)?, _ which: Int) {
            guard let (t, l) = spec else { return }
            let bt = Button(ctx, nil, style: .material)
            bt.text = t
            bt.background = nil
            bt.setTextColor(DroidTheme.colorOnPrimary)
            bt.setTypeface(bt.typeface, Typeface.BOLD)
            bt.minimumWidth = 48
            bt.setPadding(12, 10, 12, 10)
            bt.setOnClickListener { [weak self] _ in
                guard let self else { return }
                l?(self, which)
                self.dismiss()
            }
            buttons[which] = bt
            if which == AlertDialog.BUTTON_NEUTRAL {
                row.addView(bt, LinearLayout.LayoutParams(BaseLayoutParams.WRAP_CONTENT, BaseLayoutParams.WRAP_CONTENT))
                let spacer = Space(ctx)
                row.addView(spacer, LinearLayout.LayoutParams(0, 1, 1))
            } else {
                row.addView(bt, LinearLayout.LayoutParams(BaseLayoutParams.WRAP_CONTENT, BaseLayoutParams.WRAP_CONTENT))
            }
        }
        addButton(b.neutral, AlertDialog.BUTTON_NEUTRAL)
        addButton(b.negative, AlertDialog.BUTTON_NEGATIVE)
        addButton(b.positive, AlertDialog.BUTTON_POSITIVE)
        if !buttons.isEmpty { card.addView(row, LinearLayout.LayoutParams(BaseLayoutParams.MATCH_PARENT, BaseLayoutParams.WRAP_CONTENT)) }
        else { card.setPadding(0, 24, 0, 12) }

        h.card = card
        h.addView(card, FrameLayout.LayoutParams(BaseLayoutParams.MATCH_PARENT, BaseLayoutParams.WRAP_CONTENT, Gravity.CENTER))
        h.frame = win.bounds
        h.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        win.addSubview(h)
        host = h
        h.alpha = 0
        UIView.animate(withDuration: 0.15) { h.alpha = 1 }
        AlertDialog.showing.append(self)
    }

    private static var showing: [AlertDialog] = []

    func dismiss() {
        guard let h = host else { return }
        host = nil
        h.endEditing(true)
        UIView.animate(withDuration: 0.12, animations: { h.alpha = 0 }) { _ in h.removeFromSuperview() }
        AlertDialog.showing.removeAll { $0 === self }
        onDismiss?(self)
    }
    func cancel() { b.onCancel?(self); dismiss() }
}

/// 대화상자 바깥(어두운 막)과 가운데 카드. 키보드가 오르면 카드를 위로 올린다.
final class DialogHostView: FrameLayout {
    var onOutside: (() -> Void)?
    weak var card: View?
    weak var scroll: ScrollView?
    private var keyboard: CGFloat = 0

    override init(_ context: Context, _ attrs: AttributeSet? = nil) {
        super.init(context, attrs)
        backgroundColor = UIColor(white: 0, alpha: 0.32)
        NotificationCenter.default.addObserver(self, selector: #selector(kb(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func kb(_ n: Notification) {
        guard let end = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        keyboard = max(0, bounds.height - convert(end, from: nil).minY)
        requestLayout()
        setNeedsLayout()
    }

    override func onMeasure(_ widthSpec: Int, _ heightSpec: Int) {
        let w = MeasureSpec.getSize(widthSpec), h = MeasureSpec.getSize(heightSpec)
        let safeTop = Int(safeAreaInsets.top), safeBottom = Int(max(safeAreaInsets.bottom, keyboard))
        let cardW = min(w - 48, 560)
        let maxH = max(120, h - safeTop - safeBottom - 48)
        if let c = card {
            // 내용이 길면 가운데 스크롤이 줄어든다
            c.measure(MeasureSpec.makeMeasureSpec(cardW, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(maxH, MeasureSpec.AT_MOST))
            if c.measuredHeight >= maxH, let s = scroll, let lp = s.layoutParams as? LinearLayout.LayoutParams {
                lp.height = 0; lp.weight = 1
                c.measure(MeasureSpec.makeMeasureSpec(cardW, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(maxH, MeasureSpec.EXACTLY))
            }
        }
        setMeasuredDimension(w, h)
    }
    override func onLayout(_ changed: Bool, _ l: Int, _ t: Int, _ r: Int, _ b: Int) {
        guard let c = card else { return }
        let safeTop = Int(safeAreaInsets.top), safeBottom = Int(max(safeAreaInsets.bottom, keyboard))
        let avail = (b - t) - safeTop - safeBottom
        let x = ((r - l) - c.measuredWidth) / 2
        let y = safeTop + max(0, (avail - c.measuredHeight) / 2)
        c.layout(x, y, x + c.measuredWidth, y + c.measuredHeight)
    }
    override func onTouchEvent(_ event: MotionEvent) -> Bool {
        if event.action == MotionEvent.ACTION_UP { endEditing(true); onOutside?() }
        return true
    }
}

// MARK: - 클립보드·진동

enum Clipboard {
    static func copy(_ text: String) { UIPasteboard.general.string = text }
}
final class ClipData {
    let text: String
    private init(_ t: String) { text = t }
    static func newPlainText(_ label: String, _ text: String) -> ClipData { ClipData(text) }
}
final class ClipboardManager {
    func setPrimaryClip(_ c: ClipData) { UIPasteboard.general.string = c.text }
}

final class Vibrator {
    func hasVibrator() -> Bool { true }
    func vibrate(_ ms: Int) { Vibrator.buzz(ms) }
    func vibrate(_ effect: VibrationEffect) { Vibrator.buzz(effect.ms) }
    static func buzz(_ ms: Int) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = ms >= 80 ? .heavy : ms >= 35 ? .medium : .light
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
struct VibrationEffect {
    static let DEFAULT_AMPLITUDE = -1
    let ms: Int
    static func createOneShot(_ ms: Int, _ amplitude: Int) -> VibrationEffect { VibrationEffect(ms: ms) }
}

extension Context {
    static var VIBRATOR_SERVICE: String { "vibrator" }
    func getVibrator() -> Vibrator { Vibrator() }
    func getClipboard() -> ClipboardManager { ClipboardManager() }
}

/// 안드로이드 CountDownTimer
class CountDownTimer {
    private let total: Int
    private let interval: Int
    private var timer: Timer?
    private var startDate = Date()
    private let onTickBlock: ((Int) -> Void)?
    private let onFinishBlock: (() -> Void)?

    init(_ millisInFuture: Int, _ countDownInterval: Int, onTick: ((Int) -> Void)? = nil, onFinish: (() -> Void)? = nil) {
        total = millisInFuture; interval = countDownInterval; onTickBlock = onTick; onFinishBlock = onFinish
    }
    func onTick(_ millisUntilFinished: Int) { onTickBlock?(millisUntilFinished) }
    func onFinish() { onFinishBlock?() }

    @discardableResult func start() -> CountDownTimer {
        cancel()
        startDate = Date()
        onTick(total)
        timer = Timer.scheduledTimer(withTimeInterval: Double(interval) / 1000, repeats: true) { [weak self] _ in
            guard let self else { return }
            let left = self.total - Int(Date().timeIntervalSince(self.startDate) * 1000)
            if left <= 0 { self.cancel(); self.onFinish() } else { self.onTick(left) }
        }
        return self
    }
    func cancel() { timer?.invalidate(); timer = nil }
}
