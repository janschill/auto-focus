import Foundation

final class ShortcutsCLI {
    func isShortcutInstalled(named name: String) -> Bool? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["list"]

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        if process.terminationStatus != 0 {
            return nil
        }

        let data = out.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        return str.split(separator: "\n").map(String.init).contains(where: { $0 == name })
    }
}


