# SchemataValidator

[![Test](https://github.com/nostrability/schemata-validator-swift/actions/workflows/test.yml/badge.svg)](https://github.com/nostrability/schemata-validator-swift/actions/workflows/test.yml)

Swift validator for [Nostr](https://nostr.com/) protocol JSON schemas. Built on [`SchemataSwift`](https://github.com/nostrability/schemata-swift).

## When to use this

JSON Schema validation is [not suited for runtime hot paths](https://github.com/nostrability/schemata#what-is-it-not-good-for). Use this in **CI and integration tests**.

## Usage

```swift
import SchemataValidator

let event: [String: Any] = ["id": "aa...", "pubkey": "bb...", "created_at": 1700000000, "kind": 1, "tags": [], "content": "hello", "sig": "cc..."]
let result = SchemataValidator.validateNote(event)
assert(result.valid)
```

## License

GPL-3.0-or-later
