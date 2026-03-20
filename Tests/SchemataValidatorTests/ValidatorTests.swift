import XCTest
@testable import SchemataValidator

final class ValidatorTests: XCTestCase {
    func testGetSchema() {
        XCTAssertNotNil(SchemataValidator.getSchema("kind1Schema"))
        XCTAssertNotNil(SchemataValidator.getSchema("noteSchema"))
        XCTAssertNil(SchemataValidator.getSchema("nonexistent"))
    }

    func testUnknownKindWarning() {
        let event: [String: Any] = [
            "id": String(repeating: "a", count: 64),
            "pubkey": String(repeating: "b", count: 64),
            "created_at": 1700000000,
            "kind": 99999,
            "tags": [] as [Any],
            "content": "",
            "sig": String(repeating: "c", count: 128),
        ]
        let result = SchemataValidator.validateNote(event)
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.warnings.contains { $0.message.contains("No schema found") })
    }

    func testMissingKindError() {
        let event: [String: Any] = ["content": "hello"]
        let result = SchemataValidator.validateNote(event)
        XCTAssertFalse(result.valid)
        XCTAssertFalse(result.errors.isEmpty)
    }
}
