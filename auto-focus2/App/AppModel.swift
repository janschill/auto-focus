import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var compositionRoot: CompositionRoot?
    @Published private(set) var initError: String?

    @Published var showsSettings: Bool = false
    @Published var showsOnboarding: Bool = false

    func start() {
        do {
            let appSupport = try Self.ensureAppSupportDirectory()
            let root = try CompositionRoot(appSupportDirectory: appSupport)
            self.compositionRoot = root
            self.showsOnboarding = true
        } catch {
            self.initError = String(describing: error)
        }
    }

    private static func ensureAppSupportDirectory() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("AutoFocus2", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}


