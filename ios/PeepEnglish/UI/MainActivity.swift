import UIKit

final class MainActivity: AppCompatActivity {

    private var b: ActivityMainBinding!
    private var sfx: Sfx? = nil
    private var subject: Subject = Subject.ENGLISH
    // 처음 쓸 때 리소스에서 읽는다
    private lazy var greetings: [String] = [
        getString(R.string.home_greeting), getString(R.string.home_greeting_2),
        getString(R.string.home_greeting_3), getString(R.string.home_greeting_4),
        getString(R.string.home_greeting_5), getString(R.string.home_greeting_6),
    ]

    override func onCreate(_ savedInstanceState: SavedState?) {
        super.onCreate(savedInstanceState)
        b = ActivityMainBinding.inflate(layoutInflater)
        setContentView(b.root)
        // 삐약영어는 영어 전용 앱 — 과목 대문 없이 항상 영어
        subject = Subject.ENGLISH

        b.txtGreeting.text = greetings.random()
        b.btnSwitchSubject.visibility = View.GONE
        b.bannerPlacement.setOnClickListener { [weak self] _ in
            guard let self else { return }
            self.startActivity(
                Intent(self, PlacementActivity.self).putExtra("subject", self.subject.id)
            )
        }
        b.btnReview.setOnClickListener { [weak self] _ in
            guard let self else { return }
            let db = Db.get(self)
            if db.wrongCount() == 0 {
                Toast.makeText(self, self.getString(R.string.home_no_review), Toast.LENGTH_SHORT).show()
            } else {
                self.startActivity(Intent(self, LessonActivity.self).putExtra("mode", "review"))
            }
        }
        b.btnStats.setOnClickListener { [weak self] _ in
            guard let self else { return }
            self.startActivity(Intent(self, StatsActivity.self))
        }
        b.btnSettings.setOnClickListener { [weak self] _ in
            guard let self else { return }
            self.startActivity(Intent(self, SettingsActivity.self))
        }
        b.txtGoalEdit.setOnClickListener { [weak self] _ in self?.pickDailyGoal() }

        // 살아있는 마스코트 — 천천히 숨쉬고, 톡 치면 삐약! 하고 점프
        sfx = Sfx(self)
        PoseAnim.applyTo(b.imgMascot, R.drawable.ck_idle)   // 가끔 눈을 깜빡인다
        let breath = ObjectAnimator.ofPropertyValuesHolder(
            b.imgMascot,
            PropertyValuesHolder.ofFloat(View.SCALE_X, 1, 1.045),
            PropertyValuesHolder.ofFloat(View.SCALE_Y, 1, 1.045)
        )
        breath.duration = 1300
        breath.repeatCount = ValueAnimator.INFINITE
        breath.repeatMode = ValueAnimator.REVERSE
        breath.interpolator = AccelerateDecelerateInterpolator()
        breath.start()
        b.imgMascot.setOnClickListener { [weak self] _ in
            guard let self else { return }
            self.sfx?.piyak()
            let img = self.b.imgMascot
            img.animate().translationY(-self.dp(10)).setDuration(140)
                .withEndAction {
                    img.animate().translationY(0).setDuration(260)
                        .setInterpolator(BounceInterpolator()).start()
                }.start()
        }
        b.cardAlphabet.setOnClickListener { [weak self] _ in
            guard let self else { return }
            self.startActivity(Intent(self, AlphabetActivity.self))
        }
        b.cardWallet.setOnClickListener { [weak self] _ in
            guard let self else { return }
            self.startActivity(Intent(self, WalletActivity.self))
        }
        b.cardPlayground.setOnClickListener { [weak self] _ in
            guard let self else { return }
            self.startActivity(
                Intent(self, PlaygroundActivity.self).putExtra("subject", self.subject.id)
            )
        }
    }

    private func pickDailyGoal() {
        let db = Db.get(self)
        let labels = DailyGoal.OPTIONS.map { xp -> String in
            let note: String
            switch xp {
            case 20: note = getString(R.string.goal_light)
            case 50: note = getString(R.string.goal_normal)
            case 100: note = getString(R.string.goal_hard)
            default: note = getString(R.string.goal_beast)
            }
            return "\(xp) XP — \(note)"
        }
        AlertDialog.Builder(self)
            .setTitle(getString(R.string.goal_set_title))
            .setItems(labels) { _, i in
                db.setDailyGoal(DailyGoal.OPTIONS[i])
                self.refresh()
            }
            .setNegativeButton(getString(R.string.cancel), nil)
            .show()
    }

    override func onResume() {
        super.onResume()
        // 시간대에 따라 풍경이 바뀐다 — 아침 하늘, 낮 풀밭, 저녁 교실, 밤엔 별
        let hour = JCalendar.getInstance().get(JCalendar.HOUR_OF_DAY)
        let banner: Int
        switch hour {
        case 6...10: banner = R.drawable.banner_sky
        case 11...16: banner = R.drawable.banner_grass
        case 17...20: banner = R.drawable.banner_class
        default: banner = R.drawable.banner_night
        }
        b.imgBanner.setImageResource(banner)
        b.imgBanner.clipToOutline = true
        let radius = dp(18)
        b.imgBanner.outlineProvider = ViewOutlineProvider { v, o in
            o.setRoundRect(0, 0, v.width, v.height, radius)
        }
        refresh()
    }

    private func refresh() {
        let db = Db.get(self)
        let xp = db.xp()
        let lv = Economy.levelFor(xp)
        b.txtHearts.text = db.heartsEnabled() ? "\(db.hearts())" : ""
        b.txtHearts.setCompoundDrawablesRelativeWithIntrinsicBounds(
            db.heartsEnabled() ? R.drawable.ic_heart : 0, 0, 0, 0
        )
        let (streak, _) = unpair(Economy.streak(db.studyDays(), Db.today()))
        b.txtStreak.text = "\(streak)"
        b.txtLevel.text = "Lv.\(lv)"
        b.xpBar.progress = (Economy.levelProgress(xp) * 100).toInt()
        b.txtReview.text = getString(R.string.home_wrong_count, db.wrongCount())
        // 배치고사 배너: 과목별로 아직 안 본 경우에만
        let placedKey = subject == Subject.MATH ? "math_placement_done" : "placement_done"
        b.bannerPlacement.visibility = db.meta(placedKey) == "1" ? View.GONE : View.VISIBLE
        b.txtPlacement.text = subject == Subject.MATH
            ? getString(R.string.home_placement_math)
            : getString(R.string.home_placement_en)

        // 상점에서 산 테마 배경 적용
        let theme = Color.parseColor(db.themeColor())
        b.root.setBackgroundColor(theme)
        window.statusBarColor = theme

        b.txtCoins.text = Wallet.format(self, db.coins())
        // 알파벳·놀이터는 "유치원 영어" 단계 안으로 이사 — 홈을 가볍게
        b.cardAlphabet.visibility = View.GONE
        b.cardPlayground.visibility = View.GONE
        // '내 실력' 카드가 제목만 있고 속이 비어 보여서 영역 줄을 다시 보여준다
        b.skillsBox.visibility = View.VISIBLE
        b.txtWeakest.visibility = View.VISIBLE
        buildGrowth(db)
        buildTrackCards(db)
    }

    /// 칭호 · 오늘의 목표 · 영역별 실력 바
    private func buildGrowth(_ db: Db) {
        let states = db.skillStates(Skills.forSubject(subject))
        let overall = Skills.overallLevel(states)
        let rank = Ranks.of(overall)
        let sticker = db.equippedSticker()
        b.txtRank.text = "\(rank.emoji) \(getString(rank.titleRes))" + (!sticker.isEmpty ? " \(sticker)" : "")
        b.rankBar.progress = (Ranks.progress(overall) * 100).toInt()
        let next = Ranks.next(overall)
        b.txtOverall.text = getString(R.string.home_overall_lv, "%.1f".format(overall)) +
            (next != nil ? getString(R.string.rank_next, next!.emoji, getString(next!.titleRes)) : getString(R.string.rank_top))

        let goal = db.dailyGoal()
        let todayXp = db.xpToday()
        let done = DailyGoal.isDone(todayXp, goal)
        b.txtGoal.text = getString(R.string.home_daily_goal, todayXp, goal) + (done ? getString(R.string.home_goal_done) : "")
        b.goalBar.progress = (DailyGoal.progress(todayXp, goal) * 100).toInt()
        b.goalBar.progressTintList = ColorStateList.valueOf(
            Color.parseColor(done ? "#66BB6A" : "#FF8A80")
        )

        let weak = Skills.weakest(states)
        if let weak, weak.attempts >= 0 {
            b.txtWeakest.text = getString(R.string.weak_area, weak.def.emoji, getString(weak.def.titleRes))
        } else {
            b.txtWeakest.text = ""
        }

        b.skillsBox.removeAllViews()
        for st in states { b.skillsBox.addView(skillRow(st)) }
    }

    /// 실력 한 줄: 영역  Lv.3  [====----]  정답률 82%
    private func skillRow(_ st: SkillState) -> LinearLayout {
        let row = LinearLayout(self)
        row.orientation = LinearLayout.HORIZONTAL
        row.gravity = Gravity.CENTER_VERTICAL
        row.setPadding(0, dp(5).toInt(), 0, dp(5).toInt())

        // 영역 이름은 언어마다 길이가 크게 달라 가변 폭 + 한 줄 + 자동 축소로 둔다
        let name = TextView(self)
        name.text = "\(st.def.emoji) \(getString(st.def.titleRes))"
        name.maxLines = 1
        name.ellipsize = TextUtils.TruncateAt.END
        name.setAutoSizeTextTypeUniformWithConfiguration(10, 14, 1, TypedValue.COMPLEX_UNIT_SP)
        name.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 2.0)
        row.addView(name)

        let lv = TextView(self)
        lv.text = "Lv.\(st.level)"
        lv.textSize = 14
        lv.setTypeface(lv.typeface, Typeface.BOLD)
        lv.minWidth = dp(42).toInt()
        row.addView(lv)

        let bar = ProgressBar(self)
        bar.max = 100
        bar.progress = (st.progress * 100).toInt()
        bar.progressTintList = ColorStateList.valueOf(Color.parseColor(st.def.color))
        bar.progressBackgroundTintList = ColorStateList.valueOf(Color.parseColor("#FFF0CC"))
        bar.layoutParams = LinearLayout.LayoutParams(0, dp(10).toInt(), 1)
        row.addView(bar)

        // "시작 전" 문구가 접히지 않게 최소 폭만 주고 늘어나게
        let acc = TextView(self)
        acc.text = st.attempts == 0 ? getString(R.string.not_started) : "  \(st.accuracy)%"
        acc.textSize = 12
        acc.setTextColor(Color.parseColor("#8D6E63"))
        acc.minWidth = dp(52).toInt()
        acc.maxLines = 1
        acc.setPadding(dp(6).toInt(), 0, 0, 0)
        acc.gravity = Gravity.END
        row.addView(acc)
        return row
    }

    /// 홈의 단계 카드 5장 — 유치원/초등/중등·고등/성인·실전/영역별
    private func buildTrackCards(_ db: Db) {
        b.tracksBox.removeAllViews()
        struct Stage { let emoji: String; let title: Int; let sub: Int; let color: String; let id: String }
        let stages = [
            Stage(emoji: "🐣", title: R.string.stage_kinder, sub: R.string.stage_kinder_sub, color: "#FFF3D6", id: "kinder"),
            Stage(emoji: "📗", title: R.string.stage_elem, sub: R.string.stage_elem_sub, color: "#E8F6EA", id: "elementary"),
            Stage(emoji: "📘", title: R.string.stage_middle, sub: R.string.stage_middle_sub, color: "#E3F4FD", id: "middle"),
            Stage(emoji: "✈️", title: R.string.stage_adult, sub: R.string.stage_adult_sub, color: "#F3EDFB", id: "adult"),
            Stage(emoji: "🎯", title: R.string.stage_skills, sub: R.string.stage_skills_sub, color: "#FDE2E2", id: "skills"),
        ]
        // 단계 일러스트 — 없으면 이모지 동그라미로
        func stageArt(_ id: String) -> Int {
            resources.getIdentifier("stage_\(id)", "drawable", packageName)
        }
        for s in stages {
            let card = LinearLayout(self)
            card.orientation = LinearLayout.HORIZONTAL
            card.gravity = Gravity.CENTER_VERTICAL
            card.setPadding(dp(18).toInt(), dp(18).toInt(), dp(16).toInt(), dp(18).toInt())
            let bg = GradientDrawable()
            bg.cornerRadius = dp(26)
            bg.setColor(Color.WHITE)
            let c = Color.parseColor(s.color)
            bg.setStroke(dp(3).toInt(), Color.rgb(
                (Float(Color.red(c)) * 0.82).toInt(), (Float(Color.green(c)) * 0.82).toInt(), (Float(Color.blue(c)) * 0.82).toInt()
            ))
            card.background = bg
            let cardLp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            )
            cardLp.topMargin = dp(12).toInt()
            card.layoutParams = cardLp
            let stageId = s.id
            card.setOnClickListener { [weak self] _ in
                guard let self else { return }
                self.startActivity(Intent(self, StageActivity.self).putExtra("stage", stageId))
            }
            let art = stageArt(s.id)
            if art != 0 {
                let iv = ImageView(self)
                iv.setImageResource(art)
                let oval = GradientDrawable()
                oval.shape = GradientDrawable.OVAL
                oval.setColor(Color.parseColor(s.color))
                iv.background = oval
                let pad = dp(3).toInt()
                iv.setPadding(pad, pad, pad, pad)
                iv.layoutParams = LinearLayout.LayoutParams(dp(80).toInt(), dp(80).toInt())
                card.addView(iv)
            } else {
                let em = TextView(self)
                em.text = s.emoji
                em.textSize = 28
                em.gravity = Gravity.CENTER
                let oval = GradientDrawable()
                oval.shape = GradientDrawable.OVAL
                oval.setColor(Color.parseColor(s.color))
                em.background = oval
                em.layoutParams = LinearLayout.LayoutParams(dp(58).toInt(), dp(58).toInt())
                card.addView(em)
            }
            let col = LinearLayout(self)
            col.orientation = LinearLayout.VERTICAL
            col.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1)
            col.setPadding(dp(14).toInt(), 0, 0, 0)
            let title = TextView(self)
            title.text = getString(s.title)
            title.textSize = 18
            title.setTypeface(title.typeface, Typeface.BOLD)
            title.setTextColor(Color.parseColor("#4E342E"))
            col.addView(title)
            let sub = TextView(self)
            sub.text = getString(s.sub)
            sub.textSize = 13
            sub.setTextColor(Color.parseColor("#8D6E63"))
            col.addView(sub)
            card.addView(col)
            let arrow = TextView(self)
            arrow.text = "▶"; arrow.textSize = 16; arrow.setTextColor(Color.parseColor("#C9A25E"))
            arrow.setPadding(dp(8).toInt(), 0, 0, 0)   // 긴 번역 부제와 맞붙지 않게
            card.addView(arrow)
            b.tracksBox.addView(card)
        }
    }

    override func onDestroy() { super.onDestroy(); sfx?.release() }

    private func dp(_ v: Float) -> Float { v * resources.displayMetrics.density }
}
