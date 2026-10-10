import XCTest
@testable import PeepEnglish

/// 일반 문제의 상호작용(버블 보기 / 선 잇기)이 실제 콘텐츠에 잘 맞는지
final class InteractionTests: XCTestCase {

    func test_effectSoundDefaultsQuietEnoughForSpeech() {
        // 효과음이 크면 듣기·말하기 음성을 덮는다
        XCTAssertTrue(Sfx.DEFAULT_VOLUME_PERCENT <= 40, "기본 효과음이 너무 큼")
        XCTAssertTrue(Sfx.DEFAULT_VOLUME_PERCENT > 0, "기본 효과음이 0이면 피드백이 사라진다")
    }

    func test_bubbleModeOnlyForShortChoices() {
        XCTAssertTrue(BubbleChoiceView.fits(["12", "13", "14", "15"]))
        XCTAssertTrue(BubbleChoiceView.fits(["🍎", "🍌", "🐶", "🐱"]))
        XCTAssertTrue(BubbleChoiceView.fits(["apple", "banana", "dog", "cat"]))
        // 짧은 한글 낱말은 버블에 들어간다
        XCTAssertTrue(BubbleChoiceView.fits(["사과", "고양이", "무지개", "아이스크림"]))
        // 긴 문장은 버블에 안 들어간다 → 읽기 편한 버튼 목록으로
        XCTAssertFalse(
            BubbleChoiceView.fits([
                "나는 사과를 좋아해요.", "이것은 내 개예요.",
                "해는 뜨거워요.", "나는 별을 봐요.",
            ])
        )
        // 보기가 4개가 아니면 버블 배치가 깨진다
        XCTAssertFalse(BubbleChoiceView.fits(["1", "2", "3"]))
    }

    /// 한글은 글자 수가 적어도 폭이 넓다 — 글자 수로 재면 문장이 버블에 들어가 버린다
    func test_widthScoreCountsWideCharactersAsTwo() {
        XCTAssertEqual(BubbleChoiceView.widthScore("사과"), 4)
        XCTAssertEqual(BubbleChoiceView.widthScore("apple"), 5)
        XCTAssertEqual(BubbleChoiceView.widthScore("🍎"), 2)
        XCTAssertEqual(BubbleChoiceView.widthScore("12"), 2)
        // 11자짜리 한글 문장은 폭 점수가 기준을 훌쩍 넘는다
        XCTAssertTrue(BubbleChoiceView.widthScore("나는 사과를 좋아해요.") > BubbleChoiceView.MAX_WIDTH_SCORE)
    }

    /// 실제 팩에서 버블이 얼마나 쓰이는지 — 아예 안 쓰이면 의미가 없다
    func test_realContentActuallyUsesBubbles() throws {
        var bubble = 0
        var list = 0
        for tid in Subject.ENGLISH.tracks + Subject.MATH.tracks {
            guard let t = try TestSupport.track(tid) else { continue }
            for u in t.units { for l in u.lessons { for q in l.questions {
                let choices: [String]?
                switch q {
                case let q as Question.Mcq: choices = q.choices
                case let q as Question.ListenMcq: choices = q.choices
                case let q as Question.ListenDialog: choices = q.choices
                case let q as Question.Math: choices = q.input == "choice" ? q.choices : nil
                default: choices = nil
                }
                guard let c = choices else { continue }
                if BubbleChoiceView.fits(c) { bubble += 1 } else { list += 1 }
            } } }
        }
        print("버블로 뜨는 문제 \(bubble) · 목록으로 뜨는 문제 \(list)")
        XCTAssertTrue(bubble > 500, "버블이 전혀 안 쓰인다")
        // 긴 보기는 버튼 목록으로 남아야 읽기 편하다
        XCTAssertTrue(list > 0, "모든 문제가 버블이면 문장형 보기가 답답해진다")
    }

    /// 톡톡 누를 때 나는 소리는 자주 울리므로 정답·오답 소리보다 작아야 한다
    func test_tapSoundIsQuieterThanFeedbackSounds() {
        XCTAssertTrue(Sfx.TAP_VOLUME_SCALE < 0.5, "삐약 소리가 정답 소리만큼 크다")
        XCTAssertTrue(Sfx.TAP_VOLUME_SCALE > 0, "삐약 소리가 아예 안 들린다")
    }

    /// 짝 맞추기는 선 잇기로 바뀌었다 — 5쌍이어야 좌우 배치가 맞는다
    func test_matchQuestionsHaveConsistentPairCount() throws {
        var checked = 0
        for tid in Subject.ENGLISH.tracks {
            guard let t = try TestSupport.track(tid) else { continue }
            for u in t.units { for l in u.lessons { for q in l.questions {
                guard let m = q as? Question.Match else { continue }
                XCTAssertEqual(m.pairs.count, 5, "\(m.id): 5쌍이 아님")
                // 오른쪽 값이 겹치면 아무 데나 이어도 맞아 버린다
                XCTAssertEqual(Set(m.pairs.map { $0.second }).count, 5, "\(m.id): 오른쪽 값 중복")
                checked += 1
            } } }
        }
        print("짝 맞추기 문제 수: \(checked)")
        XCTAssertTrue(checked > 0, "짝 맞추기 문제가 없다")
    }
}
