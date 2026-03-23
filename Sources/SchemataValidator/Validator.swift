import Foundation
import JSONSchema

/// Nostr JSON schema validator using kylef/JSONSchema.swift for full draft-07 validation.
///
/// Supports allOf, anyOf, oneOf, contains, if/then/else, $ref,
/// const, pattern, additionalProperties, and all other draft-07 keywords.
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
        return runValidation(schema: schema, data: event)
    }

    /// Validate a NIP-11 relay information document.
    public static func validateNip11(_ doc: [String: Any]) -> ValidationResult {
        guard let schema = Schemata.get("nip11Schema") else {
            return ValidationResult(
                valid: false,
                errors: [ValidationError(keyword: "nip11", message: "nip11Schema not found")]
            )
        }
        return runValidation(schema: schema, data: doc)
    }

    /// Validate a protocol message (may be an array or object).
    public static func validateMessage(_ msg: Any, subject: Subject, slug: String) -> ValidationResult {
        let cap = slug.prefix(1).uppercased() + slug.dropFirst().lowercased()
        let key = "\(subject.description)\(cap)Schema"
        guard let schema = Schemata.get(key) else {
            return ValidationResult(
                valid: false,
                warnings: [ValidationError(keyword: "message", message: "No schema found for \(subject.description) \(slug)")]
            )
        }
        return runValidation(schema: schema, data: msg)
    }

    /// Look up a schema by key.
    public static func getSchema(_ key: String) -> [String: Any]? {
        return Schemata.get(key)
    }

    // MARK: - Private

    /// Run full draft-07 JSON Schema validation using JSONSchema.swift.
    ///
    /// Strips nested `$id` and nested `$schema` from subschemas to prevent
    /// the library from attempting remote resolution or re-selecting validators.
    /// The root-level `$schema` is preserved for draft detection.
    private static func runValidation(schema: [String: Any], data: Any) -> ValidationResult {
        let cleaned = stripNestedMetaKeys(schema)

        let jsResult: JSONSchema.ValidationResult
        do {
            jsResult = try JSONSchema.validate(data, schema: cleaned)
        } catch {
            return ValidationResult(
                valid: false,
                errors: [ValidationError(keyword: "schema", message: "Schema validation error: \(error.localizedDescription)")]
            )
        }

        if jsResult.valid {
            // Collect additional-property warnings from the schema
            let warnings = collectAdditionalPropertyWarnings(schema: cleaned, data: data)
            return ValidationResult(valid: true, warnings: warnings)
        }

        let errors: [ValidationError] = (jsResult.errors ?? []).map { jsErr in
            ValidationError(
                instancePath: jsErr.instanceLocation.path,
                keyword: extractKeyword(from: jsErr.keywordLocation.path),
                message: jsErr.description,
                schemaPath: jsErr.keywordLocation.path
            )
        }
        return ValidationResult(valid: false, errors: errors)
    }

    /// Recursively strip `$id` and `$schema` from nested sub-schemas,
    /// preserving only the root-level `$schema` for draft selection.
    private static func stripNestedMetaKeys(_ schema: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in schema {
            if let dict = value as? [String: Any] {
                result[key] = stripAllMetaKeys(dict)
            } else if let arr = value as? [[String: Any]] {
                result[key] = arr.map { stripAllMetaKeys($0) }
            } else if let arr = value as? [Any] {
                result[key] = arr.map { item -> Any in
                    if let dict = item as? [String: Any] {
                        return stripAllMetaKeys(dict)
                    }
                    return item
                }
            } else {
                result[key] = value
            }
        }
        return result
    }

    /// Strip `$id` and `$schema` from a dictionary and all its descendants.
    private static func stripAllMetaKeys(_ dict: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in dict {
            if key == "$id" || key == "$schema" { continue }
            if let nested = value as? [String: Any] {
                result[key] = stripAllMetaKeys(nested)
            } else if let arr = value as? [[String: Any]] {
                result[key] = arr.map { stripAllMetaKeys($0) }
            } else if let arr = value as? [Any] {
                result[key] = arr.map { item -> Any in
                    if let nested = item as? [String: Any] {
                        return stripAllMetaKeys(nested)
                    }
                    return item
                }
            } else {
                result[key] = value
            }
        }
        return result
    }

    /// Extract the keyword from a JSON Pointer path (last component).
    private static func extractKeyword(from path: String) -> String {
        let components = path.split(separator: "/")
        return components.last.map(String.init) ?? ""
    }

    /// Walk the schema to find properties with additionalProperties and
    /// report any extra keys in the data as warnings (not errors).
    private static func collectAdditionalPropertyWarnings(schema: [String: Any], data: Any) -> [ValidationError] {
        var warnings: [ValidationError] = []

        guard let dataObj = data as? [String: Any] else { return warnings }

        // Collect all declared property names from allOf sub-schemas
        var declaredProps = Set<String>()
        if let props = schema["properties"] as? [String: Any] {
            declaredProps.formUnion(props.keys)
        }
        if let allOf = schema["allOf"] as? [[String: Any]] {
            for sub in allOf {
                if let props = sub["properties"] as? [String: Any] {
                    declaredProps.formUnion(props.keys)
                }
                // Recurse one level into nested allOf
                if let nestedAllOf = sub["allOf"] as? [[String: Any]] {
                    for nested in nestedAllOf {
                        if let props = nested["properties"] as? [String: Any] {
                            declaredProps.formUnion(props.keys)
                        }
                    }
                }
            }
        }

        if !declaredProps.isEmpty {
            for key in dataObj.keys where !declaredProps.contains(key) {
                warnings.append(ValidationError(
                    instancePath: "/\(key)",
                    keyword: "additionalProperties",
                    message: "additional property '\(key)' is not defined in the schema"
                ))
            }
        }

        return warnings
    }
}
