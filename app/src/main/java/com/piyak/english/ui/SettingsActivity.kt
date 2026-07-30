package com.piyak.english.ui

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
                    .setTitle("마지막 오류 기록")
                    .setMessage(crash.take(3000))
                    .setPositiveButton("복사") { _, _ ->
                        val cm = getSystemService(android.content.ClipboardManager::class.java)
                        cm?.setPrimaryClip(android.content.ClipData.newPlainText("crash", crash))
                        android.widget.Toast
                            .makeText(this, "복사했어요", android.widget.Toast.LENGTH_SHORT).show()
                    }
                    .setNegativeButton("지우기") { _, _ ->
                        com.piyak.english.PiyakApp.clearCrash(this)
                        b.btnCrash.visibility = android.view.View.GONE
                    }
                    .show()
            }
        }

        b.btnReset.setOnClickListener {
            AlertDialog.Builder(this)
                .setTitle("정말 초기화할까요?")
                .setMessage("모든 진행도·XP·배지·오답이 삭제돼요.\n되돌릴 수 없어요!")
                .setPositiveButton("초기화") { _, _ ->
                    db.resetAll()
                    android.widget.Toast.makeText(this, "초기화 완료! 처음부터 삐약! 🐣", android.widget.Toast.LENGTH_SHORT).show()
                }
                .setNegativeButton("취소", null).show()
        }
    }

    override fun onDestroy() { super.onDestroy(); tts.shutdown(); sfx.release() }
}
