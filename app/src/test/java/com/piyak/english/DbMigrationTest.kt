package com.piyak.english

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * DB 버전과 마이그레이션 번호가 어긋나지 않는지.
 *
 * v2.0 에서 `oldV < 6` 마이그레이션(writes 열 추가)을 써 놓고 **버전을 5에 둔 채**
 * 내보냈다. 마이그레이션은 영영 실행되지 않았고, v1 시절부터 쓰던 폰에서만
 * 알파벳 화면이 죽었다 — 새 설치는 onCreate 가 최신 스키마라 멀쩡해서,
 * 개발 중에는 절대 재현되지 않는 종류의 버그다.
 *
 * 그래서 소스를 직접 읽어 검사한다: onUpgrade 에 `oldV < N` 이 있으면
 * 선언된 DB 버전이 N 이상이어야 한다.
 */
class DbMigrationTest {

    private fun dbSource(): String {
        val candidates = listOf(
            File("src/main/java/com/piyak/english/db/Db.kt"),
            File("app/src/main/java/com/piyak/english/db/Db.kt"),
        )
        val f = candidates.firstOrNull { it.isFile } ?: error("Db.kt 를 찾을 수 없다")
        return f.readText()
    }

    @Test fun dbVersionCoversEveryMigration() {
        val src = dbSource()

        val version = Regex("\"piyak\\.db\",\\s*null,\\s*(\\d+)")
            .find(src)?.groupValues?.get(1)?.toInt()
            ?: error("DB 버전 선언을 찾을 수 없다")

        val migrations = Regex("oldV\\s*<\\s*(\\d+)")
            .findAll(src).map { it.groupValues[1].toInt() }.toList()
        assertTrue("onUpgrade 마이그레이션이 하나도 안 보인다", migrations.isNotEmpty())

        val need = migrations.max()
        assertTrue(
            "마이그레이션은 oldV < $need 까지 있는데 DB 버전이 $version 이다. " +
                "버전을 $need 로 올리지 않으면 업그레이드된 폰에서 마이그레이션이 실행되지 않는다 " +
                "(새 설치만 멀쩡해서 개발 중엔 재현되지 않는다!)",
            version >= need
        )
    }
}
