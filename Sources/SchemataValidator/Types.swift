import Foundation

public struct ValidationError {
    public let instancePath: String
    public let keyword: String
    public let message: String
    public let schemaPath: String

    public init(instancePath: String = "", keyword: String = "", message: String = "", schemaPath: String = "") {
        self.instancePath = instancePath
        self.keyword = keyword
        self.message = message
        self.schemaPath = schemaPath
    }
}

public struct ValidationResult {
    public let valid: Bool
    public let errors: [ValidationError]
    public let warnings: [ValidationError]

    public init(valid: Bool, errors: [ValidationError] = [], warnings: [ValidationError] = []) {
        self.valid = valid
        self.errors = errors
        self.warnings = warnings
    }
}

public enum Subject {
    case relay
    case client

    public var description: String {
        switch self {
        case .relay: return "relay"
        case .client: return "client"
        }
    }
}
