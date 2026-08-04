package com.piyak.english.ui

import com.piyak.english.R

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
        b.txtBalance.text = Wallet.format(this, db.coins())
        b.txtSummary.text =
            getString(R.string.wallet_earned, Wallet.format(this, db.coinsEarned())) + "\n" +
                getString(R.string.wallet_spent, Wallet.format(this, db.coinsSpent()), Wallet.format(this, db.coinsPaidOut()))
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
                        ShopKind.CONSUMABLE -> getString(R.string.shop_g_consumable)
                        ShopKind.UPGRADE -> getString(R.string.shop_g_upgrade)
                        ShopKind.STICKER -> getString(R.string.shop_g_sticker)
                        ShopKind.THEME -> getString(R.string.shop_g_theme)
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
            text = getString(item.nameRes)
            textSize = 15f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        })
        col.addView(TextView(this).apply {
            text = when {
                item.id == "hint3" -> getString(R.string.shop_hint_have, getString(item.descRes), db.itemCount("hint"))
                item.id == "heart_up" -> getString(R.string.shop_heart_have, getString(item.descRes), db.maxHearts())
                else -> getString(item.descRes)
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
                    text = getString(R.string.shop_maxed)
                    isEnabled = false
                }
                equipped -> {
                    text = getString(R.string.shop_in_use)
                    isEnabled = false
                    setBackgroundColorTint("#66BB6A")
                    setTextColor(Color.WHITE)
                }
                owned -> {
                    text = getString(R.string.shop_apply)
                    setBackgroundColorTint("#81D4FA")
                    setTextColor(Color.parseColor("#4E342E"))
                    setOnClickListener { equip(item) }
                }
                else -> {
                    text = Wallet.format(this@WalletActivity, item.price)
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
                this, getString(R.string.shop_not_enough, Wallet.format(this, item.price - db.coins())),
                Toast.LENGTH_SHORT
            ).show()
            return
        }
        AlertDialog.Builder(this)
            .setTitle("${item.emoji} " + getString(item.nameRes))
            .setMessage(getString(R.string.shop_buy_ask, getString(item.descRes), Wallet.format(this, item.price), Wallet.format(this, db.coins() - item.price)))
            .setPositiveButton(getString(R.string.shop_buy_yes)) { _, _ -> doBuy(item) }
            .setNegativeButton(getString(R.string.shop_buy_later), null)
            .show()
    }

    private fun doBuy(item: ShopItem) {
        if (!db.spendCoins(item.price, "BUY", "${item.emoji} " + getString(item.nameRes))) return
        when (item.kind) {
            ShopKind.CONSUMABLE -> when (item.id) {
                "heart_refill" -> {
                    db.setHearts(db.maxHearts())
                    toast(getString(R.string.shop_heart_full, db.maxHearts()))
                }
                "hint3" -> {
                    db.addItem("hint", item.amount)
                    toast(getString(R.string.shop_got_hints, item.amount))
                }
            }
            ShopKind.UPGRADE -> if (item.id == "heart_up") {
                db.setMaxHearts((db.maxHearts() + 1).coerceAtMost(Shop.MAX_HEARTS_CAP))
                db.setHearts(db.maxHearts())
                toast(getString(R.string.shop_heart_up_done, db.maxHearts()))
            }
            ShopKind.STICKER -> {
                db.addItem(item.id, 1)
                db.setEquippedSticker(item.emoji)
                toast(getString(R.string.shop_sticker_on, item.emoji))
            }
            ShopKind.THEME -> {
                db.addItem(item.id, 1)
                db.setThemeColor(item.color)
                toast(getString(R.string.shop_theme_on, getString(item.nameRes), item.emoji))
            }
        }
        refresh()
    }

    private fun equip(item: ShopItem) {
        when (item.kind) {
            ShopKind.STICKER -> { db.setEquippedSticker(item.emoji); toast(getString(R.string.shop_sticker_on, item.emoji)) }
            ShopKind.THEME -> { db.setThemeColor(item.color); toast(getString(R.string.shop_applied, getString(item.nameRes))) }
            else -> {}
        }
        refresh()
    }

    // ---------------- 현금 지급 ----------------

    private fun askPayout() {
        if (db.coins() <= 0) {
            toast(getString(R.string.pay_no_money))
            return
        }
        val presets = Shop.PAYOUT_PRESETS.filter { it <= db.coins() }
        val labels = (presets.map { Wallet.format(this, it) } + getString(R.string.pay_all, Wallet.format(this, db.coins())) + getString(R.string.pay_custom))
            .toTypedArray()
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.wallet_cash_out))
            .setItems(labels) { _, i ->
                when {
                    i < presets.size -> confirmPayout(presets[i])
                    i == presets.size -> confirmPayout(db.coins())
                    else -> customPayout()
                }
            }
            .setNegativeButton(getString(R.string.cancel), null)
            .show()
    }

    private fun customPayout() {
        val input = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER
            hint = getString(R.string.pay_how_much, db.coins())
            setPadding(dp(20), dp(16), dp(20), dp(16))
        }
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.pay_enter_amount))
            .setView(input)
            .setPositiveButton(getString(R.string.confirm)) { _, _ ->
                val v = input.text.toString().toIntOrNull() ?: 0
                if (v in 1..db.coins()) confirmPayout(v)
                else toast(getString(R.string.pay_bad_amount))
            }
            .setNegativeButton(getString(R.string.cancel), null)
            .show()
    }

    private fun confirmPayout(amount: Int) {
        val doPay = {
            if (db.spendCoins(amount, "PAYOUT", getString(R.string.pay_log))) {
                AlertDialog.Builder(this)
                    .setTitle(getString(R.string.pay_done_title, Wallet.format(this, amount)))
                    .setMessage(
                        getString(R.string.pay_done_msg, Wallet.format(this, amount), Wallet.format(this, db.coins())) + "" +
                            ""
                    )
                    .setPositiveButton(getString(R.string.ok_nice), null)
                    .show()
                refresh()
            }
        }
        if (db.hasParentPin()) askPin(getString(R.string.pin_ask)) { ok -> if (ok) doPay() }
        else {
            AlertDialog.Builder(this)
                .setTitle(getString(R.string.pay_confirm_title))
                .setMessage(
                    getString(R.string.pay_confirm_msg, Wallet.format(this, amount)) + "" +
                        ""
                )
                .setPositiveButton(getString(R.string.pay_gave)) { _, _ -> doPay() }
                .setNegativeButton(getString(R.string.cancel), null)
                .show()
        }
    }

    // ---------------- 부모 설정 ----------------

    private fun parentSettings() {
        val has = db.hasParentPin()
        val options = if (has) arrayOf(getString(R.string.pin_change), getString(R.string.pin_remove))
        else arrayOf(getString(R.string.pin_create))
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.set_parent))
            .setItems(options) { _, i ->
                if (!has) newPin()
                else if (i == 0) askPin(getString(R.string.pin_current)) { ok -> if (ok) newPin() }
                else askPin(getString(R.string.pin_current)) { ok -> if (ok) { db.setParentPin(""); toast(getString(R.string.pin_removed)) } }
            }
            .setNegativeButton(getString(R.string.close), null)
            .show()
    }

    private fun newPin() {
        val input = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            hint = getString(R.string.pin_hint)
            setPadding(dp(20), dp(16), dp(20), dp(16))
        }
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.pin_new))
            .setView(input)
            .setPositiveButton(getString(R.string.save)) { _, _ ->
                val p = input.text.toString()
                if (p.length == 4) { db.setParentPin(p); toast(getString(R.string.pin_saved)) }
                else toast(getString(R.string.pin_need4))
            }
            .setNegativeButton(getString(R.string.cancel), null)
            .show()
    }

    private fun askPin(title: String, cb: (Boolean) -> Unit) {
        val input = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            hint = getString(R.string.pin_hint)
            setPadding(dp(20), dp(16), dp(20), dp(16))
        }
        AlertDialog.Builder(this)
            .setTitle(title)
            .setView(input)
            .setPositiveButton(getString(R.string.confirm)) { _, _ ->
                val ok = input.text.toString() == db.parentPin()
                if (!ok) toast(getString(R.string.pin_wrong))
                cb(ok)
            }
            .setNegativeButton(getString(R.string.cancel)) { _, _ -> cb(false) }
            .show()
    }

    // ---------------- 기록 ----------------

    private fun buildLog() {
        b.logBox.removeAllViews()
        val logs = db.walletLog(30)
        if (logs.isEmpty()) {
            b.logBox.addView(TextView(this).apply {
                text = getString(R.string.wallet_no_log)
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
                text = (if (log.isEarn) "+" else "") + Wallet.format(this@WalletActivity, log.amount)
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
            "th_lav" -> "shop_theme_lavender"
            "st_dino" -> "shop_sticker_dino"
            "st_cake" -> "shop_sticker_cake"
            "st_medal" -> "shop_sticker_medal"
            "st_unicorn" -> "shop_sticker_unicorn"
            else -> return 0
        }
        return resources.getIdentifier(name, "drawable", packageName)
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}
