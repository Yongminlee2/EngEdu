import UIKit

final class StatsActivity: AppCompatActivity {

    private var b: ActivityStatsBinding!

    override func onCreate(_ savedInstanceState: SavedState?) {
        super.onCreate(savedInstanceState)
        b = ActivityStatsBinding.inflate(layoutInflater)
        setContentView(b.root)
        b.btnBack.setOnClickListener { [weak self] _ in self?.finish() }
    }

    override func onResume() {
        super.onResume()
        let db = Db.get(self)
        let xp = db.xp()
        let lv = Economy.levelFor(xp)
        b.txtLevelBig.text = getString(R.string.stats_level_big, lv)
        b.xpBar.progress = (Economy.levelProgress(xp) * 100).toInt()
        b.txtXpDetail.text = getString(R.string.stats_xp_detail, xp, Economy.xpForLevel(lv + 1) - xp)

        let days = db.studyDays()
        let (cur, best) = unpair(Economy.streak(days, Db.today()))
        b.txtStreakInfo.text = getString(R.string.stats_streak_info, cur, best)

        b.txtCounters.text =
            getString(R.string.stats_counters,
                      db.lessonsDoneCount(), db.metaInt("perfect_count"),
                      db.metaInt("review_cleared"), days.count)

        buildSkills(db)
        buildCalendar(days)
        buildBadges(db.earnedBadges())
    }

    /// 영역별 실력 상세: 레벨 · 진행바 · 정답수/시도수 · 다음 레벨까지. 영어 앱은 영어 영역만.
    private func buildSkills(_ db: Db) {
        let states = db.skillStates(Skills.ALL)
        let overall = Skills.overallLevel(states)
        let rank = Ranks.of(overall)
        let next = Ranks.next(overall)
        b.txtRankLine.text = "%s %s · Lv.%.1f".format(rank.emoji, getString(rank.titleRes), overall) +
            (next != nil ? getString(R.string.rank_next_short, getString(next!.titleRes), next!.minOverall) : getString(R.string.rank_top))

        b.skillDetailBox.removeAllViews()
        for st in states {
            let box = LinearLayout(self)
            box.orientation = LinearLayout.VERTICAL
            box.setPadding(dp(12), dp(10), dp(12), dp(10))
            box.background = getDrawable(R.drawable.bg_tile_ghost)
            let boxLp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            )
            boxLp.topMargin = dp(6)
            box.layoutParams = boxLp

            let title = TextView(self)
            title.text = "\(st.def.emoji) \(getString(st.def.titleRes))   Lv.\(st.level)"
            title.textSize = 16
            title.setTypeface(title.typeface, Typeface.BOLD)
            box.addView(title)

            let bar = ProgressBar(self)
            bar.max = 100
            bar.progress = (st.progress * 100).toInt()
            bar.progressTintList = ColorStateList.valueOf(Color.parseColor(st.def.color))
            bar.progressBackgroundTintList = ColorStateList.valueOf(Color.parseColor("#FFF0CC"))
            let barLp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(10))
            barLp.topMargin = dp(6)
            bar.layoutParams = barLp
            box.addView(bar)

            let line = TextView(self)
            if st.attempts == 0 {
                line.text = getString(R.string.stats_none_yet)
            } else {
                line.text = getString(R.string.stats_skill_line, st.correct, st.attempts, st.accuracy) +
                    (st.level < Skills.MAX_LEVEL
                        ? getString(R.string.stats_next_level, st.nextLevelNeed)
                        : getString(R.string.stats_max_level))
            }
            line.textSize = 12
            line.setTextColor(Color.parseColor("#8D6E63"))
            line.setPadding(0, dp(5), 0, 0)
            box.addView(line)
            b.skillDetailBox.addView(box)
        }
    }

    private func buildCalendar(_ days: Set<Int>) {
        b.calGrid.removeAllViews()
        let today = LocalDate.now()
        let first = today.withDayOfMonth(1)
        let startCol = first.dayOfWeek.value % 7 // 일요일 시작

        for h in resources.getStringArray(R.array.weekday_short) {
            b.calGrid.addView(cell(h, bold: true))
        }
        for _ in 0..<startCol { b.calGrid.addView(cell("")) }
        for d in 1...today.lengthOfMonth() {
            let date = first.withDayOfMonth(d)
            let studied = days.contains(date.toEpochDay())
            let isToday = date == today
            let t = cell(studied ? "🐥" : String(d))
            if isToday { t.setBackgroundColor(Color.parseColor("#FFE082")) }
            if !studied && date.isAfter(today) { t.setTextColor(Color.parseColor("#BDBDBD")) }
            b.calGrid.addView(t)
        }
    }

    private func cell(_ text: String, bold: Bool = false) -> TextView {
        let t = TextView(self)
        t.text = text
        t.textSize = 15
        t.gravity = Gravity.CENTER
        if bold { t.setTypeface(t.typeface, Typeface.BOLD) }
        let lp = GridLayout.LayoutParams()
        lp.width = 0
        lp.columnSpec = GridLayout.spec(GridLayout.UNDEFINED, Float(1))
        lp.setMargins(0, dp(4), 0, dp(4))
        t.layoutParams = lp
        return t
    }

    private func buildBadges(_ earned: Set<String>) {
        b.badgesGrid.removeAllViews()
        for bd in Badges.ALL {
            let has = earned.contains(bd.id)
            let box = LinearLayout(self)
            box.orientation = LinearLayout.VERTICAL
            box.gravity = Gravity.CENTER
            box.setPadding(dp(6), dp(10), dp(6), dp(10))
            box.alpha = has ? 1 : 0.35
            let lp = GridLayout.LayoutParams()
            lp.width = 0
            lp.columnSpec = GridLayout.spec(GridLayout.UNDEFINED, Float(1))
            box.layoutParams = lp

            let emoji = TextView(self)
            emoji.text = bd.emoji; emoji.textSize = 30; emoji.gravity = Gravity.CENTER
            box.addView(emoji)

            let title = TextView(self)
            title.text = getString(bd.titleRes); title.gravity = Gravity.CENTER
            title.setTypeface(title.typeface, Typeface.BOLD)
            // 칸이 화면 1/3 이라 긴 이름은 두 줄까지, 낱말 중간에서 끊지 않고 글자를 줄인다
            title.maxLines = 2
            title.ellipsize = TextUtils.TruncateAt.END
            title.breakStrategy = Layout.BREAK_STRATEGY_BALANCED
            title.hyphenationFrequency = Layout.HYPHENATION_FREQUENCY_NONE
            title.setAutoSizeTextTypeUniformWithConfiguration(9, 12, 1, TypedValue.COMPLEX_UNIT_SP)
            box.addView(title)

            let desc = TextView(self)
            desc.text = getString(bd.descRes); desc.gravity = Gravity.CENTER
            desc.setTextColor(Color.parseColor("#8D6E63"))
            // 긴 설명은 세 줄까지, 안 들어가면 글자를 더 줄인다
            desc.maxLines = 3
            desc.ellipsize = TextUtils.TruncateAt.END
            desc.breakStrategy = Layout.BREAK_STRATEGY_BALANCED
            desc.hyphenationFrequency = Layout.HYPHENATION_FREQUENCY_NONE
            desc.setAutoSizeTextTypeUniformWithConfiguration(7, 10, 1, TypedValue.COMPLEX_UNIT_SP)
            desc.setLineSpacing(0, 1.05)
            box.addView(desc)
            b.badgesGrid.addView(box)
        }
    }

    private func dp(_ v: Int) -> Int { Int(Float(v) * resources.displayMetrics.density) }
}
