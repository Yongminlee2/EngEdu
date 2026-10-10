import Foundation
import SQLite3

// 안드로이드 SQLiteOpenHelper·Cursor·ContentValues 와 org.json 의 아이폰판.
// 저장 형식(표·열 이름)이 안드로이드와 같아서 Db.kt 를 한 줄씩 옮길 수 있다.

// MARK: - SQLite

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class ContentValues {
    private(set) var values: [(String, Any?)] = []
    init() {}
    func put(_ key: String, _ value: Any?) {
        values.removeAll { $0.0 == key }
        values.append((key, value))
    }
    func clear() { values.removeAll() }
}

final class Cursor {
    private var stmt: OpaquePointer?
    private var rowReady = false
    private var done = false
    private var started = false
    private var rows: [[Any?]] = []
    private var pos = -1
    let columnNames: [String]

    init(_ stmt: OpaquePointer?) {
        self.stmt = stmt
        var names: [String] = []
        let n = sqlite3_column_count(stmt)
        for i in 0..<n { names.append(String(cString: sqlite3_column_name(stmt, i))) }
        columnNames = names
        // 다 읽어 둔다 — 안드로이드 Cursor 처럼 앞뒤로 움직이고 count 를 알 수 있게
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [Any?] = []
            for i in 0..<n {
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_INTEGER: row.append(Int(sqlite3_column_int64(stmt, i)))
                case SQLITE_FLOAT: row.append(sqlite3_column_double(stmt, i))
                case SQLITE_NULL: row.append(nil)
                default:
                    if let c = sqlite3_column_text(stmt, i) { row.append(String(cString: c)) } else { row.append(nil) }
                }
            }
            rows.append(row)
        }
        sqlite3_finalize(stmt)
        self.stmt = nil
    }

    var count: Int { rows.count }
    func getCount() -> Int { rows.count }
    @discardableResult func moveToFirst() -> Bool { pos = 0; return !rows.isEmpty }
    @discardableResult func moveToNext() -> Bool { pos += 1; return pos < rows.count }
    @discardableResult func moveToPosition(_ p: Int) -> Bool { pos = p; return p >= 0 && p < rows.count }
    @discardableResult func moveToLast() -> Bool { pos = rows.count - 1; return !rows.isEmpty }
    var position: Int { pos }
    var isAfterLast: Bool { pos >= rows.count }

    func getColumnIndex(_ name: String) -> Int { columnNames.firstIndex(of: name) ?? -1 }
    func getColumnIndexOrThrow(_ name: String) -> Int { columnNames.firstIndex(of: name)! }
    private func v(_ i: Int) -> Any? { pos >= 0 && pos < rows.count && i >= 0 && i < rows[pos].count ? rows[pos][i] : nil }
    func getString(_ i: Int) -> String {
        switch v(i) {
        case let s as String: return s
        case let n as Int: return String(n)
        case let d as Double: return JavaFormat.kotlinFloatString(d)
        default: return ""
        }
    }
    func getInt(_ i: Int) -> Int {
        switch v(i) { case let n as Int: return n; case let d as Double: return Int(d); case let s as String: return Int(s) ?? 0; default: return 0 }
    }
    func getLong(_ i: Int) -> Int { getInt(i) }
    func getDouble(_ i: Int) -> Double {
        switch v(i) { case let n as Int: return Double(n); case let d as Double: return d; case let s as String: return Double(s) ?? 0; default: return 0 }
    }
    func getFloat(_ i: Int) -> Float { Float(getDouble(i)) }
    func isNull(_ i: Int) -> Bool { v(i) == nil }
    func close() {}

    /// 코틀린 `cursor.use { ... }`
    func use<T>(_ block: (Cursor) throws -> T) rethrows -> T { try block(self) }
}

final class SQLiteDatabase {
    static let CONFLICT_NONE = 0, CONFLICT_REPLACE = 5, CONFLICT_IGNORE = 4

    fileprivate var handle: OpaquePointer?
    init(handle: OpaquePointer?) { self.handle = handle }

    var version: Int {
        get { (try? rawQuery("PRAGMA user_version", nil).use { c -> Int in c.moveToFirst() ? c.getInt(0) : 0 }) ?? 0 }
        set { execSQL("PRAGMA user_version = \(newValue)") }
    }

    private func prepare(_ sql: String, _ args: [Any?]?) -> OpaquePointer? {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(handle))
            fatalError("SQL 오류: \(msg) — \(sql)")
        }
        for (i, a) in (args ?? []).enumerated() {
            let idx = Int32(i + 1)
            switch a {
            case nil: sqlite3_bind_null(stmt, idx)
            case let n as Int: sqlite3_bind_int64(stmt, idx, Int64(n))
            case let n as Int64: sqlite3_bind_int64(stmt, idx, n)
            case let n as Int32: sqlite3_bind_int64(stmt, idx, Int64(n))
            case let b as Bool: sqlite3_bind_int64(stmt, idx, b ? 1 : 0)
            case let d as Double: sqlite3_bind_double(stmt, idx, d)
            case let f as Float: sqlite3_bind_double(stmt, idx, Double(f))
            case let s as String: sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
            default: sqlite3_bind_text(stmt, idx, "\(a!)", -1, SQLITE_TRANSIENT)
            }
        }
        return stmt
    }

    func execSQL(_ sql: String) { execSQL(sql, nil) }
    func execSQL(_ sql: String, _ args: [Any?]?) {
        let stmt = prepare(sql, args)
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        if rc != SQLITE_DONE && rc != SQLITE_ROW {
            let msg = String(cString: sqlite3_errmsg(handle))
            NSException(name: .genericException, reason: "SQL 실행 실패: \(msg) — \(sql)").raise()
        }
    }
    /// 실패해도 앱을 죽이지 않는다 (코틀린 runCatching { db.execSQL(...) })
    @discardableResult func tryExecSQL(_ sql: String, _ args: [Any?]? = nil) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_finalize(stmt)
        execSQL(sql, args)
        return true
    }

    func rawQuery(_ sql: String, _ args: [Any?]?) -> Cursor { Cursor(prepare(sql, args)) }

    @discardableResult func insert(_ table: String, _ nullHack: String?, _ cv: ContentValues) -> Int {
        insertWithOnConflict(table, nullHack, cv, SQLiteDatabase.CONFLICT_NONE)
    }
    @discardableResult func insertWithOnConflict(_ table: String, _ nullHack: String?, _ cv: ContentValues, _ conflict: Int) -> Int {
        let verb: String
        switch conflict {
        case SQLiteDatabase.CONFLICT_REPLACE: verb = "INSERT OR REPLACE"
        case SQLiteDatabase.CONFLICT_IGNORE: verb = "INSERT OR IGNORE"
        default: verb = "INSERT"
        }
        let cols = cv.values.map { $0.0 }
        let sql = "\(verb) INTO \(table)(\(cols.joined(separator: ","))) VALUES(\(cols.map { _ in "?" }.joined(separator: ",")))"
        let stmt = prepare(sql, cv.values.map { $0.1 })
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        return rc == SQLITE_DONE ? Int(sqlite3_last_insert_rowid(handle)) : -1
    }
    @discardableResult func update(_ table: String, _ cv: ContentValues, _ whereClause: String?, _ whereArgs: [Any?]?) -> Int {
        let sets = cv.values.map { "\($0.0)=?" }.joined(separator: ",")
        var sql = "UPDATE \(table) SET \(sets)"
        if let w = whereClause { sql += " WHERE \(w)" }
        let stmt = prepare(sql, cv.values.map { $0.1 } + (whereArgs ?? []))
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        return Int(sqlite3_changes(handle))
    }
    @discardableResult func delete(_ table: String, _ whereClause: String?, _ whereArgs: [Any?]?) -> Int {
        var sql = "DELETE FROM \(table)"
        if let w = whereClause { sql += " WHERE \(w)" }
        let stmt = prepare(sql, whereArgs)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        return Int(sqlite3_changes(handle))
    }
    func beginTransaction() { execSQL("BEGIN") }
    func setTransactionSuccessful() { txOK = true }
    func endTransaction() { execSQL(txOK ? "COMMIT" : "ROLLBACK"); txOK = false }
    private var txOK = false
    /// 코틀린 `db.transaction { }`
    func transaction(_ block: (SQLiteDatabase) -> Void) {
        beginTransaction(); block(self); setTransactionSuccessful(); endTransaction()
    }
}

/// 안드로이드 SQLiteOpenHelper — 처음이면 onCreate, 버전이 오르면 onUpgrade.
class SQLiteOpenHelper {
    let name: String
    let version: Int
    private var db: SQLiteDatabase?

    init(_ context: Context?, _ name: String, _ factory: Any?, _ version: Int) {
        self.name = name; self.version = version
    }

    func onCreate(_ db: SQLiteDatabase) {}
    func onUpgrade(_ db: SQLiteDatabase, _ oldV: Int, _ newV: Int) {}
    func onOpen(_ db: SQLiteDatabase) {}

    /// 파일 위치 — 안드로이드 databases/ 와 같은 이름
    static var databasesDir: URL = {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("databases")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()

    private func open() -> SQLiteDatabase {
        if let d = db { return d }
        var h: OpaquePointer?
        let path = SQLiteOpenHelper.databasesDir.appendingPathComponent(name).path
        guard sqlite3_open(path, &h) == SQLITE_OK else { fatalError("DB 를 열 수 없음: \(path)") }
        let d = SQLiteDatabase(handle: h)
        db = d
        let cur = d.version
        if cur == 0 {
            d.beginTransaction(); onCreate(d); d.version = version; d.setTransactionSuccessful(); d.endTransaction()
        } else if cur < version {
            d.beginTransaction(); onUpgrade(d, cur, version); d.version = version; d.setTransactionSuccessful(); d.endTransaction()
        }
        onOpen(d)
        return d
    }

    var readableDatabase: SQLiteDatabase { open() }
    var writableDatabase: SQLiteDatabase { open() }
    func close() { if let d = db { sqlite3_close(d.handle); d.handle = nil }; db = nil }
}

// MARK: - org.json

final class JSONException: Error, CustomStringConvertible {
    let description: String
    init(_ msg: String) { description = msg }
}

/// org.json.JSONObject — 넣은 순서를 지킨다(keys() 가 파일 순서로 나온다).
final class JSONObject: CustomStringConvertible {
    private(set) var keysInOrder: [String] = []
    private(set) var map: [String: Any] = [:]

    init() {}
    convenience init(_ text: String) throws {
        self.init()
        guard let data = text.data(using: .utf8) else { throw JSONException("bad text") }
        let obj = try JSONOrdered.parse(data)
        guard let o = obj as? JSONObject else { throw JSONException("not an object") }
        keysInOrder = o.keysInOrder; map = o.map
    }
    /// 실패하면 앱을 멈춘다 (팩 파일처럼 반드시 맞아야 하는 것)
    static func parse(_ text: String) -> JSONObject { try! JSONObject(text) }

    fileprivate func set(_ k: String, _ v: Any) { if map[k] == nil { keysInOrder.append(k) }; map[k] = v }

    func has(_ k: String) -> Bool { map[k] != nil && !(map[k] is NSNull) }
    func isNull(_ k: String) -> Bool { map[k] == nil || map[k] is NSNull }
    func keys() -> [String] { keysInOrder }
    func length() -> Int { keysInOrder.count }
    func opt(_ k: String) -> Any? { map[k] }

    func getString(_ k: String) -> String {
        switch map[k] { case let s as String: return s; case let n as Int: return String(n); case let d as Double: return JSONOrdered.numString(d); case let b as Bool: return b ? "true" : "false"; default: return "" }
    }
    func optString(_ k: String, _ def: String = "") -> String { has(k) ? getString(k) : def }
    func getInt(_ k: String) -> Int {
        switch map[k] { case let n as Int: return n; case let d as Double: return Int(d); case let s as String: return Int(s) ?? 0; default: return 0 }
    }
    func optInt(_ k: String, _ def: Int = 0) -> Int { has(k) ? getInt(k) : def }
    func getLong(_ k: String) -> Int { getInt(k) }
    func optLong(_ k: String, _ def: Int = 0) -> Int { optInt(k, def) }
    func getDouble(_ k: String) -> Double {
        switch map[k] { case let n as Int: return Double(n); case let d as Double: return d; case let s as String: return Double(s) ?? 0; default: return 0 }
    }
    func optDouble(_ k: String, _ def: Double = .nan) -> Double { has(k) ? getDouble(k) : def }
    func getBoolean(_ k: String) -> Bool {
        switch map[k] { case let b as Bool: return b; case let s as String: return s == "true"; default: return false }
    }
    func optBoolean(_ k: String, _ def: Bool = false) -> Bool { has(k) ? getBoolean(k) : def }
    func getJSONObject(_ k: String) -> JSONObject { map[k] as? JSONObject ?? JSONObject() }
    func optJSONObject(_ k: String) -> JSONObject? { map[k] as? JSONObject }
    func getJSONArray(_ k: String) -> JSONArray { map[k] as? JSONArray ?? JSONArray() }
    func optJSONArray(_ k: String) -> JSONArray? { map[k] as? JSONArray }

    @discardableResult func put(_ k: String, _ v: Any?) -> JSONObject { set(k, v ?? NSNull()); return self }
    func remove(_ k: String) { map[k] = nil; keysInOrder.removeAll { $0 == k } }

    var description: String { JSONOrdered.serialize(self) }
    func toString() -> String { description }
}

final class JSONArray: CustomStringConvertible {
    private(set) var items: [Any] = []
    init() {}
    convenience init(_ text: String) throws {
        self.init()
        guard let data = text.data(using: .utf8), let a = try JSONOrdered.parse(data) as? JSONArray else { throw JSONException("not an array") }
        items = a.items
    }
    init(_ list: [Any]) { items = list }
    fileprivate func append(_ v: Any) { items.append(v) }

    func length() -> Int { items.count }
    func get(_ i: Int) -> Any { items[i] }
    func opt(_ i: Int) -> Any? { i >= 0 && i < items.count ? items[i] : nil }
    func getString(_ i: Int) -> String {
        switch items[i] { case let s as String: return s; case let n as Int: return String(n); case let d as Double: return JSONOrdered.numString(d); default: return "\(items[i])" }
    }
    func optString(_ i: Int, _ def: String = "") -> String { i < items.count ? getString(i) : def }
    func getInt(_ i: Int) -> Int {
        switch items[i] { case let n as Int: return n; case let d as Double: return Int(d); case let s as String: return Int(s) ?? 0; default: return 0 }
    }
    func optInt(_ i: Int, _ def: Int = 0) -> Int { i < items.count ? getInt(i) : def }
    func getLong(_ i: Int) -> Int { getInt(i) }
    func getDouble(_ i: Int) -> Double {
        switch items[i] { case let n as Int: return Double(n); case let d as Double: return d; case let s as String: return Double(s) ?? 0; default: return 0 }
    }
    func getBoolean(_ i: Int) -> Bool { items[i] as? Bool ?? false }
    func getJSONObject(_ i: Int) -> JSONObject { items[i] as? JSONObject ?? JSONObject() }
    func optJSONObject(_ i: Int) -> JSONObject? { opt(i) as? JSONObject }
    func getJSONArray(_ i: Int) -> JSONArray { items[i] as? JSONArray ?? JSONArray() }
    func optJSONArray(_ i: Int) -> JSONArray? { opt(i) as? JSONArray }
    @discardableResult func put(_ v: Any?) -> JSONArray { items.append(v ?? NSNull()); return self }

    var description: String { JSONOrdered.serialize(self) }
    func toString() -> String { description }
}

/// 순서를 지키는 작은 JSON 해석기 (JSONSerialization 은 키 순서를 잃는다)
enum JSONOrdered {
    static func parse(_ data: Data) throws -> Any {
        var p = Parser(bytes: [UInt8](data))
        p.skipWS()
        let v = try p.value()
        return v
    }

    static func numString(_ d: Double) -> String {
        if d == d.rounded() && abs(d) < 1e15 { return String(Int(d)) }
        return "\(d)"
    }

    static func serialize(_ v: Any) -> String {
        switch v {
        case let o as JSONObject:
            return "{" + o.keysInOrder.map { quote($0) + ":" + serialize(o.map[$0]!) }.joined(separator: ",") + "}"
        case let a as JSONArray: return "[" + a.items.map { serialize($0) }.joined(separator: ",") + "]"
        case let s as String: return quote(s)
        case let b as Bool: return b ? "true" : "false"
        case let n as Int: return String(n)
        case let d as Double: return numString(d)
        case let f as Float: return numString(Double(f))
        case is NSNull: return "null"
        default: return quote("\(v)")
        }
    }
    static func quote(_ s: String) -> String {
        var o = "\""
        for u in s.unicodeScalars {
            switch u {
            case "\"": o += "\\\""
            case "\\": o += "\\\\"
            case "\n": o += "\\n"
            case "\r": o += "\\r"
            case "\t": o += "\\t"
            case "/": o += "\\/"
            default:
                if u.value < 0x20 { o += String(format: "\\u%04x", u.value) } else { o.unicodeScalars.append(u) }
            }
        }
        return o + "\""
    }

    private struct Parser {
        let bytes: [UInt8]
        var i = 0
        init(bytes: [UInt8]) { self.bytes = bytes }

        mutating func skipWS() { while i < bytes.count, [0x20, 0x0A, 0x0D, 0x09].contains(bytes[i]) { i += 1 } }

        mutating func value() throws -> Any {
            skipWS()
            guard i < bytes.count else { throw JSONException("end") }
            switch bytes[i] {
            case UInt8(ascii: "{"): return try object()
            case UInt8(ascii: "["): return try array()
            case UInt8(ascii: "\""): return try string()
            case UInt8(ascii: "t"): i += 4; return true
            case UInt8(ascii: "f"): i += 5; return false
            case UInt8(ascii: "n"): i += 4; return NSNull()
            default: return try number()
            }
        }
        mutating func object() throws -> JSONObject {
            let o = JSONObject()
            i += 1
            skipWS()
            if bytes[i] == UInt8(ascii: "}") { i += 1; return o }
            while true {
                skipWS()
                let k = try string()
                skipWS()
                guard bytes[i] == UInt8(ascii: ":") else { throw JSONException("expected :") }
                i += 1
                let v = try value()
                o.set(k, v)
                skipWS()
                if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
                if bytes[i] == UInt8(ascii: "}") { i += 1; return o }
                throw JSONException("bad object at \(i)")
            }
        }
        mutating func array() throws -> JSONArray {
            let a = JSONArray()
            i += 1
            skipWS()
            if bytes[i] == UInt8(ascii: "]") { i += 1; return a }
            while true {
                a.append(try value())
                skipWS()
                if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
                if bytes[i] == UInt8(ascii: "]") { i += 1; return a }
                throw JSONException("bad array at \(i)")
            }
        }
        mutating func string() throws -> String {
            guard bytes[i] == UInt8(ascii: "\"") else { throw JSONException("expected string at \(i)") }
            i += 1
            var buf: [UInt8] = []
            var out = ""
            func flush() { if !buf.isEmpty { out += String(decoding: buf, as: UTF8.self); buf.removeAll() } }
            while i < bytes.count {
                let c = bytes[i]
                if c == UInt8(ascii: "\"") { i += 1; flush(); return out }
                if c == UInt8(ascii: "\\") {
                    flush()
                    let e = bytes[i + 1]
                    i += 2
                    switch e {
                    case UInt8(ascii: "n"): out += "\n"
                    case UInt8(ascii: "t"): out += "\t"
                    case UInt8(ascii: "r"): out += "\r"
                    case UInt8(ascii: "b"): out += "\u{08}"
                    case UInt8(ascii: "f"): out += "\u{0C}"
                    case UInt8(ascii: "u"):
                        var code = UInt32(String(decoding: bytes[i..<(i + 4)], as: UTF8.self), radix: 16) ?? 0x3F
                        i += 4
                        if code >= 0xD800 && code < 0xDC00, i + 6 <= bytes.count, bytes[i] == UInt8(ascii: "\\"), bytes[i + 1] == UInt8(ascii: "u") {
                            let lo = UInt32(String(decoding: bytes[(i + 2)..<(i + 6)], as: UTF8.self), radix: 16) ?? 0
                            if lo >= 0xDC00 && lo < 0xE000 { code = 0x10000 + ((code - 0xD800) << 10) + (lo - 0xDC00); i += 6 }
                        }
                        if let s = Unicode.Scalar(code) { out.unicodeScalars.append(s) }
                    default: out.unicodeScalars.append(Unicode.Scalar(e))
                    }
                    continue
                }
                buf.append(c)
                i += 1
            }
            throw JSONException("unterminated string")
        }
        mutating func number() throws -> Any {
            let start = i
            var isFloat = false
            while i < bytes.count {
                let c = bytes[i]
                if (c >= 0x30 && c <= 0x39) || c == UInt8(ascii: "-") || c == UInt8(ascii: "+") { i += 1 }
                else if c == UInt8(ascii: ".") || c == UInt8(ascii: "e") || c == UInt8(ascii: "E") { isFloat = true; i += 1 }
                else { break }
            }
            let s = String(decoding: bytes[start..<i], as: UTF8.self)
            if !isFloat, let n = Int(s) { return n }
            guard let d = Double(s) else { throw JSONException("bad number \(s)") }
            return d
        }
    }
}
