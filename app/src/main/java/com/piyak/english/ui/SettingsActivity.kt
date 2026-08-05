package com.piyak.english.ui

import com.piyak.english.R
import android.content.Intent
import android.os.Bundle
import android.widget.SeekBar
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.piyak.english.audio.Tts
import com.piyak.english.databinding.ActivitySettingsBinding
import com.piyak.english.db.Db

class SettingsActivity : AppCompatActivity() {

    private lateinit var b: ActivitySettingsBinding
    private lateinit var db: Db
    private lateinit var tts: Tts
    private lateinit var sfx: com.piyak.english.audio.Sfx

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivitySettingsBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(this)
        tts = Tts(this)
        sfx = com.piyak.english.audio.Sfx(this)

        b.btnBack.setOnClickListener { finish() }
        setupLanguageRow()

        // 발음 속도: 0.5x ~ 1.9x (0.1 단위)
        val savedRate = db.meta("tts_rate", "1.0").toFloatOrNull() ?: 1.0f
        b.seekRate.progress = ((savedRate - 0.5f) / 0.1f).toInt().coerceIn(0, 14)
        b.txtRate.text = String.format("%.1fx", savedRate)
        b.seekRate.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar?, p: Int, fromUser: Boolean) {
                val r = 0.5f + p * 0.1f
                b.txtRate.text = String.format("%.1fx", r)
                db.setMeta("tts_rate", r.toString())
            }
            override fun onStartTrackingTouch(sb: SeekBar?) {}
            override fun onStopTrackingTouch(sb: SeekBar?) {}
        })
        b.btnTtsTest.setOnClickListener {
            tts.rate = db.meta("tts_rate", "1.0").toFloatOrNull() ?: 1.0f
            tts.speak("Hello! Nice to meet you. Let's study English together!")
        }

        // 효과음 크기 (TTS 를 덮지 않게 기본 30%)
        val sfxPct = db.metaInt("sfx_volume", com.piyak.english.audio.Sfx.DEFAULT_VOLUME_PERCENT)
        b.seekSfx.progress = sfxPct
        b.txtSfx.text = "$sfxPct%"
        b.seekSfx.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar?, p: Int, fromUser: Boolean) {
                b.txtSfx.text = "$p%"
                db.setMeta("sfx_volume", p.toString())
                sfx.volume = p / 100f
            }
            override fun onStartTrackingTouch(sb: SeekBar?) {}
            override fun onStopTrackingTouch(sb: SeekBar?) { sfx.correct() }
        })
        b.btnSfxTest.setOnClickListener { sfx.correct() }

        b.switchHearts.isChecked = db.heartsEnabled()
        b.switchHearts.setOnCheckedChangeListener { _, on -> db.setHeartsEnabled(on) }

        b.switchFree.isChecked = db.meta("free_mode") == "1"
        b.switchFree.setOnCheckedChangeListener { _, on ->
            db.setMeta("free_mode", if (on) "1" else "0")
        }

        b.btnPlacement.setOnClickListener {
            startActivity(Intent(this, PlacementActivity::class.java))
        }

        // 앱이 죽은 적이 있으면 그 기록을 꺼내 볼 수 있게 (USB 로 로그를 못 뽑을 때가 잦다)
        val crash = com.piyak.english.PiyakApp.lastCrash(this)
        if (crash != null) {
            b.btnCrash.visibility = android.view.View.VISIBLE
            b.btnCrash.setOnClickListener {
                AlertDialog.Builder(this)
                    .setTitle(getString(R.string.crash_title))
                    .setMessage(crash.take(3000))
                    .setPositiveButton(getString(R.string.copy)) { _, _ ->
                        val cm = getSystemService(android.content.ClipboardManager::class.java)
                        cm?.setPrimaryClip(android.content.ClipData.newPlainText("crash", crash))
                        android.widget.Toast
                            .makeText(this, getString(R.string.copied), android.widget.Toast.LENGTH_SHORT).show()
                    }
                    .setNegativeButton(getString(R.string.clear)) { _, _ ->
                        com.piyak.english.PiyakApp.clearCrash(this)
                        b.btnCrash.visibility = android.view.View.GONE
                    }
                    .show()
            }
        }

        b.btnReset.setOnClickListener {
            AlertDialog.Builder(this)
                .setTitle(getString(R.string.reset_ask))
                .setMessage(getString(R.string.reset_msg))
                .setPositiveButton(getString(R.string.reset_do)) { _, _ ->
                    db.resetAll()
                    android.widget.Toast.makeText(this, getString(R.string.reset_done), android.widget.Toast.LENGTH_SHORT).show()
                }
                .setNegativeButton(getString(R.string.cancel), null).show()
        }
    }

    override fun onDestroy() { super.onDestroy(); tts.shutdown(); sfx.release() }

    /**
     * 앱 언어 고르기.
     *
     * 폰 전체 언어를 바꾸지 않고 이 앱만 다른 언어로 볼 수 있어야 한다.
     * 목록의 언어 이름은 **그 언어로** 적는다(Deutsch, ไทย …) — 번역하지 않는다.
     */
    private val langTags = listOf(
        "", "ko", "en", "ja", "zh", "zh-TW", "zh-HK", "es", "fr", "de", "pt", "ru", "vi", "id", "th"
    )
    private val langNames by lazy {
        listOf(
            getString(R.string.ly_lang_system), "한국어", "English", "日本語", "简体中文",
            "繁體中文（台灣）", "繁體中文（香港）", "Español", "Français", "Deutsch",
            "Português", "Русский", "Tiếng Việt", "Bahasa Indonesia", "ไทย"
        )
    }

    private fun currentLangIndex(): Int {
        val cur = androidx.appcompat.app.AppCompatDelegate.getApplicationLocales()
        if (cur.isEmpty) return 0
        val tag = cur.toLanguageTags().substringBefore(',')
        val exact = langTags.indexOfFirst { it.isNotEmpty() && it.equals(tag, true) }
        if (exact >= 0) return exact
        // "ru-RU" 처럼 지역이 붙어 오면 언어만 맞춰 본다
        val lang = tag.substringBefore('-')
        val loose = langTags.indexOfFirst { it.isNotEmpty() && it.substringBefore('-').equals(lang, true) }
        return if (loose >= 0) loose else 0
    }

    private fun setupLanguageRow() {
        b.txtLanguage.text = langNames[currentLangIndex()]
        b.rowLanguage.setOnClickListener {
            AlertDialog.Builder(this)
                .setTitle(R.string.ly_language)
                .setSingleChoiceItems(langNames.toTypedArray(), currentLangIndex()) { d, which ->
                    d.dismiss()
                    // 팩은 언어에 맞춰 걸러 놓은 것이라 캐시를 비워야 새 언어로 다시 읽힌다
                    com.piyak.english.model.ContentRepo.clearCache()
                    androidx.appcompat.app.AppCompatDelegate.setApplicationLocales(
                        if (langTags[which].isEmpty())
                            androidx.core.os.LocaleListCompat.getEmptyLocaleList()
                        else androidx.core.os.LocaleListCompat.forLanguageTags(langTags[which])
                    )
                }
                .setNegativeButton(android.R.string.cancel, null)
                .show()
        }
    }

}
