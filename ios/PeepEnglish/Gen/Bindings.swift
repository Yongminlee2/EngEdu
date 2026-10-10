// 자동 생성: tools/gen-r.py — 직접 고치지 말 것 (안드로이드 res/layout 에서 만든다)

final class ActivityAlphabetBinding {
    let root: LinearLayout
    let btnBack: Button
    let txtDone: TextView
    let btnUpper: Button
    let btnLower: Button
    let lettersGrid: GridLayout

    private init(_ v: View) {
        root = v as! LinearLayout
        btnBack = v.findViewById(R.id.btnBack)!
        txtDone = v.findViewById(R.id.txtDone)!
        btnUpper = v.findViewById(R.id.btnUpper)!
        btnLower = v.findViewById(R.id.btnLower)!
        lettersGrid = v.findViewById(R.id.lettersGrid)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ActivityAlphabetBinding {
        ActivityAlphabetBinding(inflater.inflate(R.layout.activity_alphabet, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ActivityAlphabetBinding {
        ActivityAlphabetBinding(inflater.inflate(R.layout.activity_alphabet, parent, attachToParent))
    }
    static func bind(_ v: View) -> ActivityAlphabetBinding { ActivityAlphabetBinding(v) }
}

final class ActivityGameBinding {
    let root: FrameLayout
    let btnClose: Button
    let txtScore: TextView
    let txtLives: TextView
    let timeBar: ProgressBar
    let txtQuestion: TextView
    let gameBox: FrameLayout
    let btnAction: Button
    let resultPanel: LinearLayout
    let txtResultTitle: TextView
    let txtResultBody: TextView
    let btnAgain: Button
    let btnQuit: Button

    private init(_ v: View) {
        root = v as! FrameLayout
        btnClose = v.findViewById(R.id.btnClose)!
        txtScore = v.findViewById(R.id.txtScore)!
        txtLives = v.findViewById(R.id.txtLives)!
        timeBar = v.findViewById(R.id.timeBar)!
        txtQuestion = v.findViewById(R.id.txtQuestion)!
        gameBox = v.findViewById(R.id.gameBox)!
        btnAction = v.findViewById(R.id.btnAction)!
        resultPanel = v.findViewById(R.id.resultPanel)!
        txtResultTitle = v.findViewById(R.id.txtResultTitle)!
        txtResultBody = v.findViewById(R.id.txtResultBody)!
        btnAgain = v.findViewById(R.id.btnAgain)!
        btnQuit = v.findViewById(R.id.btnQuit)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ActivityGameBinding {
        ActivityGameBinding(inflater.inflate(R.layout.activity_game, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ActivityGameBinding {
        ActivityGameBinding(inflater.inflate(R.layout.activity_game, parent, attachToParent))
    }
    static func bind(_ v: View) -> ActivityGameBinding { ActivityGameBinding(v) }
}

final class ActivityLessonBinding {
    let root: FrameLayout
    let btnClose: ImageView
    let progressBar: ProgressBar
    let txtHearts: TextView
    let btnHint: Button
    let questionScroll: ScrollView
    let questionBox: FrameLayout
    let btnCheck: Button
    let chickView: ChickView
    let feedbackPanel: LinearLayout
    let imgFeedback: ImageView
    let txtFeedback: TextView
    let txtExplain: TextView
    let btnContinue: Button
    let resultPanel: LinearLayout
    let imgResult: ImageView
    let txtResultTitle: TextView
    let txtResultStats: TextView
    let btnDone: Button
    let celebrate: CelebrateOverlayView

    private init(_ v: View) {
        root = v as! FrameLayout
        btnClose = v.findViewById(R.id.btnClose)!
        progressBar = v.findViewById(R.id.progressBar)!
        txtHearts = v.findViewById(R.id.txtHearts)!
        btnHint = v.findViewById(R.id.btnHint)!
        questionScroll = v.findViewById(R.id.questionScroll)!
        questionBox = v.findViewById(R.id.questionBox)!
        btnCheck = v.findViewById(R.id.btnCheck)!
        chickView = v.findViewById(R.id.chickView)!
        feedbackPanel = v.findViewById(R.id.feedbackPanel)!
        imgFeedback = v.findViewById(R.id.imgFeedback)!
        txtFeedback = v.findViewById(R.id.txtFeedback)!
        txtExplain = v.findViewById(R.id.txtExplain)!
        btnContinue = v.findViewById(R.id.btnContinue)!
        resultPanel = v.findViewById(R.id.resultPanel)!
        imgResult = v.findViewById(R.id.imgResult)!
        txtResultTitle = v.findViewById(R.id.txtResultTitle)!
        txtResultStats = v.findViewById(R.id.txtResultStats)!
        btnDone = v.findViewById(R.id.btnDone)!
        celebrate = v.findViewById(R.id.celebrate)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ActivityLessonBinding {
        ActivityLessonBinding(inflater.inflate(R.layout.activity_lesson, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ActivityLessonBinding {
        ActivityLessonBinding(inflater.inflate(R.layout.activity_lesson, parent, attachToParent))
    }
    static func bind(_ v: View) -> ActivityLessonBinding { ActivityLessonBinding(v) }
}

final class ActivityMainBinding {
    let root: ScrollView
    let btnSwitchSubject: Button
    let imgBanner: ImageView
    let txtHearts: TextView
    let txtStreak: TextView
    let txtLevel: TextView
    let xpBar: ProgressBar
    let imgMascot: ImageView
    let txtRank: TextView
    let txtOverall: TextView
    let rankBar: ProgressBar
    let txtGreeting: TextView
    let goalBox: LinearLayout
    let txtGoal: TextView
    let txtGoalEdit: TextView
    let goalBar: ProgressBar
    let cardPlayground: LinearLayout
    let txtPlayground: TextView
    let cardAlphabet: LinearLayout
    let txtAlphabetSub: TextView
    let txtAlphabetCount: TextView
    let tracksBox: LinearLayout
    let txtWeakest: TextView
    let skillsBox: LinearLayout
    let cardWallet: LinearLayout
    let txtCoins: TextView
    let bannerPlacement: LinearLayout
    let txtPlacement: TextView
    let btnReview: LinearLayout
    let txtReview: TextView
    let btnStats: LinearLayout
    let txtStats: TextView
    let btnSettings: LinearLayout
    let txtSettings: TextView

    private init(_ v: View) {
        root = v as! ScrollView
        btnSwitchSubject = v.findViewById(R.id.btnSwitchSubject)!
        imgBanner = v.findViewById(R.id.imgBanner)!
        txtHearts = v.findViewById(R.id.txtHearts)!
        txtStreak = v.findViewById(R.id.txtStreak)!
        txtLevel = v.findViewById(R.id.txtLevel)!
        xpBar = v.findViewById(R.id.xpBar)!
        imgMascot = v.findViewById(R.id.imgMascot)!
        txtRank = v.findViewById(R.id.txtRank)!
        txtOverall = v.findViewById(R.id.txtOverall)!
        rankBar = v.findViewById(R.id.rankBar)!
        txtGreeting = v.findViewById(R.id.txtGreeting)!
        goalBox = v.findViewById(R.id.goalBox)!
        txtGoal = v.findViewById(R.id.txtGoal)!
        txtGoalEdit = v.findViewById(R.id.txtGoalEdit)!
        goalBar = v.findViewById(R.id.goalBar)!
        cardPlayground = v.findViewById(R.id.cardPlayground)!
        txtPlayground = v.findViewById(R.id.txtPlayground)!
        cardAlphabet = v.findViewById(R.id.cardAlphabet)!
        txtAlphabetSub = v.findViewById(R.id.txtAlphabetSub)!
        txtAlphabetCount = v.findViewById(R.id.txtAlphabetCount)!
        tracksBox = v.findViewById(R.id.tracksBox)!
        txtWeakest = v.findViewById(R.id.txtWeakest)!
        skillsBox = v.findViewById(R.id.skillsBox)!
        cardWallet = v.findViewById(R.id.cardWallet)!
        txtCoins = v.findViewById(R.id.txtCoins)!
        bannerPlacement = v.findViewById(R.id.bannerPlacement)!
        txtPlacement = v.findViewById(R.id.txtPlacement)!
        btnReview = v.findViewById(R.id.btnReview)!
        txtReview = v.findViewById(R.id.txtReview)!
        btnStats = v.findViewById(R.id.btnStats)!
        txtStats = v.findViewById(R.id.txtStats)!
        btnSettings = v.findViewById(R.id.btnSettings)!
        txtSettings = v.findViewById(R.id.txtSettings)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ActivityMainBinding {
        ActivityMainBinding(inflater.inflate(R.layout.activity_main, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ActivityMainBinding {
        ActivityMainBinding(inflater.inflate(R.layout.activity_main, parent, attachToParent))
    }
    static func bind(_ v: View) -> ActivityMainBinding { ActivityMainBinding(v) }
}

final class ActivityPlacementBinding {
    let root: FrameLayout
    let btnClose: Button
    let txtCount: TextView
    let progressBar: ProgressBar
    let btnPlay: Button
    let txtPrompt: TextView
    let choicesBox: LinearLayout
    let resultPanel: LinearLayout
    let txtResultTitle: TextView
    let txtResultDesc: TextView
    let btnDone: Button

    private init(_ v: View) {
        root = v as! FrameLayout
        btnClose = v.findViewById(R.id.btnClose)!
        txtCount = v.findViewById(R.id.txtCount)!
        progressBar = v.findViewById(R.id.progressBar)!
        btnPlay = v.findViewById(R.id.btnPlay)!
        txtPrompt = v.findViewById(R.id.txtPrompt)!
        choicesBox = v.findViewById(R.id.choicesBox)!
        resultPanel = v.findViewById(R.id.resultPanel)!
        txtResultTitle = v.findViewById(R.id.txtResultTitle)!
        txtResultDesc = v.findViewById(R.id.txtResultDesc)!
        btnDone = v.findViewById(R.id.btnDone)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ActivityPlacementBinding {
        ActivityPlacementBinding(inflater.inflate(R.layout.activity_placement, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ActivityPlacementBinding {
        ActivityPlacementBinding(inflater.inflate(R.layout.activity_placement, parent, attachToParent))
    }
    static func bind(_ v: View) -> ActivityPlacementBinding { ActivityPlacementBinding(v) }
}

final class ActivityPlaygroundBinding {
    let root: LinearLayout
    let btnBack: Button
    let txtTitle: TextView
    let btnLv1: Button
    let btnLv2: Button
    let btnLv3: Button
    let gamesBox: LinearLayout

    private init(_ v: View) {
        root = v as! LinearLayout
        btnBack = v.findViewById(R.id.btnBack)!
        txtTitle = v.findViewById(R.id.txtTitle)!
        btnLv1 = v.findViewById(R.id.btnLv1)!
        btnLv2 = v.findViewById(R.id.btnLv2)!
        btnLv3 = v.findViewById(R.id.btnLv3)!
        gamesBox = v.findViewById(R.id.gamesBox)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ActivityPlaygroundBinding {
        ActivityPlaygroundBinding(inflater.inflate(R.layout.activity_playground, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ActivityPlaygroundBinding {
        ActivityPlaygroundBinding(inflater.inflate(R.layout.activity_playground, parent, attachToParent))
    }
    static func bind(_ v: View) -> ActivityPlaygroundBinding { ActivityPlaygroundBinding(v) }
}

final class ActivitySettingsBinding {
    let root: ScrollView
    let btnBack: Button
    let rowLanguage: LinearLayout
    let txtLanguage: TextView
    let seekRate: SeekBar
    let txtRate: TextView
    let btnTtsTest: Button
    let seekSfx: SeekBar
    let txtSfx: TextView
    let btnSfxTest: Button
    let switchFree: CompoundButton
    let switchHearts: CompoundButton
    let btnPlacement: Button
    let btnCrash: Button
    let btnReset: Button

    private init(_ v: View) {
        root = v as! ScrollView
        btnBack = v.findViewById(R.id.btnBack)!
        rowLanguage = v.findViewById(R.id.rowLanguage)!
        txtLanguage = v.findViewById(R.id.txtLanguage)!
        seekRate = v.findViewById(R.id.seekRate)!
        txtRate = v.findViewById(R.id.txtRate)!
        btnTtsTest = v.findViewById(R.id.btnTtsTest)!
        seekSfx = v.findViewById(R.id.seekSfx)!
        txtSfx = v.findViewById(R.id.txtSfx)!
        btnSfxTest = v.findViewById(R.id.btnSfxTest)!
        switchFree = v.findViewById(R.id.switchFree)!
        switchHearts = v.findViewById(R.id.switchHearts)!
        btnPlacement = v.findViewById(R.id.btnPlacement)!
        btnCrash = v.findViewById(R.id.btnCrash)!
        btnReset = v.findViewById(R.id.btnReset)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ActivitySettingsBinding {
        ActivitySettingsBinding(inflater.inflate(R.layout.activity_settings, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ActivitySettingsBinding {
        ActivitySettingsBinding(inflater.inflate(R.layout.activity_settings, parent, attachToParent))
    }
    static func bind(_ v: View) -> ActivitySettingsBinding { ActivitySettingsBinding(v) }
}

final class ActivityStatsBinding {
    let root: ScrollView
    let btnBack: Button
    let txtLevelBig: TextView
    let xpBar: ProgressBar
    let txtXpDetail: TextView
    let txtCounters: TextView
    let txtRankLine: TextView
    let skillDetailBox: LinearLayout
    let txtStreakInfo: TextView
    let calGrid: GridLayout
    let badgesGrid: GridLayout

    private init(_ v: View) {
        root = v as! ScrollView
        btnBack = v.findViewById(R.id.btnBack)!
        txtLevelBig = v.findViewById(R.id.txtLevelBig)!
        xpBar = v.findViewById(R.id.xpBar)!
        txtXpDetail = v.findViewById(R.id.txtXpDetail)!
        txtCounters = v.findViewById(R.id.txtCounters)!
        txtRankLine = v.findViewById(R.id.txtRankLine)!
        skillDetailBox = v.findViewById(R.id.skillDetailBox)!
        txtStreakInfo = v.findViewById(R.id.txtStreakInfo)!
        calGrid = v.findViewById(R.id.calGrid)!
        badgesGrid = v.findViewById(R.id.badgesGrid)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ActivityStatsBinding {
        ActivityStatsBinding(inflater.inflate(R.layout.activity_stats, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ActivityStatsBinding {
        ActivityStatsBinding(inflater.inflate(R.layout.activity_stats, parent, attachToParent))
    }
    static func bind(_ v: View) -> ActivityStatsBinding { ActivityStatsBinding(v) }
}

final class ActivityTraceBinding {
    let root: FrameLayout
    let btnClose: Button
    let txtTitle: TextView
    let txtStrokeInfo: TextView
    let imgWordArt: ImageView
    let txtEmoji: TextView
    let txtWord: TextView
    let txtWordKo: TextView
    let btnSay: Button
    let traceView: TraceView
    let txtHint: TextView
    let btnDemo: Button
    let btnAgain: Button
    let btnNext: Button
    let donePanel: LinearLayout
    let imgDoneBig: ImageView
    let txtDoneBig: TextView
    let txtDoneMsg: TextView

    private init(_ v: View) {
        root = v as! FrameLayout
        btnClose = v.findViewById(R.id.btnClose)!
        txtTitle = v.findViewById(R.id.txtTitle)!
        txtStrokeInfo = v.findViewById(R.id.txtStrokeInfo)!
        imgWordArt = v.findViewById(R.id.imgWordArt)!
        txtEmoji = v.findViewById(R.id.txtEmoji)!
        txtWord = v.findViewById(R.id.txtWord)!
        txtWordKo = v.findViewById(R.id.txtWordKo)!
        btnSay = v.findViewById(R.id.btnSay)!
        traceView = v.findViewById(R.id.traceView)!
        txtHint = v.findViewById(R.id.txtHint)!
        btnDemo = v.findViewById(R.id.btnDemo)!
        btnAgain = v.findViewById(R.id.btnAgain)!
        btnNext = v.findViewById(R.id.btnNext)!
        donePanel = v.findViewById(R.id.donePanel)!
        imgDoneBig = v.findViewById(R.id.imgDoneBig)!
        txtDoneBig = v.findViewById(R.id.txtDoneBig)!
        txtDoneMsg = v.findViewById(R.id.txtDoneMsg)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ActivityTraceBinding {
        ActivityTraceBinding(inflater.inflate(R.layout.activity_trace, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ActivityTraceBinding {
        ActivityTraceBinding(inflater.inflate(R.layout.activity_trace, parent, attachToParent))
    }
    static func bind(_ v: View) -> ActivityTraceBinding { ActivityTraceBinding(v) }
}

final class ActivityTrackBinding {
    let root: LinearLayout
    let btnBack: Button
    let txtTitle: TextView
    let txtTrackProgress: TextView
    let unitsBox: LinearLayout

    private init(_ v: View) {
        root = v as! LinearLayout
        btnBack = v.findViewById(R.id.btnBack)!
        txtTitle = v.findViewById(R.id.txtTitle)!
        txtTrackProgress = v.findViewById(R.id.txtTrackProgress)!
        unitsBox = v.findViewById(R.id.unitsBox)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ActivityTrackBinding {
        ActivityTrackBinding(inflater.inflate(R.layout.activity_track, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ActivityTrackBinding {
        ActivityTrackBinding(inflater.inflate(R.layout.activity_track, parent, attachToParent))
    }
    static func bind(_ v: View) -> ActivityTrackBinding { ActivityTrackBinding(v) }
}

final class ActivityWalletBinding {
    let root: ScrollView
    let btnBack: Button
    let btnParent: TextView
    let txtBalance: TextView
    let txtSummary: TextView
    let btnPayout: Button
    let shopBox: LinearLayout
    let logBox: LinearLayout

    private init(_ v: View) {
        root = v as! ScrollView
        btnBack = v.findViewById(R.id.btnBack)!
        btnParent = v.findViewById(R.id.btnParent)!
        txtBalance = v.findViewById(R.id.txtBalance)!
        txtSummary = v.findViewById(R.id.txtSummary)!
        btnPayout = v.findViewById(R.id.btnPayout)!
        shopBox = v.findViewById(R.id.shopBox)!
        logBox = v.findViewById(R.id.logBox)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ActivityWalletBinding {
        ActivityWalletBinding(inflater.inflate(R.layout.activity_wallet, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ActivityWalletBinding {
        ActivityWalletBinding(inflater.inflate(R.layout.activity_wallet, parent, attachToParent))
    }
    static func bind(_ v: View) -> ActivityWalletBinding { ActivityWalletBinding(v) }
}

final class ViewQMatchBinding {
    let root: LinearLayout
    let txtKind: TextView
    let txtCountInline: TextView
    let leftCol: LinearLayout
    let rightCol: LinearLayout

    private init(_ v: View) {
        root = v as! LinearLayout
        txtKind = v.findViewById(R.id.txtKind)!
        txtCountInline = v.findViewById(R.id.txtCountInline)!
        leftCol = v.findViewById(R.id.leftCol)!
        rightCol = v.findViewById(R.id.rightCol)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ViewQMatchBinding {
        ViewQMatchBinding(inflater.inflate(R.layout.view_q_match, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ViewQMatchBinding {
        ViewQMatchBinding(inflater.inflate(R.layout.view_q_match, parent, attachToParent))
    }
    static func bind(_ v: View) -> ViewQMatchBinding { ViewQMatchBinding(v) }
}

final class ViewQMcqBinding {
    let root: LinearLayout
    let txtKind: TextView
    let txtCountInline: TextView
    let txtPassage: TextView
    let btnPlay: Button
    let btnPlaySlow: Button
    let txtBigEmoji: TextView
    let txtPrompt: TextView
    let choicesBox: LinearLayout

    private init(_ v: View) {
        root = v as! LinearLayout
        txtKind = v.findViewById(R.id.txtKind)!
        txtCountInline = v.findViewById(R.id.txtCountInline)!
        txtPassage = v.findViewById(R.id.txtPassage)!
        btnPlay = v.findViewById(R.id.btnPlay)!
        btnPlaySlow = v.findViewById(R.id.btnPlaySlow)!
        txtBigEmoji = v.findViewById(R.id.txtBigEmoji)!
        txtPrompt = v.findViewById(R.id.txtPrompt)!
        choicesBox = v.findViewById(R.id.choicesBox)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ViewQMcqBinding {
        ViewQMcqBinding(inflater.inflate(R.layout.view_q_mcq, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ViewQMcqBinding {
        ViewQMcqBinding(inflater.inflate(R.layout.view_q_mcq, parent, attachToParent))
    }
    static func bind(_ v: View) -> ViewQMcqBinding { ViewQMcqBinding(v) }
}

final class ViewQOrderBinding {
    let root: LinearLayout
    let txtKind: TextView
    let txtCountInline: TextView
    let txtPrompt: TextView
    let answerFlow: FlowLayout
    let bankFlow: FlowLayout

    private init(_ v: View) {
        root = v as! LinearLayout
        txtKind = v.findViewById(R.id.txtKind)!
        txtCountInline = v.findViewById(R.id.txtCountInline)!
        txtPrompt = v.findViewById(R.id.txtPrompt)!
        answerFlow = v.findViewById(R.id.answerFlow)!
        bankFlow = v.findViewById(R.id.bankFlow)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ViewQOrderBinding {
        ViewQOrderBinding(inflater.inflate(R.layout.view_q_order, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ViewQOrderBinding {
        ViewQOrderBinding(inflater.inflate(R.layout.view_q_order, parent, attachToParent))
    }
    static func bind(_ v: View) -> ViewQOrderBinding { ViewQOrderBinding(v) }
}

final class ViewQSpeakBinding {
    let root: LinearLayout
    let txtKind: TextView
    let txtCountInline: TextView
    let txtEn: TextView
    let txtKo: TextView
    let btnListen: Button
    let btnMic: Button
    let txtHeard: TextView
    let btnCantSpeak: Button

    private init(_ v: View) {
        root = v as! LinearLayout
        txtKind = v.findViewById(R.id.txtKind)!
        txtCountInline = v.findViewById(R.id.txtCountInline)!
        txtEn = v.findViewById(R.id.txtEn)!
        txtKo = v.findViewById(R.id.txtKo)!
        btnListen = v.findViewById(R.id.btnListen)!
        btnMic = v.findViewById(R.id.btnMic)!
        txtHeard = v.findViewById(R.id.txtHeard)!
        btnCantSpeak = v.findViewById(R.id.btnCantSpeak)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ViewQSpeakBinding {
        ViewQSpeakBinding(inflater.inflate(R.layout.view_q_speak, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ViewQSpeakBinding {
        ViewQSpeakBinding(inflater.inflate(R.layout.view_q_speak, parent, attachToParent))
    }
    static func bind(_ v: View) -> ViewQSpeakBinding { ViewQSpeakBinding(v) }
}

final class ViewQTypeBinding {
    let root: LinearLayout
    let txtKind: TextView
    let txtCountInline: TextView
    let btnPlay: Button
    let btnPlaySlow: Button
    let txtPrompt: TextView
    let txtHint: TextView
    let editAnswer: EditText

    private init(_ v: View) {
        root = v as! LinearLayout
        txtKind = v.findViewById(R.id.txtKind)!
        txtCountInline = v.findViewById(R.id.txtCountInline)!
        btnPlay = v.findViewById(R.id.btnPlay)!
        btnPlaySlow = v.findViewById(R.id.btnPlaySlow)!
        txtPrompt = v.findViewById(R.id.txtPrompt)!
        txtHint = v.findViewById(R.id.txtHint)!
        editAnswer = v.findViewById(R.id.editAnswer)!
    }
    static func inflate(_ inflater: LayoutInflater) -> ViewQTypeBinding {
        ViewQTypeBinding(inflater.inflate(R.layout.view_q_type, nil, false))
    }
    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> ViewQTypeBinding {
        ViewQTypeBinding(inflater.inflate(R.layout.view_q_type, parent, attachToParent))
    }
    static func bind(_ v: View) -> ViewQTypeBinding { ViewQTypeBinding(v) }
}

enum Bindings {
    /// 레이아웃 XML 에 쓰인 직접 만든 부품
    static func registerCustomViews() {
        LayoutInflater.customViews["com.piyak.english.ui.CelebrateOverlayView"] = { CelebrateOverlayView($0, nil) }
        LayoutInflater.customViews["com.piyak.english.ui.ChickView"] = { ChickView($0, nil) }
        LayoutInflater.customViews["com.piyak.english.ui.FlowLayout"] = { FlowLayout($0, nil) }
        LayoutInflater.customViews["com.piyak.english.ui.TraceView"] = { TraceView($0, nil) }
    }
}
