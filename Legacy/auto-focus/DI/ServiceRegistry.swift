import Foundation

// MARK: - Dependency Container Protocol
protocol DependencyContainer {
    func resolve<T>(_ type: T.Type) -> T
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
}

// MARK: - Service Registry
class ServiceRegistry: DependencyContainer {
    static let shared = ServiceRegistry()

    private var factories: [String: () -> Any] = [:]
    private var singletons: [String: Any] = [:]

    private init() {
        registerDefaults()
    }

    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
    }

    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = {
            if let existing = self.singletons[key] as? T {
                return existing
            }
            let instance = factory()
            self.singletons[key] = instance
            return instance
        }
    }

    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        guard let factory = factories[key] else {
            fatalError("No factory registered for type \(type)")
        }

        guard let instance = factory() as? T else {
            fatalError("Factory for \(type) returned wrong type")
        }

        return instance
    }

    private func registerDefaults() {
        // Register default implementations
        registerSingleton(UserDefaultsManager.self) {
            UserDefaultsManager()
        }

        register(SessionManager.self) {
            SessionManager(userDefaultsManager: self.resolve(UserDefaultsManager.self))
        }

        register(AppMonitor.self) {
            AppMonitor(checkInterval: AppConfiguration.checkInterval)
        }

        register(BufferManager.self) {
            BufferManager()
        }

        register(FocusModeManager.self) {
            FocusModeManager()
        }

        register(FocusManager.self) {
            FocusManager(
                userDefaultsManager: self.resolve(UserDefaultsManager.self),
                sessionManager: self.resolve(SessionManager.self),
                appMonitor: self.resolve(AppMonitor.self),
                bufferManager: self.resolve(BufferManager.self),
                focusModeController: self.resolve(FocusModeManager.self)
            )
        }
    }

    #if DEBUG
    func registerMocks() {
        // Override with mock implementations for testing
        register(MockSessionManager.self) {
            MockSessionManager()
        }

        register(MockAppMonitor.self) {
            MockAppMonitor()
        }

        register(MockBufferManager.self) {
            MockBufferManager()
        }

        register(MockFocusModeManager.self) {
            MockFocusModeManager()
        }

        register(MockPersistenceManager.self) {
            MockPersistenceManager()
        }

        // Register test FocusManager with mocks
        register(FocusManager.self) {
            FocusManager(
                userDefaultsManager: self.resolve(MockPersistenceManager.self),
                sessionManager: self.resolve(MockSessionManager.self),
                appMonitor: self.resolve(MockAppMonitor.self),
                bufferManager: self.resolve(MockBufferManager.self),
                focusModeController: self.resolve(MockFocusModeManager.self)
            )
        }
    }
    #endif
}

// MARK: - Convenience Extensions
extension ServiceRegistry {
    func focusManager() -> FocusManager {
        return resolve(FocusManager.self)
    }

    func sessionManager() -> any SessionManaging {
        return resolve(SessionManager.self)
    }

    func appMonitor() -> any AppMonitoring {
        return resolve(AppMonitor.self)
    }

    func bufferManager() -> any BufferManaging {
        return resolve(BufferManager.self)
    }

    func focusModeController() -> any FocusModeControlling {
        return resolve(FocusModeManager.self)
    }
}
