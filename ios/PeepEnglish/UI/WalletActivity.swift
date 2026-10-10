import UIKit

/// 지갑 · 상점 · 현금 지급
final class WalletActivity: AppCompatActivity {

    private var b: ActivityWalletBinding!
    private var db: Db!

    override func onCreate(_ savedInstanceState: SavedState?) {
        super.onCreate(savedInstanceState)
        b = ActivityWalletBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(self)
        b.btnBack.setOnClickListener { [weak self] _ in self?.finish() }
        b.btnPayout.setOnClickListener { [weak self] _ in self?.askPayout() }
        b.btnParent.setOnClickListener { [weak self] _ in self?.parentSettings() }
    }

    override func onResume() {
        super.onResume()
        refresh()
    }

    private func refresh() {
        b.txtBalance.text = Wallet.format(self, db.coins())
        b.txtSummary.text =
            getString(R.string.wallet_earned, Wallet.format(self, db.coinsEarned())) + "\n" +
            getString(R.string.wallet_spent, Wallet.format(self, db.coinsSpent()), Wallet.format(self, db.coinsPaidOut()))
        buildShop()
        buildLog()
    }

    // ---------------- 상점 ----------------

    private func buildShop() {
        b.shopBox.removeAllViews()
        var lastKind: ShopKind? = nil
        for item in Shop.ITEMS {
            if item.kind != lastKind {
                lastKind = item.kind
                let head = TextView(self)
                switch item.kind {
                case .CONSUMABLE: head.text = getString(R.string.shop_g_consumable)
                case .UPGRADE: head.text = getString(R.string.shop_g_upgrade)
                case .STICKER: head.text = getString(R.string.shop_g_sticker)
                case .THEME: head.text = getString(R.string.shop_g_theme)
                }
                head.textSize = 13
                head.setTextColor(Color.parseColor("#8D6E63"))
                head.setPadding(dp(4), dp(12), 0, dp(4))
                b.shopBox.addView(head)
            }
            b.shopBox.addView(shopRow(item))
        }
    }

    private func shopRow(_ item: ShopItem) -> LinearLayout {
        let owned: Bool
        switch item.kind {
        case .STICKER, .THEME: owned = db.ownsItem(item.id)
        default: owned = false
        }
        let equipped: Bool
        switch item.kind {
        case .STICKER: equipped = db.equippedSticker() == item.emoji
        case .THEME: equipped = db.themeColor() == item.color
        default: equipped = false
        }
        let maxed = item.id == "heart_up" && db.maxHearts() >= Shop.MAX_HEARTS_CAP

        let row = LinearLayout(self)
        row.orientation = LinearLayout.HORIZONTAL
        row.gravity = Gravity.CENTER_VERTICAL
        row.setPadding(dp(12), dp(10), dp(12), dp(10))
        let bg = GradientDrawable()
        bg.cornerRadius = Float(dp(16))
        bg.setColor(Color.WHITE)
        bg.setStroke(dp(2), Color.parseColor(equipped ? "#66BB6A" : "#FFE082"))
        row.background = bg
        let rowLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
        )
        rowLp.topMargin = dp(6)
        row.layoutParams = rowLp

        let iconRes = shopIconRes(item.id)
        if iconRes != 0 {
            let iv = ImageView(self)
            iv.setImageResource(iconRes)
            iv.layoutParams = LinearLayout.LayoutParams(dp(46), dp(46))
            row.addView(iv)
        } else {
            let em = TextView(self)
            em.text = item.emoji; em.textSize = 26
            row.addView(em)
        }
        let col = LinearLayout(self)
        col.orientation = LinearLayout.VERTICAL
        col.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1)
        col.setPadding(dp(10), 0, dp(6), 0)
        let name = TextView(self)
        name.text = getString(item.nameRes)
        name.textSize = 15
        name.setTypeface(name.typeface, Typeface.BOLD)
        col.addView(name)
        let desc = TextView(self)
        if item.id == "hint3" {
            desc.text = getString(R.string.shop_hint_have, getString(item.descRes), db.itemCount("hint"))
        } else if item.id == "heart_up" {
            desc.text = getString(R.string.shop_heart_have, getString(item.descRes), db.maxHearts())
        } else {
            desc.text = getString(item.descRes)
        }
        desc.textSize = 11
        desc.setTextColor(Color.parseColor("#8D6E63"))
        col.addView(desc)
        row.addView(col)

        let btn = Button(self)
        btn.isAllCaps = false
        btn.textSize = 13
        btn.minWidth = 0
        btn.minimumWidth = 0
        btn.setPadding(dp(14), 0, dp(14), 0)
        if maxed {
            btn.text = getString(R.string.shop_maxed)
            btn.isEnabled = false
        } else if equipped {
            btn.text = getString(R.string.shop_in_use)
            btn.isEnabled = false
            btn.setBackgroundColorTint("#66BB6A")
            btn.setTextColor(Color.WHITE)
        } else if owned {
            btn.text = getString(R.string.shop_apply)
            btn.setBackgroundColorTint("#81D4FA")
            btn.setTextColor(Color.parseColor("#4E342E"))
            btn.setOnClickListener { [weak self] _ in self?.equip(item) }
        } else {
            btn.text = Wallet.format(self, item.price)
            let affordable = db.coins() >= item.price
            btn.setBackgroundColorTint(affordable ? "#FFD54F" : "#EDE7E0")
            btn.setTextColor(Color.parseColor("#4E342E"))
            btn.setOnClickListener { [weak self] _ in self?.buy(item) }
        }
        row.addView(btn)
        return row
    }

    private func buy(_ item: ShopItem) {
        if db.coins() < item.price {
            Toast.makeText(
                self, getString(R.string.shop_not_enough, Wallet.format(self, item.price - db.coins())),
                Toast.LENGTH_SHORT
            ).show()
            return
        }
        AlertDialog.Builder(self)
            .setTitle("\(item.emoji) " + getString(item.nameRes))
            .setMessage(getString(R.string.shop_buy_ask, getString(item.descRes), Wallet.format(self, item.price), Wallet.format(self, db.coins() - item.price)))
            .setPositiveButton(getString(R.string.shop_buy_yes)) { _, _ in self.doBuy(item) }
            .setNegativeButton(getString(R.string.shop_buy_later), nil)
            .show()
    }

    private func doBuy(_ item: ShopItem) {
        if !db.spendCoins(item.price, "BUY", "\(item.emoji) " + getString(item.nameRes)) { return }
        switch item.kind {
        case .CONSUMABLE:
            switch item.id {
            case "heart_refill":
                db.setHearts(db.maxHearts())
                toast(getString(R.string.shop_heart_full, db.maxHearts()))
            case "hint3":
                db.addItem("hint", item.amount)
                toast(getString(R.string.shop_got_hints, item.amount))
            default: break
            }
        case .UPGRADE:
            if item.id == "heart_up" {
                db.setMaxHearts((db.maxHearts() + 1).coerceAtMost(Shop.MAX_HEARTS_CAP))
                db.setHearts(db.maxHearts())
                toast(getString(R.string.shop_heart_up_done, db.maxHearts()))
            }
        case .STICKER:
            db.addItem(item.id, 1)
            db.setEquippedSticker(item.emoji)
            toast(getString(R.string.shop_sticker_on, item.emoji))
        case .THEME:
            db.addItem(item.id, 1)
            db.setThemeColor(item.color)
            toast(getString(R.string.shop_theme_on, getString(item.nameRes), item.emoji))
        }
        refresh()
    }

    private func equip(_ item: ShopItem) {
        switch item.kind {
        case .STICKER: db.setEquippedSticker(item.emoji); toast(getString(R.string.shop_sticker_on, item.emoji))
        case .THEME: db.setThemeColor(item.color); toast(getString(R.string.shop_applied, getString(item.nameRes)))
        default: break
        }
        refresh()
    }

    // ---------------- 현금 지급 ----------------

    private func askPayout() {
        if db.coins() <= 0 {
            toast(getString(R.string.pay_no_money))
            return
        }
        let presets = Shop.PAYOUT_PRESETS.filter { $0 <= db.coins() }
        let labels = presets.map { Wallet.format(self, $0) }
            + [getString(R.string.pay_all, Wallet.format(self, db.coins())), getString(R.string.pay_custom)]
        AlertDialog.Builder(self)
            .setTitle(getString(R.string.wallet_cash_out))
            .setItems(labels) { _, i in
                if i < presets.count { self.confirmPayout(presets[i]) }
                else if i == presets.count { self.confirmPayout(self.db.coins()) }
                else { self.customPayout() }
            }
            .setNegativeButton(getString(R.string.cancel), nil)
            .show()
    }

    private func customPayout() {
        let input = EditText(self)
        input.inputType = InputType.TYPE_CLASS_NUMBER
        input.hint = getString(R.string.pay_how_much, db.coins())
        input.setPadding(dp(20), dp(16), dp(20), dp(16))
        AlertDialog.Builder(self)
            .setTitle(getString(R.string.pay_enter_amount))
            .setView(input)
            .setPositiveButton(getString(R.string.confirm)) { _, _ in
                let v = input.text.toIntOrNull() ?? 0
                if v >= 1 && v <= self.db.coins() { self.confirmPayout(v) }
                else { self.toast(self.getString(R.string.pay_bad_amount)) }
            }
            .setNegativeButton(getString(R.string.cancel), nil)
            .show()
    }

    private func confirmPayout(_ amount: Int) {
        let doPay = {
            if self.db.spendCoins(amount, "PAYOUT", self.getString(R.string.pay_log)) {
                AlertDialog.Builder(self)
                    .setTitle(self.getString(R.string.pay_done_title, Wallet.format(self, amount)))
                    .setMessage(
                        self.getString(R.string.pay_done_msg, Wallet.format(self, amount), Wallet.format(self, self.db.coins()))
                    )
                    .setPositiveButton(self.getString(R.string.ok_nice), nil)
                    .show()
                self.refresh()
            }
        }
        if db.hasParentPin() { askPin(getString(R.string.pin_ask)) { ok in if ok { doPay() } } }
        else {
            AlertDialog.Builder(self)
                .setTitle(getString(R.string.pay_confirm_title))
                .setMessage(getString(R.string.pay_confirm_msg, Wallet.format(self, amount)))
                .setPositiveButton(getString(R.string.pay_gave)) { _, _ in doPay() }
                .setNegativeButton(getString(R.string.cancel), nil)
                .show()
        }
    }

    // ---------------- 부모 설정 ----------------

    private func parentSettings() {
        let has = db.hasParentPin()
        let options = has ? [getString(R.string.pin_change), getString(R.string.pin_remove)]
            : [getString(R.string.pin_create)]
        AlertDialog.Builder(self)
            .setTitle(getString(R.string.set_parent))
            .setItems(options) { _, i in
                if !has { self.newPin() }
                else if i == 0 { self.askPin(self.getString(R.string.pin_current)) { ok in if ok { self.newPin() } } }
                else {
                    self.askPin(self.getString(R.string.pin_current)) { ok in
                        if ok { self.db.setParentPin(""); self.toast(self.getString(R.string.pin_removed)) }
                    }
                }
            }
            .setNegativeButton(getString(R.string.close), nil)
            .show()
    }

    private func newPin() {
        let input = EditText(self)
        input.inputType = InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_VARIATION_PASSWORD
        input.hint = getString(R.string.pin_hint)
        input.setPadding(dp(20), dp(16), dp(20), dp(16))
        AlertDialog.Builder(self)
            .setTitle(getString(R.string.pin_new))
            .setView(input)
            .setPositiveButton(getString(R.string.save)) { _, _ in
                let p = input.text
                if p.length == 4 { self.db.setParentPin(p); self.toast(self.getString(R.string.pin_saved)) }
                else { self.toast(self.getString(R.string.pin_need4)) }
            }
            .setNegativeButton(getString(R.string.cancel), nil)
            .show()
    }

    private func askPin(_ title: String, _ cb: @escaping (Bool) -> Void) {
        let input = EditText(self)
        input.inputType = InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_VARIATION_PASSWORD
        input.hint = getString(R.string.pin_hint)
        input.setPadding(dp(20), dp(16), dp(20), dp(16))
        AlertDialog.Builder(self)
            .setTitle(title)
            .setView(input)
            .setPositiveButton(getString(R.string.confirm)) { _, _ in
                let ok = input.text == self.db.parentPin()
                if !ok { self.toast(self.getString(R.string.pin_wrong)) }
                cb(ok)
            }
            .setNegativeButton(getString(R.string.cancel)) { _, _ in cb(false) }
            .show()
    }

    // ---------------- 기록 ----------------

    private func buildLog() {
        b.logBox.removeAllViews()
        let logs = db.walletLog(30)
        if logs.isEmpty {
            let none = TextView(self)
            none.text = getString(R.string.wallet_no_log)
            none.textSize = 13
            none.setTextColor(Color.parseColor("#8D6E63"))
            none.setPadding(dp(4), dp(8), 0, 0)
            b.logBox.addView(none)
            return
        }
        let fmt = SimpleDateFormat("M/d HH:mm", JLocale.KOREA)
        for log in logs {
            let row = LinearLayout(self)
            row.orientation = LinearLayout.HORIZONTAL
            row.gravity = Gravity.CENTER_VERTICAL
            row.setPadding(dp(4), dp(7), dp(4), dp(7))
            let icon = TextView(self)
            switch log.kind {
            case "LESSON": icon.text = "📚"
            case "LETTER": icon.text = "✏️"
            case "REVIEW": icon.text = "💊"
            case "GOAL": icon.text = "🎯"
            case "PLACEMENT": icon.text = "🎓"
            case "BUY": icon.text = "🛒"
            case "PAYOUT": icon.text = "💵"
            case "LEGACY": icon.text = "🎁"
            default: icon.text = "•"
            }
            icon.textSize = 16
            // 안드로이드 setWidth — 최소·최대 폭을 같게
            icon.minWidth = dp(28)
            icon.maxWidth = dp(28)
            row.addView(icon)
            let col = LinearLayout(self)
            col.orientation = LinearLayout.VERTICAL
            col.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1)
            let note = TextView(self)
            note.text = log.note.ifEmpty { log.kind }
            note.textSize = 13
            note.maxLines = 2
            col.addView(note)
            let at = TextView(self)
            at.text = fmt.format(Date(millis: log.at))
            at.textSize = 10
            at.setTextColor(Color.parseColor("#A1887F"))
            col.addView(at)
            row.addView(col)
            let amt = TextView(self)
            amt.text = (log.isEarn ? "+" : "") + Wallet.format(self, log.amount)
            amt.textSize = 14
            amt.setTypeface(amt.typeface, Typeface.BOLD)
            amt.setTextColor(Color.parseColor(log.isEarn ? "#43A047" : "#E53935"))
            row.addView(amt)
            b.logBox.addView(row)
        }
    }

    private func toast(_ s: String) { Toast.makeText(self, s, Toast.LENGTH_SHORT).show() }

    /// 상점 일러스트 — 그림이 없는 아이템은 이모지로 보여준다
    private func shopIconRes(_ id: String) -> Int {
        let name: String
        switch id {
        case "heart_refill": name = "shop_heart"
        case "heart_up": name = "shop_heart_plus"
        case "hint3": name = "shop_hint"
        case "st_star": name = "shop_sticker_star"
        case "st_crown": name = "shop_sticker_crown"
        case "st_rainbow": name = "shop_sticker_rainbow"
        case "st_rocket": name = "shop_sticker_rocket"
        case "th_pink": name = "shop_theme_pink"
        case "th_mint": name = "shop_theme_mint"
        case "th_sky": name = "shop_theme_sky"
        case "th_lav": name = "shop_theme_lavender"
        case "st_dino": name = "shop_sticker_dino"
        case "st_cake": name = "shop_sticker_cake"
        case "st_medal": name = "shop_sticker_medal"
        case "st_unicorn": name = "shop_sticker_unicorn"
        default: return 0
        }
        return resources.getIdentifier(name, "drawable", packageName)
    }

    private func dp(_ v: Int) -> Int { Int(Float(v) * resources.displayMetrics.density) }
}

fileprivate extension Button {
    func setBackgroundColorTint(_ hex: String) {
        backgroundTintList = ColorStateList.valueOf(Color.parseColor(hex))
    }
}
