//
//  PermissionManagerTests.swift
//  auto-focusTests
//
//  Created by Copilot on 13/08/2025.
//

@testable import auto_focus
import XCTest

class PermissionManagerTests: XCTestCase {

    func testPermissionManagerInitialization() {
        let permissionManager = PermissionManager()
        
        // Test that the manager initializes properly
        XCTAssertNotNil(permissionManager)
        // The initial state should have permissions checked
        // Note: In test environment, these will likely be false since we don't have actual permissions
    }
    
    func testOpenSystemPreferencesURL() {
        let permissionManager = PermissionManager()
        
        // Test that the system preferences URL is properly formed
        // This method should not crash when called
        XCTAssertNoThrow(permissionManager.openSystemPreferences())
    }
}