import SwiftUI

class UserDefaultsManager: PersistenceManaging {
    enum Keys {
        static let focusApps = "focusApps"
        static let focusSessions = "focusSessions"
        static let focusThreshold = "focusThreshold"
        static let focusLossBuffer = "focusLossBuffer"
        static let isPaused = "isPaused"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    func save<T: Codable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // Convenience methods for primitive types
    func setBool(_ value: Bool, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    func getBool(forKey key: String) -> Bool {
        return UserDefaults.standard.bool(forKey: key)
    }

    func setDouble(_ value: Double, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    func getDouble(forKey key: String) -> Double {
        return UserDefaults.standard.double(forKey: key)
    }
}
