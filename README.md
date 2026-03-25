# SchemataValidator (Swift)

[![Test](https://github.com/nostrability/schemata-validator-swift/actions/workflows/test.yml/badge.svg)](https://github.com/nostrability/schemata-validator-swift/actions/workflows/test.yml)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange?style=flat-square)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Linux-blue?style=flat-square)](Package.swift)
[![License](https://img.shields.io/badge/license-GPL--3.0--or--later-blue?style=flat-square)](LICENSE)

Swift validator for [Nostr](https://nostr.com/) protocol JSON schemas. Built on [`kylef/JSONSchema.swift`](https://github.com/kylef/JSONSchema.swift) (Draft 7) with 188 embedded schemas.

## Overview

`SchemataValidator` wraps canonical Nostr JSON Schema definitions with JSONSchema.swift validation, exposing ready-to-use static methods for common Nostr data structures. It validates Nostr events by kind, NIP-11 relay information documents, and relay/client protocol messages.

Validation results include both hard errors (schema violations) and soft warnings (additional properties not defined in the schema). All 188 schemas are embedded as string literals — no resource bundles or network fetches needed.

## When to use this

JSON Schema validation is [not suited for runtime hot paths](https://github.com/nostrability/schemata#what-is-it-not-good-for). Use this in:

- **CI pipelines** catching schema drift during builds
- **Integration tests** for clients and relays
- **XCTest suites** verifying event construction correctness

## Installation

**Swift Package Manager:**

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/nostrability/schemata-validator-swift.git", branch: "main"),
],
targets: [
    .testTarget(
        name: "MyAppTests",
        dependencies: [
            .product(name: "SchemataValidator", package: "schemata-validator-swift"),
        ]
    ),
]
```

## Quick Start

```swift
import SchemataValidator

let event: [String: Any] = [
    "id": String(repeating: "a", count: 64),
    "pubkey": String(repeating: "b", count: 64),
    "created_at": 1700000000,
    "kind": 1,
    "tags": [],
    "content": "hello world",
    "sig": String(repeating: "c", count: 128),
]

let result = SchemataValidator.validateNote(event)
assert(result.valid)
// result.errors is empty, result.warnings may flag additional properties
```

## API

All methods are static on the `SchemataValidator` struct.

### `SchemataValidator.validateNote(_:)`

```swift
public static func validateNote(_ event: [String: Any]) -> ValidationResult
```

Validates a Nostr event against the schema for its `kind`. The schema is looked up using the key `kind{N}Schema`. Returns a warning (not an error) if no schema exists for the given kind.

| Parameter | Type | Description |
|-----------|------|-------------|
| `event` | `[String: Any]` | A Nostr event dictionary |

### `SchemataValidator.validateNip11(_:)`

```swift
public static func validateNip11(_ doc: [String: Any]) -> ValidationResult
```

Validates a NIP-11 relay information document — the metadata object a relay serves at its HTTP endpoint — against the `nip11Schema`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `doc` | `[String: Any]` | A NIP-11 relay info document |

### `SchemataValidator.validateMessage(_:subject:slug:)`

```swift
public static func validateMessage(_ msg: Any, subject: Subject, slug: String) -> ValidationResult
```

Validates a Nostr protocol message against the schema for the given subject and message type. The schema key is constructed as `{subject}{Slug}Schema` (e.g., `relayNoticeSchema` for `subject=.relay`, `slug="notice"`).

| Parameter | Type | Description |
|-----------|------|-------------|
| `msg` | `Any` | The protocol message (array or dictionary) |
| `subject` | `Subject` | Message origin: `.relay` or `.client` |
| `slug` | `String` | Message type name (e.g., `"notice"`, `"event"`, `"ok"`) |

### `SchemataValidator.getSchema(_:)`

```swift
public static func getSchema(_ key: String) -> [String: Any]?
```

Looks up a schema by key from the embedded registry. Returns `nil` if the key doesn't exist.

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `String` | Schema registry key (e.g., `"kind1Schema"`, `"pTagSchema"`) |

### `ValidationResult`

```swift
public struct ValidationResult {
    public let valid: Bool
    public let errors: [ValidationError]
    public let warnings: [ValidationError]
}
```

- `valid` — `true` if the data passes all schema constraints
- `errors` — schema violations; empty when `valid` is `true`
- `warnings` — additional property alerts; populated even when `valid` is `true`

### `ValidationError`

```swift
public struct ValidationError {
    public let instancePath: String
    public let keyword: String
    public let message: String
    public let schemaPath: String
}
```

### `Subject`

```swift
public enum Subject {
    case relay
    case client
}
```

## Usage Examples

**Event validation:**

```swift
let event: [String: Any] = [
    "id": String(repeating: "a", count: 64),
    "pubkey": String(repeating: "b", count: 64),
    "created_at": 1700000000,
    "kind": 1,
    "tags": [],
    "content": "hello world",
    "sig": String(repeating: "c", count: 128),
]
let result = SchemataValidator.validateNote(event)
assert(result.valid)
```

**NIP-11 validation:**

```swift
let doc: [String: Any] = [
    "name": "My Relay",
    "supported_nips": [1, 11],
]
let result = SchemataValidator.validateNip11(doc)
assert(result.valid)
```

**Protocol message validation:**

```swift
let msg: [Any] = ["EVENT", [
    "id": String(repeating: "a", count: 64),
    "pubkey": String(repeating: "b", count: 64),
    "created_at": 1700000000,
    "kind": 1,
    "tags": [],
    "content": "hello",
    "sig": String(repeating: "c", count: 128),
]]
let result = SchemataValidator.validateMessage(msg, subject: .client, slug: "event")
```

**Direct schema lookup:**

```swift
if let schema = SchemataValidator.getSchema("kind1Schema") {
    print("Found schema with keys: \(schema.keys)")
}
```

## Known Limitations

- **Partial kind coverage:** Only event kinds with a corresponding schema in `@nostrability/schemata` can be validated. `validateNote` returns a warning (not an error) when no schema exists for the given kind.
- **No recursive content validation:** The `content` field of events containing stringified JSON (e.g., kind 0 metadata) is not recursively validated.
- **Alpha accuracy:** False positives and negatives are possible. The underlying schemas are in active development.

## Related Packages

- [`@nostrability/schemata`](https://github.com/nostrability/schemata) — canonical language-agnostic schema definitions
- [`@nostrwatch/schemata-js-ajv`](https://github.com/sandwichfarm/nostr-watch/tree/next/libraries/schemata-js-ajv) — JavaScript/TypeScript validator implementation
- [`schemata-validator-rs`](https://github.com/nostrability/schemata-validator-rs) — Rust validator implementation

## License

[GPL-3.0-or-later](LICENSE)
