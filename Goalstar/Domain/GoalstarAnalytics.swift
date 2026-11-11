import Foundation

/// Debug-visible analytics stubs for Goalstar 1.1. No network upload.
enum GoalstarAnalytics {
    static func track(_ name: String, _ properties: [String: String] = [:]) {
        #if DEBUG
        let payload = properties
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: " ")
        print("[GoalstarAnalytics] \(name) \(payload)")
        #endif
    }
}
