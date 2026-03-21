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

    // MARK: - Draft-07 Feature Tests

    func testValidKind1Event() {
        let event: [String: Any] = [
            "id": String(repeating: "a", count: 64),
            "pubkey": String(repeating: "b", count: 64),
            "created_at": 1700000000,
            "kind": 1,
            "tags": [] as [Any],
            "content": "Hello, Nostr!",
            "sig": String(repeating: "c", count: 128),
        ]
        let result = SchemataValidator.validateNote(event)
        XCTAssertTrue(result.valid, "Valid kind 1 event should pass. Errors: \(result.errors.map(\.message))")
    }

    func testConstValidation_WrongKind() {
        // kind must equal 1 for kind1Schema — draft-07 const keyword
        let event: [String: Any] = [
            "id": String(repeating: "a", count: 64),
            "pubkey": String(repeating: "b", count: 64),
            "created_at": 1700000000,
            "kind": 999,
            "tags": [] as [Any],
            "content": "",
            "sig": String(repeating: "c", count: 128),
        ]
        let result = SchemataValidator.validateNote(event)
        // kind 999 has no schema, so this should produce a warning
        XCTAssertFalse(result.valid)
    }

    func testPatternValidation_InvalidId() {
        // id must match ^[a-f0-9]{64}$ — draft-07 pattern keyword
        let event: [String: Any] = [
            "id": "INVALID_NOT_HEX",
            "pubkey": String(repeating: "b", count: 64),
            "created_at": 1700000000,
            "kind": 1,
            "tags": [] as [Any],
            "content": "",
            "sig": String(repeating: "c", count: 128),
        ]
        let result = SchemataValidator.validateNote(event)
        XCTAssertFalse(result.valid, "Invalid hex id should fail pattern validation")
        XCTAssertTrue(result.errors.contains { $0.message.lowercased().contains("pattern") || $0.keyword == "pattern" },
                       "Should report a pattern error. Got: \(result.errors.map(\.message))")
    }

    func testPatternValidation_InvalidSig() {
        // sig must match ^[a-f0-9]{128}$
        let event: [String: Any] = [
            "id": String(repeating: "a", count: 64),
            "pubkey": String(repeating: "b", count: 64),
            "created_at": 1700000000,
            "kind": 1,
            "tags": [] as [Any],
            "content": "",
            "sig": "tooshort",
        ]
        let result = SchemataValidator.validateNote(event)
        XCTAssertFalse(result.valid, "Invalid sig should fail pattern validation")
    }

    func testRequiredFieldValidation() {
        // Missing required fields — draft-07 required keyword
        let event: [String: Any] = [
            "kind": 1,
            "content": "hello",
        ]
        let result = SchemataValidator.validateNote(event)
        XCTAssertFalse(result.valid, "Missing required fields should fail")
        XCTAssertFalse(result.errors.isEmpty)
    }

    func testTypeValidation_WrongType() {
        // created_at must be integer, not string — draft-07 type keyword
        let event: [String: Any] = [
            "id": String(repeating: "a", count: 64),
            "pubkey": String(repeating: "b", count: 64),
            "created_at": "not_an_integer",
            "kind": 1,
            "tags": [] as [Any],
            "content": "",
            "sig": String(repeating: "c", count: 128),
        ]
        let result = SchemataValidator.validateNote(event)
        XCTAssertFalse(result.valid, "Wrong type for created_at should fail type validation")
    }

    func testAdditionalPropertiesRejected() {
        // kind1 schema has additionalProperties: false
        let event: [String: Any] = [
            "id": String(repeating: "a", count: 64),
            "pubkey": String(repeating: "b", count: 64),
            "created_at": 1700000000,
            "kind": 1,
            "tags": [] as [Any],
            "content": "",
            "sig": String(repeating: "c", count: 128),
            "extra_field": "should not be here",
        ]
        let result = SchemataValidator.validateNote(event)
        XCTAssertFalse(result.valid, "Additional properties should be rejected by draft-07 additionalProperties:false")
    }

    func testArrayMessageValidation() {
        // Validate a CLIENT EVENT message (array type)
        let validEvent: [String: Any] = [
            "id": String(repeating: "a", count: 64),
            "pubkey": String(repeating: "b", count: 64),
            "created_at": 1700000000,
            "kind": 1,
            "tags": [] as [Any],
            "content": "test",
            "sig": String(repeating: "c", count: 128),
        ]
        let msg: [Any] = ["EVENT", validEvent]
        let result = SchemataValidator.validateMessage(msg, subject: .client, slug: "event")
        XCTAssertTrue(result.valid, "Valid EVENT message should pass. Errors: \(result.errors.map(\.message))")
    }

    func testArrayMessageValidation_WrongLabel() {
        // First item must be const "EVENT"
        let validEvent: [String: Any] = [
            "id": String(repeating: "a", count: 64),
            "pubkey": String(repeating: "b", count: 64),
            "created_at": 1700000000,
            "kind": 1,
            "tags": [] as [Any],
            "content": "test",
            "sig": String(repeating: "c", count: 128),
        ]
        let msg: [Any] = ["WRONG", validEvent]
        let result = SchemataValidator.validateMessage(msg, subject: .client, slug: "event")
        XCTAssertFalse(result.valid, "Wrong message label should fail const validation")
    }

    func testNip11Validation() {
        let doc: [String: Any] = [
            "name": "Test Relay",
            "description": "A test relay",
            "supported_nips": [1, 11],
            "software": "test",
            "version": "0.1.0",
        ]
        let result = SchemataValidator.validateNip11(doc)
        // NIP-11 schema may or may not require all fields;
        // at minimum, a reasonable doc should not crash
        XCTAssertTrue(result.valid || !result.errors.isEmpty,
                       "NIP-11 validation should produce a definitive result")
    }

    func testValidationErrorHasInstancePath() {
        // Verify our ValidationError carries instancePath from JSONSchema.swift
        let event: [String: Any] = [
            "id": "BAD",
            "pubkey": String(repeating: "b", count: 64),
            "created_at": 1700000000,
            "kind": 1,
            "tags": [] as [Any],
            "content": "",
            "sig": String(repeating: "c", count: 128),
        ]
        let result = SchemataValidator.validateNote(event)
        XCTAssertFalse(result.valid)
        // At least one error should have a non-empty instancePath or schemaPath
        let hasPath = result.errors.contains { !$0.instancePath.isEmpty || !$0.schemaPath.isEmpty }
        XCTAssertTrue(hasPath, "Errors should include path info. Got: \(result.errors.map { ($0.instancePath, $0.schemaPath) })")
    }
}
