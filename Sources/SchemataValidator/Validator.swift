import Foundation
import SchemataSwift

/// Nostr JSON schema validator following schemata-validator-rs patterns.
///
/// Note: Swift lacks a mature draft-07 JSON Schema validation library.
/// This implementation performs basic structural validation (const, required).
/// Full draft-07 validation is planned when a suitable Swift library emerges.
public struct SchemataValidator {

    /// Validate a Nostr event by looking up kind{N}Schema.
    public static func validateNote(_ event: [String: Any]) -> ValidationResult {
        guard let kind = event["kind"] as? Int else {
            return ValidationResult(
                valid: false,
                errors: [ValidationError(keyword: "note", message: "Event missing 'kind' field")]
            )
        }

        let key = "kind\(kind)Schema"
        guard let schema = Schemata.get(key) else {
            return ValidationResult(
                valid: false,
                warnings: [ValidationError(keyword: "note", message: "No schema found for kind \(kind)")]
            )
        }
        return basicValidate(schema: schema, data: event)
    }

    /// Validate a NIP-11 relay information document.
    public static func validateNip11(_ doc: [String: Any]) -> ValidationResult {
        guard let schema = Schemata.get("nip11Schema") else {
            return ValidationResult(
                valid: false,
                errors: [ValidationError(keyword: "nip11", message: "nip11Schema not found")]
            )
        }
        return basicValidate(schema: schema, data: doc)
    }

    /// Validate a protocol message.
    public static func validateMessage(_ msg: Any, subject: Subject, slug: String) -> ValidationResult {
        let cap = slug.prefix(1).uppercased() + slug.dropFirst().lowercased()
        let key = "\(subject.description)\(cap)Schema"
        guard let schema = Schemata.get(key) else {
            return ValidationResult(
                valid: false,
                warnings: [ValidationError(keyword: "message", message: "No schema found for \(subject.description) \(slug)")]
            )
        }
        guard let data = msg as? [String: Any] ?? (msg as? [Any]).flatMap({ _ in nil as [String: Any]? }) else {
            // For array messages, just check schema exists
            return ValidationResult(valid: true)
        }
        return basicValidate(schema: schema, data: data)
    }

    /// Look up a schema by key.
    public static func getSchema(_ key: String) -> [String: Any]? {
        return Schemata.get(key)
    }

    /// Basic structural validation checking const and required constraints.
    private static func basicValidate(schema: [String: Any], data: [String: Any]) -> ValidationResult {
        var errors: [ValidationError] = []

        if let allOf = schema["allOf"] as? [[String: Any]] {
            for sub in allOf {
                if let properties = sub["properties"] as? [String: Any] {
                    for (propName, propSchema) in properties {
                        if let constraint = propSchema as? [String: Any],
                           let constValue = constraint["const"] {
                            let actual = data[propName]
                            if !valuesEqual(actual, constValue) {
                                errors.append(ValidationError(
                                    keyword: "const",
                                    message: "\(propName) must equal \(constValue)"
                                ))
                            }
                        }
                    }
                }
                if let required = sub["required"] as? [String] {
                    for field in required {
                        if data[field] == nil {
                            errors.append(ValidationError(
                                keyword: "required",
                                message: "missing required field: \(field)"
                            ))
                        }
                    }
                }
            }
        }

        return ValidationResult(valid: errors.isEmpty, errors: errors)
    }

    private static func valuesEqual(_ a: Any?, _ b: Any?) -> Bool {
        if a == nil && b == nil { return true }
        guard let a = a, let b = b else { return false }
        if let aInt = a as? Int, let bInt = b as? Int { return aInt == bInt }
        if let aStr = a as? String, let bStr = b as? String { return aStr == bStr }
        if let aDouble = a as? Double, let bDouble = b as? Double { return aDouble == bDouble }
        return false
    }
}
