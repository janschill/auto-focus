import Foundation
import os

enum AppLog {
    static let subsystem = "auto-focus.AutoFocus2"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let focus = Logger(subsystem: subsystem, category: "focus")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let license = Logger(subsystem: subsystem, category: "license")

    /// Never log full URLs/titles/license keys. Prefer domain-only and redacted details.
    static func redact(_ value: String) -> String {
        if value.count <= 4 { return "****" }
        return "\(value.prefix(2))…\(value.suffix(2))"
    }
}


