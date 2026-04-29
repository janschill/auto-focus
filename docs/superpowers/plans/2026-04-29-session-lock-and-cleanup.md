# Session lock-end & cleanup implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** End focus sessions when the Mac locks/sleeps and add a bulk-delete-by-filter UX for cleaning up short sessions.

**Architecture:** Move screen-lock/sleep observation from `AppMonitor` into `FocusManager` (which owns session lifecycle) and route it through the same `endSession`/`cancelCurrentSession` decision used by the buffer-timeout path. Add a single bulk-delete API to `SessionManager` (one GRDB transaction) exposed through `FocusManager`, and surface it via a destructive button on `SessionListView`'s filter row plus a "Review & clean up" hint on the Data tab.

**Tech Stack:** Swift 5, SwiftUI, GRDB, AppKit (NSWorkspace, DistributedNotificationCenter), XCTest.

**Spec:** `docs/superpowers/specs/2026-04-29-session-lock-and-cleanup-design.md`

---

## File map

**Modify:**

- `auto-focus/Database/Repositories/SessionRepository.swift` — add `delete(_ sessions:)` batch method.
- `auto-focus/Services/SessionManager.swift` — add `deleteSessions(_:)`.
- `auto-focus/Protocols/ManagerProtocols.swift` — add `deleteSessions(_:)` to `SessionManaging`.
- `auto-focus/Mocks/MockManagers.swift` — add `deleteSessions(_:)` to `MockSessionManager`.
- `auto-focus/Services/FocusManager.swift` — add `deleteSessions(_:)` pass-through; add screen-lock observer + `handleScreenInactive()`.
- `auto-focus/Services/AppMonitor.swift` — remove screen-lock handling (moved to FocusManager).
- `auto-focus/Views/SessionListView.swift` — accept `initialFilter` / `initialSort`; add bulk-delete button.
- `auto-focus/Views/DataView.swift` — add cleanup hint row in `DataSessionManagementView` and pass initial filter/sort to `SessionListView`.

**Add:**

- `auto-focusTests/SessionDeletionTests.swift` — bulk delete tests.
- `auto-focusTests/ScreenLockSessionEndTests.swift` — tests for `handleScreenInactive()`.

---

## Task 1: Add batch delete to `SessionRepository`

**Files:**
- Modify: `auto-focus/Database/Repositories/SessionRepository.swift`

- [ ] **Step 1: Add `delete(_ sessions:)` method**

Add immediately after the existing single-session `delete(_:)` (around line 30):

```swift
func delete(_ sessions: [FocusSession]) throws {
    try dbQueue.write { db in
        let ids = sessions.map { $0.id.uuidString }
        _ = try FocusSession
            .filter(ids.contains(Column("id")))
            .deleteAll(db)
    }
}
```

This deletes all matching sessions in a single GRDB write transaction.

- [ ] **Step 2: Build to confirm the code compiles**

Run: `xcodebuild build -project auto-focus.xcodeproj -scheme auto-focus -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add auto-focus/Database/Repositories/SessionRepository.swift
git commit -m "Add batch delete to SessionRepository"
```

---

## Task 2: Add `deleteSessions(_:)` to SessionManaging protocol and SessionManager

**Files:**
- Modify: `auto-focus/Protocols/ManagerProtocols.swift`
- Modify: `auto-focus/Services/SessionManager.swift`
- Modify: `auto-focus/Mocks/MockManagers.swift`
- Add: `auto-focusTests/SessionDeletionTests.swift`

- [ ] **Step 1: Write the failing test**

Create `auto-focusTests/SessionDeletionTests.swift`:

```swift
@testable import auto_focus
import GRDB
import XCTest

#if DEBUG

final class SessionDeletionTests: XCTestCase {
    var sessionRepo: SessionRepository!
    var sessionManager: SessionManager!

    override func setUp() {
        super.setUp()
        let testDB = MockFactory.createTestDB()
        sessionRepo = SessionRepository(dbQueue: testDB)
        sessionManager = SessionManager(sessionRepo: sessionRepo)
    }

    func testDeleteSessionsRemovesMatchingSessions() throws {
        let now = Date()
        let s1 = FocusSession(startTime: now.addingTimeInterval(-300), endTime: now.addingTimeInterval(-290))
        let s2 = FocusSession(startTime: now.addingTimeInterval(-200), endTime: now.addingTimeInterval(-100))
        let s3 = FocusSession(startTime: now.addingTimeInterval(-90), endTime: now)

        try sessionRepo.insert(s1)
        try sessionRepo.insert(s2)
        try sessionRepo.insert(s3)

        sessionManager.deleteSessions([s1, s3])

        // Allow the observation publisher to deliver before reading
        let exp = expectation(description: "observation delivers")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        let remaining = try sessionRepo.fetchAll()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, s2.id)
    }

    func testDeleteSessionsWithEmptyArrayIsNoOp() throws {
        let now = Date()
        let s1 = FocusSession(startTime: now.addingTimeInterval(-100), endTime: now)
        try sessionRepo.insert(s1)

        sessionManager.deleteSessions([])

        let remaining = try sessionRepo.fetchAll()
        XCTAssertEqual(remaining.count, 1)
    }
}

#endif
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project auto-focus.xcodeproj -scheme auto-focus -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO -only-testing:auto-focusTests/SessionDeletionTests`
Expected: Compilation failure ("Value of type 'SessionManager' has no member 'deleteSessions'") OR test failure.

- [ ] **Step 3: Add `deleteSessions(_:)` to the SessionManaging protocol**

In `auto-focus/Protocols/ManagerProtocols.swift`, after the existing `deleteSession(_:)` declaration:

```swift
func deleteSession(_ session: FocusSession)
func deleteSessions(_ sessions: [FocusSession])
```

- [ ] **Step 4: Implement `deleteSessions(_:)` on SessionManager**

In `auto-focus/Services/SessionManager.swift`, add immediately after the existing `deleteSession(_:)` method (around line 169):

```swift
func deleteSessions(_ sessions: [FocusSession]) {
    guard !sessions.isEmpty else { return }

    do {
        try sessionRepo.delete(sessions)
        AppLogger.session.info("Sessions deleted in batch", metadata: [
            "count": String(sessions.count)
        ])
    } catch {
        AppLogger.session.error("Failed to batch-delete sessions", error: error)
    }
}
```

- [ ] **Step 5: Implement `deleteSessions(_:)` on MockSessionManager**

In `auto-focus/Mocks/MockManagers.swift`, immediately after the existing `deleteSession(_:)` (around line 82):

```swift
func deleteSessions(_ sessions: [FocusSession]) {
    let idsToDelete = Set(sessions.map { $0.id })
    focusSessions.removeAll { idsToDelete.contains($0.id) }
}
```

- [ ] **Step 6: Run the tests**

Run: `xcodebuild test -project auto-focus.xcodeproj -scheme auto-focus -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO -only-testing:auto-focusTests/SessionDeletionTests`
Expected: PASS for both tests.

- [ ] **Step 7: Commit**

```bash
git add auto-focus/Protocols/ManagerProtocols.swift auto-focus/Services/SessionManager.swift auto-focus/Mocks/MockManagers.swift auto-focusTests/SessionDeletionTests.swift
git commit -m "Add bulk session deletion to SessionManager"
```

---

## Task 3: Add `deleteSessions(_:)` pass-through on FocusManager

**Files:**
- Modify: `auto-focus/Services/FocusManager.swift`

- [ ] **Step 1: Add the method**

In `auto-focus/Services/FocusManager.swift`, immediately after the existing `deleteSession(_:)` (around line 124):

```swift
func deleteSession(_ session: FocusSession) {
    sessionManager.deleteSession(session)
}

func deleteSessions(_ sessions: [FocusSession]) {
    sessionManager.deleteSessions(sessions)
}
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `xcodebuild build -project auto-focus.xcodeproj -scheme auto-focus -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add auto-focus/Services/FocusManager.swift
git commit -m "Expose bulk session deletion via FocusManager"
```

---

## Task 4: Add bulk-delete UI to SessionListView

**Files:**
- Modify: `auto-focus/Views/SessionListView.swift`

- [ ] **Step 1: Add initial filter/sort init parameters**

Replace the top of `struct SessionListView: View { ... }` (currently lines 10-16) with:

```swift
struct SessionListView: View {
    @EnvironmentObject var focusManager: FocusManager
    @State private var showingDeleteConfirmation = false
    @State private var showingBulkDeleteConfirmation = false
    @State private var sessionToDelete: FocusSession?
    @State private var sortOrder: SessionSortOrder
    @State private var filterDuration: SessionDurationFilter

    init(initialFilter: SessionDurationFilter = .all, initialSort: SessionSortOrder = .newest) {
        _filterDuration = State(initialValue: initialFilter)
        _sortOrder = State(initialValue: initialSort)
    }
```

This preserves the default zero-arg initializer used by the existing call site.

- [ ] **Step 2: Add the bulk-delete button to the controls header**

Replace the `// Filters and Sort Controls` HStack (currently lines 83-103) with:

```swift
            // Filters and Sort Controls
            HStack(spacing: 12) {
                // Duration Filter
                Picker("Filter", selection: $filterDuration) {
                    ForEach(SessionDurationFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 150)

                // Sort Order
                Picker("Sort", selection: $sortOrder) {
                    ForEach(SessionSortOrder.allCases, id: \.self) { order in
                        Text(order.displayName).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 150)

                Spacer()

                if filterDuration != .all && !filteredAndSortedSessions.isEmpty {
                    Button(role: .destructive) {
                        showingBulkDeleteConfirmation = true
                    } label: {
                        Label("Delete \(filteredAndSortedSessions.count) sessions", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .help("Delete every session matching the current filter")
                }
            }
```

- [ ] **Step 3: Add the bulk-delete confirmation alert**

Replace the existing `.alert(isPresented: $showingDeleteConfirmation) { deleteConfirmationAlert }` modifier (currently around lines 61-63) with two separate alert modifiers:

```swift
        .alert(isPresented: $showingDeleteConfirmation) {
            deleteConfirmationAlert
        }
        .alert("Delete \(filteredAndSortedSessions.count) sessions?", isPresented: $showingBulkDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                let toDelete = filteredAndSortedSessions
                focusManager.deleteSessions(toDelete)
            }
        } message: {
            Text("This will delete every session matching '\(filterDuration.displayName)'. This action cannot be undone.")
        }
```

- [ ] **Step 4: Build to confirm**

Run: `xcodebuild build -project auto-focus.xcodeproj -scheme auto-focus -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Manual smoke test**

1. Run the app (`make build` or via Xcode).
2. Open Data tab → Manage Sessions.
3. With several sessions present, change Filter to "Very Short (<1m)" — the Delete N sessions button appears.
4. Click → confirmation alert appears with the correct count and filter name.
5. Confirm → sessions disappear, count goes to 0, button hides, empty state appears.
6. Change Filter back to "All Sessions" — button is hidden.

If sessions aren't available, add some via the Debug tab (`canShowDebugOptions == true` in DEBUG builds) or seed via the in-tree `addSampleSessions` debug API.

- [ ] **Step 6: Commit**

```bash
git add auto-focus/Views/SessionListView.swift
git commit -m "Add bulk delete by filter to session list"
```

---

## Task 5: Add cleanup hint to DataView

**Files:**
- Modify: `auto-focus/Views/DataView.swift`

- [ ] **Step 1: Track an initial filter/sort for the sheet and add the hint row**

In `DataSessionManagementView` (around lines 149-230), add new state for the initial sheet filter, change the sheet construction to pass it, and add the hint row before the "Manage Sessions" button.

Replace `struct DataSessionManagementView: View { ... }` body with:

```swift
struct DataSessionManagementView: View {
    @EnvironmentObject var focusManager: FocusManager
    @State private var showingSessionList = false
    @State private var sheetInitialFilter: SessionDurationFilter = .all
    @State private var sheetInitialSort: SessionSortOrder = .newest

    private var veryShortSessionCount: Int {
        focusManager.focusSessions.filter { $0.duration < 60 }.count
    }

    var body: some View {
        GroupBox(label: Text("Session Management").font(.headline)) {
            VStack(spacing: 16) {
                Text("View and manage your focus sessions. Remove unwanted sessions if needed.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Sessions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(focusManager.focusSessions.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    if focusManager.focusSessions.count > 0 {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Shortest Session")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let shortest = focusManager.focusSessions.min(by: { $0.duration < $1.duration }) {
                                Text(TimeFormatter.duration(Int(shortest.duration / 60)))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(shortest.duration < 60 ? .orange : .primary)
                            }
                        }

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Longest Session")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let longest = focusManager.focusSessions.max(by: { $0.duration < $1.duration }) {
                                Text(TimeFormatter.duration(Int(longest.duration / 60)))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                if veryShortSessionCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(veryShortSessionCount) session\(veryShortSessionCount == 1 ? "" : "s") under 1 minute")
                            .font(.callout)
                        Spacer()
                        Button("Review & clean up") {
                            sheetInitialFilter = .veryShort
                            sheetInitialSort = .oldest
                            showingSessionList = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                    )
                }

                HStack {
                    Spacer()

                    Button("Manage Sessions") {
                        sheetInitialFilter = .all
                        sheetInitialSort = .newest
                        showingSessionList = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(focusManager.focusSessions.isEmpty)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showingSessionList) {
            NavigationView {
                SessionListView(initialFilter: sheetInitialFilter, initialSort: sheetInitialSort)
                    .navigationTitle("Focus Sessions")
                    .toolbar {
                        ToolbarItem(placement: .automatic) {
                            Button("Done") {
                                showingSessionList = false
                            }
                        }
                    }
            }
            .frame(minWidth: 700, minHeight: 600)
        }
    }
}
```

- [ ] **Step 2: Build to confirm**

Run: `xcodebuild build -project auto-focus.xcodeproj -scheme auto-focus -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Manual smoke test**

1. Run the app.
2. With at least one session under 1 minute, the orange hint row appears with the correct count.
3. Click "Review & clean up" — sheet opens pre-filtered to "Very Short (<1m)" and sorted "Oldest First", and the bulk-delete button is visible.
4. Click "Manage Sessions" — sheet opens with filter "All Sessions", sort "Newest First", bulk-delete button hidden.
5. With zero short sessions, the hint row is absent.

- [ ] **Step 4: Commit**

```bash
git add auto-focus/Views/DataView.swift
git commit -m "Add short-session cleanup hint to data tab"
```

---

## Task 6: Add screen-lock observation and `handleScreenInactive` on FocusManager

**Files:**
- Modify: `auto-focus/Services/FocusManager.swift`
- Add: `auto-focusTests/ScreenLockSessionEndTests.swift`

- [ ] **Step 1: Write the failing test**

Create `auto-focusTests/ScreenLockSessionEndTests.swift`:

```swift
@testable import auto_focus
import XCTest

#if DEBUG

final class ScreenLockSessionEndTests: XCTestCase {
    var focusManager: FocusManager!
    var mockSessionManager: MockSessionManager!
    var mockAppMonitor: MockAppMonitor!
    var mockBufferManager: MockBufferManager!
    var mockFocusModeManager: MockFocusModeManager!

    override func setUp() {
        super.setUp()
        let mocks = MockFactory.createMockDependencies()
        mockSessionManager = mocks.sessionManager
        mockAppMonitor = mocks.appMonitor
        mockBufferManager = mocks.bufferManager
        mockFocusModeManager = mocks.focusModeManager
        focusManager = MockFactory.createFocusManager(
            sessionManager: mockSessionManager,
            appMonitor: mockAppMonitor,
            bufferManager: mockBufferManager,
            focusModeManager: mockFocusModeManager
        )
    }

    func testScreenLockEndsSessionWhenThresholdReached() {
        mockSessionManager.startSession()
        focusManager.isFocusAppActive = true
        focusManager.isInFocusMode = true
        focusManager.didReachFocusThreshold = true
        focusManager.timeSpent = 600

        focusManager.handleScreenInactive()

        XCTAssertEqual(mockSessionManager.focusSessions.count, 1, "Session should be saved when threshold was reached")
        XCTAssertFalse(focusManager.isFocusAppActive)
        XCTAssertFalse(focusManager.isInFocusMode)
        XCTAssertFalse(focusManager.didReachFocusThreshold)
        XCTAssertEqual(focusManager.timeSpent, 0)
    }

    func testScreenLockDiscardsPreThresholdSession() {
        mockSessionManager.startSession()
        focusManager.isFocusAppActive = true
        focusManager.didReachFocusThreshold = false
        focusManager.timeSpent = 5

        focusManager.handleScreenInactive()

        XCTAssertEqual(mockSessionManager.focusSessions.count, 0, "Pre-threshold session should be discarded")
        XCTAssertFalse(focusManager.isFocusAppActive)
        XCTAssertEqual(focusManager.timeSpent, 0)
    }

    func testScreenLockCancelsActiveBuffer() {
        focusManager.isFocusAppActive = true
        focusManager.didReachFocusThreshold = true
        mockBufferManager.startBuffer(duration: 60)
        XCTAssertTrue(mockBufferManager.isInBufferPeriod)

        focusManager.handleScreenInactive()

        XCTAssertFalse(mockBufferManager.isInBufferPeriod, "Buffer should be cancelled on lock")
        XCTAssertEqual(mockSessionManager.focusSessions.count, 1, "Session should still be saved when threshold was reached")
    }

    func testScreenLockNoOpWhenPaused() {
        focusManager.isPaused = true
        focusManager.isFocusAppActive = true
        focusManager.didReachFocusThreshold = true

        focusManager.handleScreenInactive()

        XCTAssertEqual(mockSessionManager.focusSessions.count, 0)
    }
}

#endif
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project auto-focus.xcodeproj -scheme auto-focus -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO -only-testing:auto-focusTests/ScreenLockSessionEndTests`
Expected: Compilation failure ("Value of type 'FocusManager' has no member 'handleScreenInactive'").

- [ ] **Step 3: Add `handleScreenInactive()` to FocusManager**

In `auto-focus/Services/FocusManager.swift`, add immediately after `resetFocusState()` (around line 380):

```swift
func handleScreenInactive() {
    guard !isPaused else { return }
    guard isFocusAppActive || isBrowserInFocus || timeSpent > 0 || bufferManager.isInBufferPeriod else {
        return
    }

    bufferManager.cancelBuffer()

    if didReachFocusThreshold {
        sessionManager.endSession()
    } else {
        sessionManager.cancelCurrentSession()
    }

    resetFocusState()

    if !isNotificationsEnabled {
        focusModeController.setFocusMode(enabled: false)
    }

    AppLogger.focus.info("Screen inactive — session ended")
}
```

- [ ] **Step 4: Wire up the notification observers in `init`**

In `auto-focus/Services/FocusManager.swift`, at the end of `init` (immediately after `refreshShortcutStatus()` around line 236), append:

```swift
        setUpScreenInactivityObservers()
```

Then add the helper as a private method (place near the other private helpers, e.g., right after `refreshShortcutStatus()`):

```swift
    private func setUpScreenInactivityObservers() {
        let workspaceNC = NSWorkspace.shared.notificationCenter
        workspaceNC.addObserver(
            self,
            selector: #selector(screenInactivityNotification),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        workspaceNC.addObserver(
            self,
            selector: #selector(screenInactivityNotification),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenInactivityNotification),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
    }

    @objc private func screenInactivityNotification() {
        handleScreenInactive()
    }
```

- [ ] **Step 5: Add a `deinit` to remove the observers**

In `auto-focus/Services/FocusManager.swift`, immediately before the closing brace of the `class FocusManager` body (just before `}` around line 483):

```swift
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
```

- [ ] **Step 6: Run the tests**

Run: `xcodebuild test -project auto-focus.xcodeproj -scheme auto-focus -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO -only-testing:auto-focusTests/ScreenLockSessionEndTests`
Expected: All four tests PASS.

- [ ] **Step 7: Commit**

```bash
git add auto-focus/Services/FocusManager.swift auto-focusTests/ScreenLockSessionEndTests.swift
git commit -m "End focus session when screen locks or sleeps"
```

---

## Task 7: Remove screen-lock detection from AppMonitor

**Files:**
- Modify: `auto-focus/Services/AppMonitor.swift`

- [ ] **Step 1: Remove the obsolete observer setup, handlers, and gating**

In `auto-focus/Services/AppMonitor.swift`:

a) Remove the `private var isScreenLocked = false` field (line 23).

b) In `startMonitoring()` (lines 33-41), remove the `observeScreenLockState()` call.

c) In `stopMonitoring()` (lines 43-48), remove the `removeScreenLockObservers()` call.

d) Remove the entire `// MARK: - Screen Lock Detection` block (lines 59-93), including:
   - `observeScreenLockState()`
   - `removeScreenLockObservers()`
   - `handleScreenSleep()`
   - `handleScreenWake()`
   - `handleScreenLocked()`
   - `handleScreenUnlocked()`

e) In `checkActiveApp()` (lines 97-130), remove the `guard !isScreenLocked else { return }` line at the top (line 98).

After the edits, `AppMonitor` is solely responsible for app activity detection — no screen-lock concerns.

- [ ] **Step 2: Build to confirm**

Run: `xcodebuild build -project auto-focus.xcodeproj -scheme auto-focus -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run the full test suite to catch regressions**

Run: `make test`
Expected: All tests PASS. Pay particular attention to `FocusManagerTests`, `FocusManagerStateTests`, `CoreFocusBehaviorTests`, and `BrowserPollingGatingTests` — they exercise `AppMonitor` indirectly.

- [ ] **Step 4: Commit**

```bash
git add auto-focus/Services/AppMonitor.swift
git commit -m "Move screen lock handling out of AppMonitor"
```

---

## Task 8: Final validation

- [ ] **Step 1: Full build**

Run: `xcodebuild build -project auto-focus.xcodeproj -scheme auto-focus -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED with no warnings introduced by this change.

- [ ] **Step 2: Full test suite**

Run: `make test`
Expected: All tests PASS.

- [ ] **Step 3: Manual end-to-end smoke test**

Manual verification of both features in a running app:

**Lock-end:**
1. Add a focus app you can easily activate (e.g., Notes).
2. Lower `focusThreshold` temporarily for quick reproduction (e.g., 1 minute).
3. Open Notes, wait until DND turns on (focus mode active).
4. Press Ctrl+Cmd+Q to lock the screen.
5. Wait ~10 seconds, unlock.
6. Verify a session ending around the moment of lock was saved (Data tab → Manage Sessions).
7. Verify `timeSpent` is 0 and DND is off after unlock.

**Lock without threshold:**
1. With `focusThreshold` set higher than the test, open a focus app for a few seconds (below threshold).
2. Lock the screen, unlock.
3. Verify NO session was saved.

**Bulk cleanup:**
1. With multiple sessions present, verify the orange "N sessions under 1 minute" hint appears on the Data tab if applicable.
2. Click "Review & clean up" → list opens pre-filtered.
3. Click "Delete N sessions" → confirm.
4. Verify list goes empty for that filter and the hint disappears.

- [ ] **Step 4: Final summary**

Report: build status, test status, what was verified manually, anything unexpected.
