# 아이폰판 옮기기 규칙

아이폰판은 안드로이드 코틀린 파일을 **한 파일씩 같은 이름으로** 옮긴 것이다.
화면은 SwiftUI 가 아니라 `PeepEnglish/Droid/` 의 **안드로이드 호환 층** 위에서 돈다 —
`View`·`LinearLayout`·`TextView`·`Canvas`·`Paint`·`Activity`·`AlertDialog`… 가 안드로이드와 같은 이름·인자로 있다.
그래서 코틀린 화면 코드를 거의 줄 단위로 옮길 수 있다.

레이아웃 XML·문구(strings.xml)·색·그림·문제 팩은 **안드로이드 한 벌**을 빌드 때 번들로 복사해 그대로 읽는다
(`tools/copy-assets.sh`). 아이폰에 사본을 두지 않는다.

## 파일 위치

| 안드로이드 (`app/src/main/java/com/piyak/english/`) | 아이폰 (`ios/PeepEnglish/`) |
|---|---|
| `model/X.kt`, `engine/X.kt`, `db/X.kt`, `i18n/X.kt`, `audio/X.kt`, `PiyakApp.kt` | `Core/<같은 폴더>/X.swift` |
| `ui/X.kt` | `UI/X.swift` |
| `ui/game/X.kt` | `UI/game/X.swift` |
| `app/src/test/.../XTest.kt` | `PeepEnglishTests/XTests.swift` |
| `res/layout/x.xml` | 그대로 읽는다. 바인딩 클래스는 `Gen/Bindings.swift` (자동 생성) |
| `R.string.x` 등 | `Gen/R.swift` (자동 생성, `python3 tools/gen-r.py`) |

`Droid/` 는 고치지 않는다. 호환 층에 없는 안드로이드 API 가 필요하면, 그 파일 안에 `private` 도우미를 두거나
`Droid/Additions/<내 이름>.swift` 에 넣고 보고한다(나중에 합친다).

## 이름

- **클래스·함수·속성·인자 이름은 코틀린과 똑같이.** 다른 사람이 옮긴 파일과 이름이 맞물려야 한다.
- 함수 인자 이름표는 **붙이지 않는다**(`_`). 코틀린 호출 `foo(a, b)` → 스위프트 `foo(a, b)`.
  단, 코틀린에서 이름 붙여 부르는 인자(`foo(x = 1)`)나 기본값이 있는 인자가 여럿이면 이름표를 둔다: `func foo(_ a: Int, x: Int = 0)`.
  호출하는 쪽 코틀린이 이름을 붙였으면 이름표, 안 붙였으면 `_`.
- `object X` → `enum X { static ... }`. 바뀌는 상태가 있으면 `static var`.
- `companion object` 의 것 → `static`. 상수 이름 그대로(`PER_LETTER`).
- 파일 맨 위 함수 → 전역 `func`. 확장 함수 → `extension`.
- `enum class X { A, B }` → `enum X: String, KotlinEnum { case A, B }` (**대문자 이름 그대로**, 원시값 = 이름).
  생성자 속성은 계산 속성 `var id: String { switch self { ... } }`. `X.values()`/`entries` → `X.allCases`, `name`·`ordinal`·`valueOf` 는 `KotlinEnum` 이 준다.
- `sealed class` → 연관값 있는 `enum` 또는 클래스 상속 — 옮긴 파일 맨 위에 어느 쪽인지 한 줄 적는다.
  `is Question.Mcq` 같은 검사가 많으면 클래스 상속(`class Mcq: Question`)이 옮기기 쉽다.
- `data class` → `struct`(필드는 `var`, 순서 그대로, 필요하면 `Equatable`/`Hashable`).
  **같은 객체를 여러 곳이 고쳐 쓰는 것**(참조로 공유)이면 `final class`.
- `MutableList` 를 다른 객체에 넘겨 그쪽이 고치는 코드는 스위프트 배열(값 복사)로 바꾸면 깨진다 — 클래스로 감싸거나 `inout`.

## 자료형

| 코틀린 | 스위프트 |
|---|---|
| `Int`, `Long` | `Int` |
| `Float` | `Float` (Canvas·Paint 는 Float 를 받는다) |
| `Double` | `Double` |
| `List<T>`/`MutableList<T>` | `[T]` |
| `Map<K,V>` | `[K: V]` — **돌면서 순서가 결과에 영향을 주면** `[(K, V)]` 배열이나 정렬 |
| `Set<T>` | `Set<T>` — 순서가 중요하면 배열 |
| `Pair`/`Triple` | `Pair`/`Triple` (`Droid/Kotlin.swift`) 또는 튜플 |
| `kotlin.random.Random` | `KRandom.default` · `XorWowRandom(seed:)` (`Droid/KotlinCompat.swift`) |
| `list.random()` / `shuffled()` | `list.random(random: KRandom.default)` / `list.shuffled(random: KRandom.default)` |
| `x.roundToInt()` | `x.roundToInt()` (코틀린과 같은 반올림) |
| `coerceIn`·`coerceAtLeast`·`coerceAtMost` | 같은 이름 |
| `String.length`·`substring`·`indexOf` | 같은 이름 — **UTF-16 단위**(코틀린과 같다) |
| `"%d".format(x)` / `String.format(...)` | `"%d".format(x)` (자바 형식 그대로 처리) |
| `java.time.LocalDate` | `LocalDate` (`Droid/Kotlin.swift`) |
| `SimpleDateFormat`, `Calendar` | `SimpleDateFormat`, `JCalendar` |
| `java.util.Locale` | `JLocale` (`Locale.getDefault()` → `JLocale.getDefault()`) |
| `org.json.JSONObject(text)` | `JSONObject.parse(text)` 또는 `try JSONObject(text)` — 메서드 이름은 같다 |
| `assets.open(p).bufferedReader().use { it.readText() }` | `context.assets.open(p).readText()` |
| `File(filesDir, name)` | `context.filesDir.appendingPathComponent(name)` |
| 코틀린 문자 `Char` | 상황에 맞게 `Character` 또는 `Unicode.Scalar` — 이모지·한글 판정은 `unicodeScalars` 로 |

## 화면 (Droid 층)

- 단위: **1dp = 1pt**. 코틀린 `dp(x)` 도우미는 그대로 두되 값을 바꾸지 않는다
  (`resources.displayMetrics.density` 는 1 이다). `sp` 도 같다.
- 색은 `Int` (0xAARRGGBB). `Color.parseColor("#…")`, `0xFF4E342E.toInt()` → `0xFF4E342E`.
- `View`/`ViewGroup` 크기·위치는 `Int`: `width`, `height`, `measuredWidth`, `paddingLeft`…
- 직접 만든 화면 부품:
  ```swift
  final class ChickView: View {
      override init(_ context: Context, _ attrs: AttributeSet? = nil) {
          super.init(context, attrs)
          ...
      }
      required init?(coder: NSCoder) { fatalError() }
      override func onDraw(_ canvas: Canvas) { ... }
      override func onMeasure(_ widthMeasureSpec: Int, _ heightMeasureSpec: Int) { ... }
      override func onSizeChanged(_ w: Int, _ h: Int, _ oldw: Int, _ oldh: Int) { ... }
      override func onTouchEvent(_ event: MotionEvent) -> Bool { ... }
  }
  ```
  레이아웃 XML 에 쓰이는 부품은 이 `init(_:_:)` 이 꼭 있어야 한다(`Gen/Bindings.swift` 가 부른다).
- `LinearLayout`, `FrameLayout`, `GridLayout` 을 상속한 부품은 `ViewGroup` 메서드(`addView`, `removeAllViews`, `getChildAt`, `childCount`)를 그대로 쓴다.
  `LinearLayout.LayoutParams(w, h, weight)`, `FrameLayout.LayoutParams(w, h, gravity)`, `GridLayout.LayoutParams()`·`GridLayout.spec(...)`,
  `ViewGroup.LayoutParams.MATCH_PARENT` / `WRAP_CONTENT`, `ViewGroup.MarginLayoutParams` 다 있다.
- `View.tag` 는 `tagAny` 로 (UIView.tag 와 겹쳐서): `v.tag = x` → `v.tagAny = x`, `v.tag as Int` → `v.tagAny as! Int`.
- `view.alpha = 0.5f` → `view.alpha = 0.5` (UIView 의 CGFloat). Float 변수면 `view.alphaF = f`.
- `visibility = View.GONE`, `isVisible`, `isEnabled`, `translationX/Y`, `scaleX/Y`, `rotation`, `elevation` 그대로.
- `setOnClickListener { ... }` → `setOnClickListener { _ in ... }` (인자 하나: 눌린 View).
- `setOnTouchListener { v, e -> ... }` → `setOnTouchListener { v, e in ... }`.
- `post { }`, `postDelayed({ }, 300)`, `removeCallbacks(r)` — 취소할 일은 `Runnable { ... }` 상자에 담아 둔다.
  `Handler(Looper.getMainLooper())` 도 있다.
- 애니메이션: `ValueAnimator.ofFloat(0f, 1f)` → `ValueAnimator.ofFloat(0, 1)`, `it.animatedValue as Float` → `$0.animatedValue as! Float`
  (또는 `animatedFloat`). `view.animate().scaleX(1.1f).setDuration(120).withEndAction { }` 그대로.
  `object : AnimatorListenerAdapter() { override fun onAnimationEnd(...) }` → `AnimatorListenerAdapter(onEnd: { _ in ... })`.
- `Canvas`·`Paint`·`Path`·`RectF` 는 안드로이드 이름·인자 순서 그대로 (`canvas.drawText(s, x, y, paint)` 의 y 는 기준선).
  `paint.fontMetrics.ascent`, `paint.measureText(s)`, `Paint.Align.CENTER`, `Paint.Style.STROKE`, `Paint.Cap.ROUND`,
  `DashPathEffect(floatArrayOf(…), 0f)` → `DashPathEffect([…], 0)`.
- `TextView`: `text`, `textSize`(sp), `setTextColor(Int)`, `typeface`, `setTypeface(tf, Typeface.BOLD)`, `gravity`, `maxLines`,
  `ellipsize = TextUtils.TruncateAt.END`, `setLineSpacing(add, mult)`, `setPadding`, `setCompoundDrawablesRelativeWithIntrinsicBounds`,
  `setAutoSizeTextTypeUniformWithConfiguration(min, max, step, unit)` (TextViewCompat 이 하던 일).
  `text.toString()` → `text`.
- `Button(this)` 는 AppCompat 버튼(코드로 만든 안드로이드 버튼과 같은 모양). XML 의 `<Button>` 은 Material 버튼이다 — 바인딩이 알아서 만든다.
- `ImageView.setImageResource(R.drawable.x)`, `getDrawable(R.drawable.x)`, `GradientDrawable`, `ColorStateList.valueOf(c)`, `backgroundTintList` 그대로.
- `resources.getIdentifier("word_apple", "drawable", packageName)` 그대로 (없으면 0).
- `Activity`: `class MainActivity: AppCompatActivity { override func onCreate(_ savedInstanceState: SavedState?) { super.onCreate(savedInstanceState); ... } }`.
  `ActivityMainBinding.inflate(layoutInflater)`, `setContentView(b.root)`,
  `startActivity(Intent(self, LessonActivity.self).putExtra("mode", "review"))`, `intent.getStringExtra("x")`, `finish()`,
  `onResume`·`onPause`·`onDestroy` 덮어쓰기, `onBackPressedDispatcher.addCallback(self, OnBackPressedCallback(true) { _ in ... })`,
  `window.statusBarColor = c`.
  (`Activity` 에는 매개변수 없는 `required init()` 이 있다 — 하위 클래스가 init 을 따로 만들지 말고 속성은 기본값·`lazy`·`!` 로.)
- `Toast.makeText(this, "…", Toast.LENGTH_SHORT).show()`,
  `AlertDialog.Builder(this).setTitle(…).setItems(arr) { _, which in … }.setPositiveButton(…) { _, _ in … }.setNegativeButton(R.string.cancel, nil).show()`.
- 진동: `getSystemService(VIBRATOR_SERVICE) as Vibrator` → `getVibrator()`; 클립보드 → `getClipboard().setPrimaryClip(ClipData.newPlainText("", s))`.
- `SoundPool`, `TextToSpeech`, `UtteranceProgressListener` 도 같은 이름으로 있다(`Droid/Audio.swift`).
- DB: `SQLiteOpenHelper`, `SQLiteDatabase`(`rawQuery`·`execSQL`·`insertWithOnConflict`·`update`·`delete`), `Cursor`(`use { }`·`moveToFirst`·`getInt`…),
  `ContentValues` 그대로. `arrayOf(a, b)` → `[a, b]`. `runCatching { db.execSQL(...) }` → `db.tryExecSQL(...)`.

## 문구

화면 문구는 `getString(R.string.x)` / `getString(R.string.x, a, b)` 로 안드로이드와 같은 strings.xml 을 읽는다.
코틀린에 한국어 글자가 직접 박혀 있으면 **그대로** 둔다(안드로이드와 같게).

## 시험

- `XTest.kt` 의 시험 하나 → `func test_<원래 이름>()` (한글 이름이면 그대로, 띄어쓰기는 `_`).
- `assertEquals(기대, 실제)` → `XCTAssertEqual(실제, 기대)`, `assertTrue(msg, cond)` → `XCTAssertTrue(cond, msg)`.
- 맨 위: `import XCTest` / `@testable import PeepEnglish`.
- 안드로이드 원본 파일(`app/src/main/assets/packs`, `res/values/strings.xml`, `Db.kt`)을 읽는 시험은
  저장소 경로를 `URL(fileURLWithPath: #filePath)` 에서 거슬러 올라가 찾는다(`RepoPaths.swift` 의 `RepoPaths.androidMain`).
- 숫자·기대값은 바꾸지 않는다. 다르면 스위프트 쪽이 틀린 것이다.

## 주석·커밋

- 코틀린의 긴 "왜" 주석은 한두 줄로 줄여 옮기고, 아이폰에서 달라진 점만 따로 적는다.
- 커밋 메시지·주석·문서에 AI 로 만들었다는 흔적을 남기지 않는다(소유자 규칙).
