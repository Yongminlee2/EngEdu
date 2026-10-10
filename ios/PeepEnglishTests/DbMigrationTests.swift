import XCTest
@testable import PeepEnglish

/// DB 버전과 마이그레이션 번호가 어긋나지 않는지.
///
/// 안드로이드 v2.0 에서 `oldV < 6` 마이그레이션을 써 놓고 버전을 5에 둔 채 내보내,
/// 업그레이드된 폰에서만 알파벳 화면이 죽었다(새 설치는 멀쩡해서 개발 중엔 재현되지 않는다).
/// 그래서 소스를 직접 읽어 검사한다: onUpgrade 에 `oldV < N` 이 있으면 DB 버전이 N 이상이어야 한다.
/// 아이폰판은 Db.kt 와 Db.swift 둘 다 보고, 두 버전이 같은지도 본다(같은 piyak.db 형식).
final class DbMigrationTests: XCTestCase {

    private func dbSource() -> String {
        let src = RepoPaths.read("java/com/piyak/english/db/Db.kt")
        precondition(!src.isEmpty, "Db.kt 를 찾을 수 없다")
        return src
    }

    private func swiftDbSource() -> String {
        let u = RepoPaths.repo.appendingPathComponent("ios/PeepEnglish/Core/db/Db.swift")
        let src = TestSupport.readText(u)
        precondition(!src.isEmpty, "Db.swift 를 찾을 수 없다")
        return src
    }

    private func migrations(_ src: String) -> [Int] {
        TestSupport.findAll(#"oldV\s*<\s*(\d+)"#, src).map { Int($0[1])! }
    }

    func test_dbVersionCoversEveryMigration() {
        let src = dbSource()

        guard let vs = TestSupport.find(#""piyak\.db",\s*null,\s*(\d+)"#, src)?[1], let version = Int(vs) else {
            XCTFail("DB 버전 선언을 찾을 수 없다"); return
        }

        let migs = migrations(src)
        XCTAssertTrue(migs.isNotEmpty(), "onUpgrade 마이그레이션이 하나도 안 보인다")

        let need = migs.max() ?? 0
        XCTAssertTrue(
            version >= need,
            "마이그레이션은 oldV < \(need) 까지 있는데 DB 버전이 \(version) 이다. " +
                "버전을 \(need) 로 올리지 않으면 업그레이드된 폰에서 마이그레이션이 실행되지 않는다 " +
                "(새 설치만 멀쩡해서 개발 중엔 재현되지 않는다!)"
        )

        // 아이폰판: 같은 검사를 Db.swift 에 하고, 버전이 안드로이드와 같은지 본다
        let swiftMigs = migrations(swiftDbSource())
        XCTAssertTrue(swiftMigs.isNotEmpty(), "Db.swift 에 onUpgrade 마이그레이션이 하나도 안 보인다")
        XCTAssertEqual(swiftMigs, migs, "Db.swift 의 마이그레이션이 Db.kt 와 다르다")
        XCTAssertTrue(Db.DB_VERSION >= (swiftMigs.max() ?? 0), "Db.swift 의 DB_VERSION 이 마이그레이션보다 낮다")
        XCTAssertEqual(Db.DB_VERSION, version, "Db.swift 의 DB_VERSION 이 Db.kt 의 버전과 다르다")
    }
}
