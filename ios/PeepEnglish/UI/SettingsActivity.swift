import UIKit

final class SettingsActivity: AppCompatActivity {

    private var b: ActivitySettingsBinding!
    private var db: Db!
    private var tts: Tts!
    private var sfx: Sfx!

    override func onCreate(_ savedInstanceState: SavedState?) {
        super.onCreate(savedInstanceState)
        b = ActivitySettingsBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(self)
        tts = Tts(self)
        sfx = Sfx(self)

        b.btnBack.setOnClickListener { [weak self] _ in self?.finish() }
        setupLanguageRow()

        // 발음 속도: 0.5x ~ 1.9x (0.1 단위)
        let savedRate = db.meta("tts_rate", "1.0").toFloatOrNull() ?? 1.0
        b.seekRate.progress = ((savedRate - 0.5) / 0.1).toInt().coerceIn(0, 14)
        b.txtRate.text = "%.1fx".format(savedRate)
        b.seekRate.setOnSeekBarChangeListener(SeekBarListener(changed: { [weak self] _, p, _ in
            guard let self else { return }
            let r: Float = 0.5 + Float(p) * 0.1
            self.b.txtRate.text = "%.1fx".format(r)
            self.db.setMeta("tts_rate", String(r))
        }))
        b.btnTtsTest.setOnClickListener { [weak self] _ in
            guard let self else { return }
            self.tts.rate = self.db.meta("tts_rate", "1.0").toFloatOrNull() ?? 1.0
            self.tts.speak("Hello! Nice to meet you. Let's study English together!")
        }

        // 효과음 크기 (TTS 를 덮지 않게 기본 30%)
        let sfxPct = db.metaInt("sfx_volume", Sfx.DEFAULT_VOLUME_PERCENT)
        b.seekSfx.progress = sfxPct
        b.txtSfx.text = "\(sfxPct)%"
        b.seekSfx.setOnSeekBarChangeListener(SeekBarListener(
            changed: { [weak self] _, p, _ in
                guard let self else { return }
                self.b.txtSfx.text = "\(p)%"
                self.db.setMeta("sfx_volume", String(p))
                self.sfx.volume = Float(p) / 100
            },
            stop: { [weak self] _ in self?.sfx.correct() }
        ))
        b.btnSfxTest.setOnClickListener { [weak self] _ in self?.sfx.correct() }

        b.switchHearts.isChecked = db.heartsEnabled()
        b.switchHearts.setOnCheckedChangeListener { [weak self] _, on in self?.db.setHeartsEnabled(on) }

        b.switchFree.isChecked = db.meta("free_mode") == "1"
        b.switchFree.setOnCheckedChangeListener { [weak self] _, on in
            self?.db.setMeta("free_mode", on ? "1" : "0")
        }

        b.btnPlacement.setOnClickListener { [weak self] _ in
            guard let self else { return }
            self.startActivity(Intent(self, PlacementActivity.self))
        }

        // 앱이 죽은 적이 있으면 그 기록을 꺼내 볼 수 있게
        let crash = PiyakApp.lastCrash(self)
        if let crash {
            b.btnCrash.visibility = View.VISIBLE
            b.btnCrash.setOnClickListener { [weak self] _ in
                guard let self else { return }
                AlertDialog.Builder(self)
                    .setTitle(self.getString(R.string.crash_title))
                    .setMessage(crash.take(3000))
                    .setPositiveButton(self.getString(R.string.copy)) { _, _ in
                        self.getClipboard().setPrimaryClip(ClipData.newPlainText("crash", crash))
                        Toast.makeText(self, self.getString(R.string.copied), Toast.LENGTH_SHORT).show()
                    }
                    .setNegativeButton(self.getString(R.string.clear)) { _, _ in
                        PiyakApp.clearCrash(self)
                        self.b.btnCrash.visibility = View.GONE
                    }
                    .show()
            }
        }

        b.btnReset.setOnClickListener { [weak self] _ in
            guard let self else { return }
            AlertDialog.Builder(self)
                .setTitle(self.getString(R.string.reset_ask))
                .setMessage(self.getString(R.string.reset_msg))
                .setPositiveButton(self.getString(R.string.reset_do)) { _, _ in
                    self.db.resetAll()
                    Toast.makeText(self, self.getString(R.string.reset_done), Toast.LENGTH_SHORT).show()
                }
                .setNegativeButton(self.getString(R.string.cancel), nil).show()
        }
    }

    override func onDestroy() { super.onDestroy(); tts?.shutdown(); sfx?.release() }

    /// 앱 언어 고르기 — 기기 언어를 바꾸지 않고 이 앱만. 목록의 언어 이름은 그 언어로 적는다.
    private let langTags = [
        "", "ko", "en", "ja", "zh", "zh-TW", "zh-HK", "es", "fr", "de", "pt", "ru", "vi", "id", "th",
    ]
    private lazy var langNames: [String] = [
        getString(R.string.ly_lang_system), "한국어", "English", "日本語", "简体中文",
        "繁體中文（台灣）", "繁體中文（香港）", "Español", "Français", "Deutsch",
        "Português", "Русский", "Tiếng Việt", "Bahasa Indonesia", "ไทย",
    ]

    private func currentLangIndex() -> Int {
        let cur = AppCompatDelegate.getApplicationLocales()
        if cur.isEmpty { return 0 }
        let tag = cur.toLanguageTags().components(separatedBy: ",").first ?? ""
        let exact = langTags.indexOfFirst { !$0.isEmpty && $0.equals(tag, ignoreCase: true) }
        if exact >= 0 { return exact }
        // "ru-RU" 처럼 지역이 붙어 오면 언어만 맞춰 본다
        let lang = tag.components(separatedBy: "-").first ?? ""
        let loose = langTags.indexOfFirst {
            !$0.isEmpty && ($0.components(separatedBy: "-").first ?? "").equals(lang, ignoreCase: true)
        }
        return loose >= 0 ? loose : 0
    }

    private func setupLanguageRow() {
        b.txtLanguage.text = langNames[currentLangIndex()]
        b.rowLanguage.setOnClickListener { [weak self] _ in
            guard let self else { return }
            AlertDialog.Builder(self)
                .setTitle(R.string.ly_language)
                .setSingleChoiceItems(self.langNames, self.currentLangIndex()) { d, which in
                    d.dismiss()
                    // 팩은 언어에 맞춰 걸러 놓은 것이라 캐시를 비워야 새 언어로 다시 읽힌다
                    ContentRepo.clearCache()
                    AppCompatDelegate.setApplicationLocales(
                        self.langTags[which].isEmpty
                            ? LocaleListCompat.getEmptyLocaleList()
                            : LocaleListCompat.forLanguageTags(self.langTags[which])
                    )
                }
                // 안드로이드 시스템 '취소' 대신 앱의 같은 문구
                .setNegativeButton(R.string.cancel, nil)
                .show()
        }
    }
}
