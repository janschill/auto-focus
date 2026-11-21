import Foundation

/// Builds the prompt Auto-Focus+ users paste into Claude to analyze their focus sessions.
///
/// The prompt body lives in the bundled `ClaudeSessionAnalysis.md`. The app prepends the exact
/// database path so Claude doesn't have to search for it.
enum ClaudeAnalysisPrompt {
    static let resourceName = "ClaudeSessionAnalysis"

    /// Loads the bundled template and fills in this Mac's database path.
    /// Returns nil if the template is missing from the bundle.
    static func load(bundle: Bundle = .main, databaseURL: URL = DatabaseManager.databaseURL) -> String? {
        guard let templateURL = bundle.url(forResource: resourceName, withExtension: "md") else {
            AppLogger.ui.error("Claude analysis prompt template missing from bundle")
            return nil
        }
        do {
            let template = try String(contentsOf: templateURL, encoding: .utf8)
            return make(template: template, databasePath: databaseURL.path)
        } catch {
            AppLogger.ui.error("Failed to read Claude analysis prompt template", error: error)
            return nil
        }
    }

    /// Prepends the known database path to the prompt template.
    static func make(template: String, databasePath: String) -> String {
        """
        Auto-Focus filled this in for you: my database is at `\(databasePath)`. Use that path in \
        Step 1 instead of searching (quote it, it contains spaces).

        \(template)
        """
    }
}
