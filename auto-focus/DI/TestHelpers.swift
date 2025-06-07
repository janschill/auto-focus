import Foundation

#if DEBUG

// MARK: - Test Helpers
class DependencyInjectionTestHelper {
    
    /// Sets up the service registry with mock implementations for testing
    static func setupMockEnvironment() {
        ServiceRegistry.shared.registerMocks()
    }
    
    /// Creates a FocusManager with mock dependencies for testing
    static func createTestFocusManager() -> FocusManager {
        let mockPersistence = MockPersistenceManager()
        let mockSession = MockSessionManager()
        let mockAppMonitor = MockAppMonitor()
        let mockBuffer = MockBufferManager()
        let mockFocusMode = MockFocusModeController()
        
        return FocusManager(
            userDefaultsManager: mockPersistence,
            sessionManager: mockSession,
            appMonitor: mockAppMonitor,
            bufferManager: mockBuffer,
            focusModeController: mockFocusMode
        )
    }
    
    /// Creates individual mock services for granular testing
    static func createMockServices() -> (
        sessionManager: MockSessionManager,
        appMonitor: MockAppMonitor,
        bufferManager: MockBufferManager,
        focusModeController: MockFocusModeController,
        persistenceManager: MockPersistenceManager
    ) {
        return (
            sessionManager: MockSessionManager(),
            appMonitor: MockAppMonitor(),
            bufferManager: MockBufferManager(),
            focusModeController: MockFocusModeController(),
            persistenceManager: MockPersistenceManager()
        )
    }
}

// MARK: - Example Usage in Tests
/*
To use these test helpers in your test target:

1. Create a proper test target in Xcode
2. Add these files to your test target:
   - MockManagers.swift
   - TestHelpers.swift
   - FocusManagerTests.swift

3. Example test structure:

class ExampleTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        DependencyInjectionTestHelper.setupMockEnvironment()
    }
    
    func testUsingServiceRegistry() {
        let focusManager = ServiceRegistry.shared.focusManager()
        // Test with mocked dependencies
    }
    
    func testUsingDirectInjection() {
        let focusManager = DependencyInjectionTestHelper.createTestFocusManager()
        // Test with specific mock setup
    }
    
    func testIndividualServices() {
        let mocks = DependencyInjectionTestHelper.createMockServices()
        
        mocks.sessionManager.startSession()
        assert(mocks.sessionManager.isSessionActive == true)
        
        mocks.appMonitor.simulateFocusAppActive()
        // More tests...
    }
}
*/

#endif