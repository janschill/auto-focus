# Auto-Focus Test Suite

This directory contains the unit tests for the Auto-Focus macOS application.

## Test Structure

```
auto-focusTests/
├── TestHelpers/           # Test utilities and helpers
│   └── TestHelpers.swift  # Common test utilities, builders, and assertions
├── FocusManagerTests.swift      # Tests for FocusManager core logic
├── ConfigurationViewModelTests.swift  # Tests for ConfigurationViewModel
├── InsightsViewModelTests.swift        # Tests for InsightsViewModel
├── MenuBarViewModelTests.swift        # Tests for MenuBarViewModel
├── SessionEditingTests.swift         # Tests for session editing functionality
└── TimerDisplayModeTests.swift        # Tests for timer display modes
```

## Running Tests

### From Command Line

```bash
# Run all tests
make test

# Run tests with code coverage
make test-coverage

# Run tests directly with xcodebuild
xcodebuild test \
  -project auto-focus.xcodeproj \
  -scheme auto-focus \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=NO
```

### From Xcode

1. Open `auto-focus.xcodeproj` in Xcode
2. Press `Cmd+U` to run all tests
3. Or use `Cmd+Option+U` to run tests with coverage

## Test Helpers

### MockFactory

Creates mock dependencies for testing:

```swift
let mocks = MockFactory.createMockDependencies()
let focusManager = MockFactory.createFocusManager(
    persistence: mocks.persistence,
    sessionManager: mocks.sessionManager,
    // ...
)
```

### TestDataBuilder

Creates test data:

```swift
// Create a single session
let session = TestDataBuilder.createFocusSession(
    startTime: Date(),
    duration: 3600
)

// Create multiple sessions for a day
let sessions = TestDataBuilder.createSessionsForDay(
    count: 5,
    duration: 3600
)

// Create test app info
let app = TestDataBuilder.createAppInfo(
    name: "Xcode",
    bundleIdentifier: "com.apple.dt.Xcode"
)
```

### Custom Assertions

```swift
// Assert dates are equal within tolerance
XCTAssertEqualDates(date1, date2, tolerance: 1.0)

// Assert time interval is in range
XCTAssertTimeInterval(interval, isBetween: 0, and: 100)
```

## Mock Objects

All mocks are located in `auto-focus/Mocks/MockManagers.swift`:

- **MockSessionManager**: Mocks session management
- **MockAppMonitor**: Mocks app monitoring
- **MockBufferManager**: Mocks buffer period management
- **MockFocusModeManager**: Mocks focus mode control
- **MockPersistenceManager**: Mocks persistence layer

### Mock Configuration

Mocks support failure scenarios for testing error handling:

```swift
mockSessionManager.shouldFailStartSession = true
mockPersistence.shouldFailSave = true
mockFocusModeManager.shouldFailFocusMode = true
```

## Best Practices

1. **Use MockFactory**: Always use `MockFactory` to create test dependencies
2. **Reset Mocks**: Call `reset()` on mocks in `tearDown()` to ensure clean state
3. **Use TestDataBuilder**: Use builders instead of manually creating test data
4. **Test One Thing**: Each test should verify a single behavior
5. **Descriptive Names**: Test names should clearly describe what they test
6. **Arrange-Act-Assert**: Follow AAA pattern in tests

## CI/CD

Tests run automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches

See `.github/workflows/ci.yml` for CI configuration.

## Code Coverage

To generate code coverage reports:

```bash
make test-coverage
```

Coverage reports are generated in Xcode's DerivedData directory and can be viewed in Xcode's Report Navigator.

