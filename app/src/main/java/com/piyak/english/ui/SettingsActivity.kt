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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivitySettingsBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(this)
        tts = Tts(this)

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

        b.switchFree.isChecked = db.meta("free_mode") == "1"
        b.switchFree.setOnCheckedChangeListener { _, on ->
            db.setMeta("free_mode", if (on) "1" else "0")
        }

        b.btnPlacement.setOnClickListener {
            startActivity(Intent(this, PlacementActivity::class.java))
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

    override fun onDestroy() { super.onDestroy(); tts.shutdown() }
}
