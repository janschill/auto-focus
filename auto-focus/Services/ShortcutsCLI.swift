import Foundation

/// Runs user shortcuts and lists installed ones.
protocol ShortcutRunning {
    /// Names of all shortcuts installed in the Shortcuts app.
    func listShortcuts() throws -> [String]
    /// Runs a shortcut with a text input and returns its text output, trimmed.
    func runShortcut(named name: String, input: String) throws -> String
}

enum ShortcutsCLIError: LocalizedError {
    case timedOut
    case failed(status: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .timedOut:
            return "shortcuts command timed out"
        case let .failed(status, message):
            return "shortcuts exited with status \(status): \(message)"
        }
    }
}

/// `ShortcutRunning` backed by the `/usr/bin/shortcuts` command-line tool.
///
/// Calling the tool directly needs no Apple Events permission, unlike scripting the Shortcuts app.
struct ShortcutsCLI: ShortcutRunning {
    private let executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
    private let timeout: DispatchTimeInterval = .seconds(15)

    func listShortcuts() throws -> [String] {
        try withScratchDirectory { directory in
            try execute(["list"], in: directory)
        }
        .split(whereSeparator: \.isNewline)
        .map(String.init)
    }

    func runShortcut(named name: String, input: String) throws -> String {
        try withScratchDirectory { directory in
            let inputURL = directory.appendingPathComponent("input.txt")
            let outputURL = directory.appendingPathComponent("output.txt")
            try input.write(to: inputURL, atomically: true, encoding: .utf8)

            _ = try execute(["run", name, "--input-path", inputURL.path, "--output-path", outputURL.path], in: directory)

            let output = (try? String(contentsOf: outputURL, encoding: .utf8)) ?? ""
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func withScratchDirectory<Result>(_ body: (URL) throws -> Result) throws -> Result {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("auto-focus-shortcuts-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        return try body(directory)
    }

    /// Runs the tool and returns its stdout. Output goes to files rather than pipes, so large output
    /// cannot block the process before it exits.
    private func execute(_ arguments: [String], in directory: URL) throws -> String {
        let stdoutURL = directory.appendingPathComponent("stdout.txt")
        let stderrURL = directory.appendingPathComponent("stderr.txt")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdout.close()
            try? stderr.close()
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr

        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        try process.run()

        if finished.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            throw ShortcutsCLIError.timedOut
        }

        guard process.terminationStatus == 0 else {
            let message = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
            throw ShortcutsCLIError.failed(
                status: process.terminationStatus,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return (try? String(contentsOf: stdoutURL, encoding: .utf8)) ?? ""
    }
}
