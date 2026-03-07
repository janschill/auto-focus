# Auto-Focus Refactor Plan

## Phase 1: Delete Dead Code -- DONE
- [x] Delete `MenuBarViewModel.swift`
- [x] Delete `SessionEditingDemo.swift`
- [x] Remove `SessionManagerDelegate` protocol from `SessionManager.swift`
- [x] Remove `FocusTimer.onThresholdReached` property
- [x] Delete `FocusError.swift`
- [x] Rename `MenuBarViewModelTests.swift` -> `FocusManagerStateTests.swift`

## Phase 2: Remove FocusStateMachine -- DONE
- [x] Remove all `stateMachine.*` calls from FocusManager
- [x] Delete `FocusStateMachine.swift`
- [x] Delete `FocusState.swift`
- [x] Delete `FocusStateMachineTests.swift`
- [x] Remove `stateMachine` property from FocusManager

## Phase 3: Extract Import/Export from FocusManager -- DONE
- [x] Create `DataExportService.swift`
- [x] Move export/import methods out of FocusManager (~200 lines removed)
- [x] Update DataView to use DataExportService

## Phase 4: Stop Using FocusManager as a Facade -- SKIPPED
Removing pass-throughs would break SwiftUI's observation chain (views observe
FocusManager.objectWillChange; sub-managers are protocol-typed). Would require
making sub-managers environment objects - significant restructuring for ~60 lines
of simple one-liner forwards. Not worth the risk.

## Phase 5: Inline Thin ViewModels -- DONE
- [x] Inline `DebugViewModel` into `DebugView` as @State
- [x] Delete `DebugViewModel.swift`
- [x] Delete `ConfigurationViewModel.swift` (unused by any view)
- [x] Delete `ConfigurationViewModelTests.swift` (redundant with FocusManagerStateTests)

## Phase 6: Flatten Directory Structure -- DONE
- [x] Create `App/`, `Services/`, `Utilities/` directories
- [x] Move all files to flat 2-level structure
- [x] Remove old `Features/`, `Managers/`, `Shared/` directories
- [x] Xcode auto-discovers files (no pbxproj changes needed)

## Summary
- FocusManager: 925 -> 686 lines (-26%)
- Files deleted: 8 (3 dead code, 3 state machine, 2 thin ViewModels)
- Tests: 91 -> 63 (removed state machine + redundant ViewModel tests)
- Max directory depth: 4 -> 2
- All remaining 63 tests pass, build succeeds
