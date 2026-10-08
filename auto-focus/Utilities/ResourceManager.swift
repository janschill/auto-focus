//
//  ResourceManager.swift
//  auto-focus
//
//  Created by Jan Schill on 09/02/2025.
//

import AppKit

struct ResourceManager {
    /// Copies the bundled Do Not Disturb shortcut to a temporary location and opens it,
    /// prompting the Shortcuts app to install it.
    static func installShortcut() {
        guard let shortcutUrl = copyShortcutToTemporary() else {
            AppLogger.ui.error("Could not prepare shortcut for installation")
            return
        }

        NSWorkspace.shared.open(shortcutUrl)
    }

    private static func getShortcutURL() -> URL? {
        return Bundle.main.url(forResource: "Toggle Do Not Disturb",
                             withExtension: "shortcut")
    }

    private static func copyShortcutToTemporary() -> URL? {
        guard let shortcutUrl = getShortcutURL() else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let tempUrl = tempDir.appendingPathComponent("Toggle Do Not Disturb.shortcut")

        try? FileManager.default.removeItem(at: tempUrl) // Remove if exists

        do {
            try FileManager.default.copyItem(at: shortcutUrl, to: tempUrl)
            return tempUrl
        } catch {
            AppLogger.general.error("Error copying shortcut", error: error)
            return nil
        }
    }
}
