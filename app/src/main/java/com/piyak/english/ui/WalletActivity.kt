package com.piyak.english.ui

import android.graphics.Color
import android.os.Bundle
import android.text.InputType
import android.view.Gravity
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.piyak.english.databinding.ActivityWalletBinding
import com.piyak.english.db.Db
import com.piyak.english.engine.Shop
import com.piyak.english.engine.ShopItem
import com.piyak.english.engine.ShopKind
import com.piyak.english.engine.Wallet
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** 지갑 · 상점 · 현금 지급 */
class WalletActivity : AppCompatActivity() {

    private lateinit var b: ActivityWalletBinding
    private lateinit var db: Db

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityWalletBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(this)
        b.btnBack.setOnClickListener { finish() }
        b.btnPayout.setOnClickListener { askPayout() }
        b.btnParent.setOnClickListener { parentSettings() }
    }

    override fun onResume() {
        super.onResume()
        refresh()
    }

    private fun refresh() {
        b.txtBalance.text = Wallet.format(db.coins())
        b.txtSummary.text =
            "지금까지 모은 돈 ${Wallet.format(db.coinsEarned())}\n" +
                "상점에서 쓴 돈 ${Wallet.format(db.coinsSpent())} · 현금으로 받은 돈 ${Wallet.format(db.coinsPaidOut())}"
        buildShop()
        buildLog()
    }

    // ---------------- 상점 ----------------

    private fun buildShop() {
        b.shopBox.removeAllViews()
        var lastKind: ShopKind? = null
        for (item in Shop.ITEMS) {
            if (item.kind != lastKind) {
                lastKind = item.kind
                b.shopBox.addView(TextView(this).apply {
                    text = when (item.kind) {
                        ShopKind.CONSUMABLE -> "쓰면 없어지는 것"
                        ShopKind.UPGRADE -> "영원히 남는 것"
                        ShopKind.STICKER -> "스티커 (홈에 자랑하기)"
                        ShopKind.THEME -> "테마 (홈 배경 바꾸기)"
                    }
                    textSize = 13f
                    setTextColor(Color.parseColor("#8D6E63"))
                    setPadding(dp(4), dp(12), 0, dp(4))
                })
            }
            b.shopBox.addView(shopRow(item))
        }
    }

    private fun shopRow(item: ShopItem): LinearLayout {
        val owned = when (item.kind) {
            ShopKind.STICKER, ShopKind.THEME -> db.ownsItem(item.id)
            else -> false
        }
        val equipped = when (item.kind) {
            ShopKind.STICKER -> db.equippedSticker() == item.emoji
            ShopKind.THEME -> db.themeColor() == item.color
            else -> false
        }
        val maxed = item.id == "heart_up" && db.maxHearts() >= Shop.MAX_HEARTS_CAP

        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(10), dp(12), dp(10))
            background = android.graphics.drawable.GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(Color.WHITE)
                setStroke(dp(2), Color.parseColor(if (equipped) "#66BB6A" else "#FFE082"))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(6) }
        }
        val iconRes = shopIconRes(item.id)
        if (iconRes != 0) row.addView(android.widget.ImageView(this).apply {
            setImageResource(iconRes)
            layoutParams = LinearLayout.LayoutParams(dp(46), dp(46))
        }) else row.addView(TextView(this).apply { text = item.emoji; textSize = 26f })
        val col = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            setPadding(dp(10), 0, dp(6), 0)
        }
        col.addView(TextView(this).apply {
            text = item.name
            textSize = 15f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        })
        col.addView(TextView(this).apply {
            text = when {
                item.id == "hint3" -> "${item.desc}  (가진 힌트권 ${db.itemCount("hint")}개)"
                item.id == "heart_up" -> "${item.desc}  (현재 최대 ${db.maxHearts()}개)"
                else -> item.desc
            }
            textSize = 11f
            setTextColor(Color.parseColor("#8D6E63"))
        })
        row.addView(col)

        val btn = Button(this).apply {
            isAllCaps = false
            textSize = 13f
            minWidth = 0
            minimumWidth = 0
            setPadding(dp(14), 0, dp(14), 0)
            when {
                maxed -> {
                    text = "최대"
                    isEnabled = false
                }
                equipped -> {
                    text = "사용 중"
                    isEnabled = false
                    setBackgroundColorTint("#66BB6A")
                    setTextColor(Color.WHITE)
                }
                owned -> {
                    text = "적용"
                    setBackgroundColorTint("#81D4FA")
                    setTextColor(Color.parseColor("#4E342E"))
                    setOnClickListener { equip(item) }
                }
                else -> {
                    text = Wallet.format(item.price)
                    val affordable = db.coins() >= item.price
                    setBackgroundColorTint(if (affordable) "#FFD54F" else "#EDE7E0")
                    setTextColor(Color.parseColor("#4E342E"))
                    setOnClickListener { buy(item) }
                }
            }
        }
        row.addView(btn)
        return row
    }

    private fun Button.setBackgroundColorTint(hex: String) {
        backgroundTintList = android.content.res.ColorStateList.valueOf(Color.parseColor(hex))
    }

    private fun buy(item: ShopItem) {
        if (db.coins() < item.price) {
            Toast.makeText(
                this, "용돈이 ${Wallet.format(item.price - db.coins())} 모자라요. 문제를 더 풀어 봐요! 🐥",
                Toast.LENGTH_SHORT
            ).show()
            return
        }
        AlertDialog.Builder(this)
            .setTitle("${item.emoji} ${item.name}")
            .setMessage("${item.desc}\n\n${Wallet.format(item.price)}을 쓸까요?\n(남는 돈 ${Wallet.format(db.coins() - item.price)})")
            .setPositiveButton("살래요") { _, _ -> doBuy(item) }
            .setNegativeButton("다음에", null)
            .show()
    }

    private fun doBuy(item: ShopItem) {
        if (!db.spendCoins(item.price, "BUY", "${item.emoji} ${item.name}")) return
        when (item.kind) {
            ShopKind.CONSUMABLE -> when (item.id) {
                "heart_refill" -> {
                    db.setHearts(db.maxHearts())
                    toast("하트가 가득 찼어요! ❤️ ${db.maxHearts()}")
                }
                "hint3" -> {
                    db.addItem("hint", item.amount)
                    toast("힌트권 ${item.amount}개를 받았어요! 💡")
                }
            }
            ShopKind.UPGRADE -> if (item.id == "heart_up") {
                db.setMaxHearts((db.maxHearts() + 1).coerceAtMost(Shop.MAX_HEARTS_CAP))
                db.setHearts(db.maxHearts())
                toast("이제 하트를 ${db.maxHearts()}개까지 가질 수 있어요! ❤️‍🔥")
            }
            ShopKind.STICKER -> {
                db.addItem(item.id, 1)
                db.setEquippedSticker(item.emoji)
                toast("${item.emoji} 스티커를 홈에 붙였어요!")
            }
            ShopKind.THEME -> {
                db.addItem(item.id, 1)
                db.setThemeColor(item.color)
                toast("${item.name}로 바꿨어요! ${item.emoji}")
            }
        }
        refresh()
    }

    private fun equip(item: ShopItem) {
        when (item.kind) {
            ShopKind.STICKER -> { db.setEquippedSticker(item.emoji); toast("${item.emoji} 스티커를 붙였어요!") }
            ShopKind.THEME -> { db.setThemeColor(item.color); toast("${item.name} 적용!") }
            else -> {}
        }
        refresh()
    }

    // ---------------- 현금 지급 ----------------

    private fun askPayout() {
        if (db.coins() <= 0) {
            toast("아직 바꿀 용돈이 없어요 🐣")
            return
        }
        val presets = Shop.PAYOUT_PRESETS.filter { it <= db.coins() }
        val labels = (presets.map { Wallet.format(it) } + "전액 ${Wallet.format(db.coins())}" + "직접 입력")
            .toTypedArray()
        AlertDialog.Builder(this)
            .setTitle("💵 현금으로 바꾸기")
            .setItems(labels) { _, i ->
                when {
                    i < presets.size -> confirmPayout(presets[i])
                    i == presets.size -> confirmPayout(db.coins())
                    else -> customPayout()
                }
            }
            .setNegativeButton("취소", null)
            .show()
    }

    private fun customPayout() {
        val input = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER
            hint = "얼마를 드릴까요? (최대 ${db.coins()})"
            setPadding(dp(20), dp(16), dp(20), dp(16))
        }
        AlertDialog.Builder(this)
            .setTitle("금액 입력")
            .setView(input)
            .setPositiveButton("확인") { _, _ ->
                val v = input.text.toString().toIntOrNull() ?: 0
                if (v in 1..db.coins()) confirmPayout(v)
                else toast("금액을 다시 확인해 주세요")
            }
            .setNegativeButton("취소", null)
            .show()
    }

    private fun confirmPayout(amount: Int) {
        val doPay = {
            if (db.spendCoins(amount, "PAYOUT", "현금으로 받음")) {
                AlertDialog.Builder(this)
                    .setTitle("🎉 ${Wallet.format(amount)} 지급 완료!")
                    .setMessage(
                        "부모님이 ${Wallet.format(amount)}을 현금으로 주셨어요.\n" +
                            "남은 용돈: ${Wallet.format(db.coins())}\n\n열심히 공부한 보람이 있네요! 🐥"
                    )
                    .setPositiveButton("좋아요!", null)
                    .show()
                refresh()
            }
        }
        if (db.hasParentPin()) askPin("부모님 비밀번호를 넣어 주세요") { ok -> if (ok) doPay() }
        else {
            AlertDialog.Builder(this)
                .setTitle("부모님 확인")
                .setMessage(
                    "${Wallet.format(amount)}을 현금으로 주시겠어요?\n" +
                        "확인을 누르면 지갑에서 빠지고 기록에 남아요.\n\n" +
                        "(설정에서 비밀번호를 걸면 아이가 혼자 누를 수 없어요)"
                )
                .setPositiveButton("현금 줬어요") { _, _ -> doPay() }
                .setNegativeButton("취소", null)
                .show()
        }
    }

    // ---------------- 부모 설정 ----------------

    private fun parentSettings() {
        val has = db.hasParentPin()
        val options = if (has) arrayOf("비밀번호 바꾸기", "비밀번호 없애기")
        else arrayOf("비밀번호 만들기 (현금 지급 잠금)")
        AlertDialog.Builder(this)
            .setTitle("🔒 부모 설정")
            .setItems(options) { _, i ->
                if (!has) newPin()
                else if (i == 0) askPin("지금 비밀번호") { ok -> if (ok) newPin() }
                else askPin("지금 비밀번호") { ok -> if (ok) { db.setParentPin(""); toast("비밀번호를 없앴어요") } }
            }
            .setNegativeButton("닫기", null)
            .show()
    }

    private fun newPin() {
        val input = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            hint = "숫자 4자리"
            setPadding(dp(20), dp(16), dp(20), dp(16))
        }
        AlertDialog.Builder(this)
            .setTitle("새 비밀번호")
            .setView(input)
            .setPositiveButton("저장") { _, _ ->
                val p = input.text.toString()
                if (p.length == 4) { db.setParentPin(p); toast("비밀번호를 저장했어요 🔒") }
                else toast("숫자 4자리로 만들어 주세요")
            }
            .setNegativeButton("취소", null)
            .show()
    }

    private fun askPin(title: String, cb: (Boolean) -> Unit) {
        val input = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            hint = "숫자 4자리"
            setPadding(dp(20), dp(16), dp(20), dp(16))
        }
        AlertDialog.Builder(this)
            .setTitle(title)
            .setView(input)
            .setPositiveButton("확인") { _, _ ->
                val ok = input.text.toString() == db.parentPin()
                if (!ok) toast("비밀번호가 달라요")
                cb(ok)
            }
            .setNegativeButton("취소") { _, _ -> cb(false) }
            .show()
    }

    // ---------------- 기록 ----------------

    private fun buildLog() {
        b.logBox.removeAllViews()
        val logs = db.walletLog(30)
        if (logs.isEmpty()) {
            b.logBox.addView(TextView(this).apply {
                text = "아직 기록이 없어요. 문제를 풀어 용돈을 모아 봐요! 🐥"
                textSize = 13f
                setTextColor(Color.parseColor("#8D6E63"))
                setPadding(dp(4), dp(8), 0, 0)
            })
            return
        }
        val fmt = SimpleDateFormat("M/d HH:mm", Locale.KOREA)
        for (log in logs) {
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(4), dp(7), dp(4), dp(7))
            }
            row.addView(TextView(this).apply {
                text = when (log.kind) {
                    "LESSON" -> "📚"; "LETTER" -> "✏️"; "REVIEW" -> "💊"
                    "GOAL" -> "🎯"; "PLACEMENT" -> "🎓"; "BUY" -> "🛒"; "PAYOUT" -> "💵"
                    "LEGACY" -> "🎁"
                    else -> "•"
                }
                textSize = 16f
                width = dp(28)
            })
            val col = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            col.addView(TextView(this).apply {
                text = log.note.ifEmpty { log.kind }
                textSize = 13f
                maxLines = 2
            })
            col.addView(TextView(this).apply {
                text = fmt.format(Date(log.at))
                textSize = 10f
                setTextColor(Color.parseColor("#A1887F"))
            })
            row.addView(col)
            row.addView(TextView(this).apply {
                text = (if (log.isEarn) "+" else "") + Wallet.format(log.amount)
                textSize = 14f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                setTextColor(Color.parseColor(if (log.isEarn) "#43A047" else "#E53935"))
            })
            b.logBox.addView(row)
        }
    }

    private fun toast(s: String) = Toast.makeText(this, s, Toast.LENGTH_SHORT).show()

    /** codex 상점 일러스트 (발주서 #04) — 그림이 없는 아이템은 이모지로 보여준다 */
    private fun shopIconRes(id: String): Int {
        val name = when (id) {
            "heart_refill" -> "shop_heart"
            "heart_up" -> "shop_heart_plus"
            "hint3" -> "shop_hint"
            "st_star" -> "shop_sticker_star"
            "st_crown" -> "shop_sticker_crown"
            "st_rainbow" -> "shop_sticker_rainbow"
            "st_rocket" -> "shop_sticker_rocket"
            "th_pink" -> "shop_theme_pink"
            "th_mint" -> "shop_theme_mint"
            "th_sky" -> "shop_theme_sky"
            else -> return 0
        }
        return resources.getIdentifier(name, "drawable", packageName)
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}
