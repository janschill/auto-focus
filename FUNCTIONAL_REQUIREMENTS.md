# Auto-Focus Functional Requirements Specification

## Document Purpose
This document provides a comprehensive specification of all functional requirements for the Auto-Focus macOS application. This specification serves as the foundation for spec-driven development and rebuilding of the application.

---

## 1. Core Focus Detection & Management

### 1.1 Focus Detection Overview
**Requirement FR-001**: The system shall automatically detect when a user is engaged in focused work by monitoring active applications and browser tabs.

**Requirement FR-002**: Focus detection shall operate continuously while the application is running, checking the active application at configurable intervals (default: 1 second).

**Requirement FR-003**: The system shall support two types of focus contexts:
- **Application Focus**: User is using a designated focus application (e.g., VSCode, Xcode)
- **Browser Focus**: User is viewing a designated focus URL in a supported browser

**Requirement FR-004**: Application focus and browser focus shall share the same time tracking mechanism, allowing seamless transitions between contexts without resetting the timer.

### 1.2 Focus State Machine
**Requirement FR-005**: The system shall maintain a state machine with the following states:
- **Idle**: Not tracking focus time, no focus context active
- **Counting**: Tracking time but threshold not yet reached (Do Not Disturb not active)
- **Focus Mode**: Threshold reached, Do Not Disturb is active
- **Buffer**: Temporary grace period after leaving focus context

**Requirement FR-006**: State transitions shall be validated to ensure only valid transitions occur:
- Idle → Counting (when entering focus context)
- Counting → Focus Mode (when threshold reached)
- Counting → Idle (when leaving focus context before threshold)
- Counting → Buffer (when leaving focus context after threshold reached)
- Focus Mode → Buffer (when leaving focus context)
- Focus Mode → Idle (when buffer expires)
- Buffer → Counting (when returning to focus context)
- Buffer → Focus Mode (when returning to focus context and threshold already met)
- Buffer → Idle (when buffer expires)

**Requirement FR-007**: The state machine shall maintain a history of state transitions (up to 100 transitions) for debugging purposes.

### 1.3 Time Tracking
**Requirement FR-008**: The system shall track elapsed focus time using a timer that increments at configurable intervals (default: 1 second).

**Requirement FR-009**: Time tracking shall preserve elapsed time when switching between focus contexts (app ↔ browser, app ↔ app, browser ↔ browser).

**Requirement FR-010**: Time tracking shall reset to zero when:
- User leaves focus entirely (focus → non-focus)
- User manually pauses the system
- User explicitly resets focus state

**Requirement FR-011**: Time tracking shall pause (but not reset) when entering buffer period.

**Requirement FR-012**: The timer shall support starting with preserved time (for context switching) or reset time (for new sessions).

**Requirement FR-013**: In debug builds, time shall use a multiplier of 1.0 (1 second = 1 second). In production builds, time shall use a multiplier of 60.0 (1 second = 1 minute).

### 1.4 Focus Threshold
**Requirement FR-014**: The system shall activate Do Not Disturb mode after a configurable threshold of focused time (default: 12 minutes).

**Requirement FR-015**: The threshold shall be configurable by the user through the settings interface.

**Requirement FR-016**: The threshold shall be stored persistently and restored on application launch.

**Requirement FR-017**: When the threshold is reached, the system shall:
- Transition to Focus Mode state
- Activate Do Not Disturb mode
- Continue tracking time
- Update UI to reflect active focus mode

---

## 2. Application Monitoring

### 2.1 Application Detection
**Requirement FR-018**: The system shall continuously monitor the frontmost application using macOS system APIs.

**Requirement FR-019**: Application monitoring shall check the active application at configurable intervals (default: 1 second).

**Requirement FR-020**: The system shall detect when the active application changes and notify the focus manager.

**Requirement FR-021**: The system shall identify applications by their bundle identifier (e.g., `com.microsoft.VSCode`, `com.apple.dt.Xcode`).

### 2.2 Focus Applications Management
**Requirement FR-022**: Users shall be able to designate specific applications as "focus applications" that trigger focus detection.

**Requirement FR-023**: Users shall be able to add focus applications by:
- Selecting an application from the file system (via file picker)
- Extracting bundle identifier and display name from the selected application

**Requirement FR-024**: Users shall be able to remove focus applications from the list.

**Requirement FR-025**: Focus applications shall be stored persistently and restored on application launch.

**Requirement FR-026**: Focus applications shall be sorted alphabetically by name in the UI.

**Requirement FR-027**: The system shall enforce limits on the number of focus applications:
- Free tier: Maximum 3 focus applications
- Premium tier: Unlimited (or as specified by license)

**Requirement FR-028**: The system shall prevent adding duplicate applications (based on bundle identifier).

**Requirement FR-029**: When a focus application becomes the frontmost application, the system shall:
- Start or continue time tracking
- Preserve time if switching from another focus context
- Reset time if starting a new focus session

**Requirement FR-030**: When a non-focus application becomes frontmost:
- If in Focus Mode: Enter buffer period
- If in Counting state: Reset focus state (unless switching to browser focus)
- If in Idle: No action needed

### 2.3 Browser Application Detection
**Requirement FR-031**: The system shall recognize when a browser application becomes frontmost:
- Google Chrome (and variants: Canary, Beta, Dev)
- Microsoft Edge (and variants)
- Safari
- Firefox
- Other Chromium-based browsers (Brave, Opera, Vivaldi, Arc, etc.)

**Requirement FR-032**: When switching to a browser application, the system shall:
- Check if browser extension is connected
- If connected: Wait for browser focus state from extension
- If not connected: Handle as non-focus application

**Requirement FR-033**: The system shall distinguish between:
- Tab switching within browser (browser still frontmost) → Reset timer
- App switching (browser not frontmost) → Preserve time if switching to focus app

---

## 3. Browser Integration

### 3.1 Browser Extension Communication
**Requirement FR-034**: The system shall communicate with browser extensions via HTTP server running on localhost (default port: 8942).

**Requirement FR-035**: The HTTP server shall:
- Start automatically when the application launches
- Retry startup on failure (up to 3 attempts with exponential backoff)
- Perform periodic health checks (default: every 60 seconds)
- Restart automatically on health check failure (if configured)

**Requirement FR-036**: The HTTP server shall accept POST requests to `/browser` endpoint with the following commands:
- `handshake`: Initial connection establishment
- `heartbeat`: Periodic connection keepalive (every 30 seconds)
- `tab_changed`: Tab URL changed notification
- `browser_lost_focus`: Browser window lost focus
- `add_focus_url`: Add URL from extension popup
- `connection_test`: Connection diagnostics

**Requirement FR-037**: The HTTP server shall respond with JSON-formatted responses including:
- Command acknowledgment
- Connection status
- Focus state information
- Recommendations (if applicable)

### 3.2 Browser Extension Connection Management
**Requirement FR-038**: The system shall track extension connection state:
- **Connected**: Extension is actively communicating
- **Disconnected**: No communication received within timeout period (default: 90 seconds)

**Requirement FR-039**: The system shall reset connection timeout timer when receiving:
- Handshake messages
- Heartbeat messages
- Tab change messages

**Requirement FR-040**: The system shall mark extension as disconnected if no messages received within timeout period.

**Requirement FR-041**: The system shall handle system sleep/wake events:
- Pause connection timeout processing during sleep
- Resume connection timeout processing on wake
- Reset connection state on wake (extension will reconnect)

**Requirement FR-042**: The system shall track connection quality:
- **Excellent**: No failures, stable connection
- **Good**: Occasional failures (< 3 consecutive)
- **Fair**: Some failures (3-10 consecutive)
- **Poor**: Many failures (> 10 consecutive)
- **Disconnected**: No connection
- **Unknown**: Initial state

### 3.3 Focus URL Management
**Requirement FR-043**: Users shall be able to designate specific URLs/domains as "focus URLs" that trigger browser focus detection.

**Requirement FR-044**: Focus URLs shall support multiple match types:
- **Exact**: Matches exact URL
- **Domain**: Matches domain and subdomains (e.g., `github.com` matches `docs.github.com`)
- **Contains**: URL contains the specified text
- **StartsWith**: URL starts with the specified text

**Requirement FR-045**: Focus URLs shall support wildcard domain patterns (e.g., `*.google.com` matches `docs.google.com`, `drive.google.com`).

**Requirement FR-046**: Focus URLs shall be categorized:
- Work
- Communication
- Development
- Design
- Documentation
- Productivity
- Learning
- Custom

**Requirement FR-047**: Focus URLs shall support enable/disable toggle without removal.

**Requirement FR-048**: Focus URLs shall support premium designation (requires premium license).

**Requirement FR-049**: The system shall enforce limits on focus URLs:
- Free tier: Maximum 3 focus URLs
- Premium tier: Unlimited (or as specified by license)

**Requirement FR-050**: Focus URLs shall be stored persistently and restored on application launch.

**Requirement FR-051**: Focus URLs shall be sorted alphabetically by name in the UI.

**Requirement FR-052**: The system shall provide preset focus URLs:
- Free presets: Common free URLs (GitHub, Stack Overflow, Google Docs)
- Premium presets: Additional premium URLs (GitLab, Figma, Notion, etc.)

**Requirement FR-053**: Users shall be able to add preset URLs in bulk.

**Requirement FR-054**: When a focus URL is detected in the active browser tab:
- Start or continue time tracking
- Preserve time if switching from another focus context
- Reset time if starting a new focus session
- Only activate if browser is actually frontmost (prevent false positives)

**Requirement FR-055**: When switching away from a focus URL:
- If in Focus Mode: Enter buffer period
- If in Counting state: Check if switching tabs (reset) or switching apps (preserve if switching to focus app)
- If in Idle: No action needed

**Requirement FR-056**: The system shall suppress focus activation for 2 seconds after adding a new focus URL (to prevent immediate activation when adding current URL).

### 3.4 Browser Tab Information
**Requirement FR-057**: The system shall track current browser tab information:
- URL
- Page title
- Timestamp
- Whether it matches a focus URL
- Which focus URL it matches

**Requirement FR-058**: The system shall update tab information when:
- Tab URL changes
- Tab is activated
- Browser window gains focus

**Requirement FR-059**: The system shall ignore Chrome internal pages (`chrome://`, `chrome-extension://`).

---

## 4. Focus Mode Control (Do Not Disturb)

### 4.1 Do Not Disturb Activation
**Requirement FR-060**: The system shall activate macOS Do Not Disturb mode when focus threshold is reached.

**Requirement FR-061**: Do Not Disturb activation shall use Apple Shortcuts integration:
- Require a Shortcut named "Toggle Do Not Disturb" to be installed
- Execute the Shortcut via AppleScript/Shortcuts Events API
- Handle errors gracefully if Shortcut is not found

**Requirement FR-062**: The system shall verify Shortcut installation on startup and periodically.

**Requirement FR-063**: The system shall provide UI feedback if Shortcut is not installed.

**Requirement FR-064**: The system shall track whether Do Not Disturb is currently enabled.

**Requirement FR-065**: The system shall deactivate Do Not Disturb when:
- Buffer period expires
- User manually pauses the system
- User leaves focus entirely

**Requirement FR-066**: The system shall only activate/deactivate Do Not Disturb if notifications are enabled (user preference).

### 4.2 Focus Mode State Management
**Requirement FR-067**: Focus Mode state (`isInFocusMode`) shall be synchronized with state machine Focus Mode state.

**Requirement FR-068**: Focus Mode shall remain active during buffer period (Do Not Disturb stays on).

**Requirement FR-069**: Focus Mode shall be deactivated when:
- Buffer period expires
- User returns to focus context (cancels buffer)
- User manually resets focus state

---

## 5. Buffer Period Management

### 5.1 Buffer Period Overview
**Requirement FR-070**: The system shall provide a configurable buffer period that prevents immediate focus loss when switching away from focus contexts.

**Requirement FR-071**: Buffer period shall only activate when:
- User is in Focus Mode (Do Not Disturb is active)
- User switches to a non-focus application or non-focus URL

**Requirement FR-072**: Buffer period shall NOT activate when:
- User is in Counting state (before threshold reached)
- User switches between focus contexts (app ↔ browser, app ↔ app)

### 5.2 Buffer Period Behavior
**Requirement FR-073**: Buffer period duration shall be configurable (default: 2 seconds).

**Requirement FR-074**: Buffer period duration shall be stored persistently and restored on application launch.

**Requirement FR-075**: During buffer period:
- Timer shall pause (not reset)
- Do Not Disturb shall remain active
- System shall wait for user to return to focus context

**Requirement FR-076**: If user returns to focus context during buffer period:
- Buffer shall be cancelled
- Timer shall resume
- Focus session shall continue

**Requirement FR-077**: If buffer period expires:
- Focus session shall end
- Timer shall reset
- Do Not Disturb shall deactivate (if notifications enabled)
- System shall transition to Idle state

**Requirement FR-078**: Buffer time remaining shall be displayed in menu bar (if buffer is active).

**Requirement FR-079**: Buffer countdown shall update at configurable intervals (default: 1 second).

---

## 6. Session Management

### 6.1 Focus Session Tracking
**Requirement FR-080**: The system shall track focus sessions, recording:
- Start time
- End time
- Duration (calculated)
- Unique session identifier

**Requirement FR-081**: A focus session shall start when:
- User enters a focus context (app or browser) for the first time
- Timer begins tracking

**Requirement FR-082**: A focus session shall end when:
- Buffer period expires
- User manually pauses the system
- User leaves focus entirely

**Requirement FR-083**: A focus session shall NOT end when:
- Switching between focus contexts (app ↔ browser, app ↔ app)
- Switching browser tabs (if staying in focus URL)

**Requirement FR-084**: Focus sessions shall be stored persistently in UserDefaults.

**Requirement FR-085**: Focus sessions shall be sorted by start time (newest first).

### 6.2 Session Queries
**Requirement FR-086**: The system shall provide queries for focus sessions:
- **Today's Sessions**: All sessions that started today
- **Week Sessions**: All sessions from the last 7 days
- **Month Sessions**: All sessions from the last 30 days
- **All Sessions**: Complete session history

**Requirement FR-087**: Session queries shall use calendar-aware date calculations.

### 6.3 Session Editing
**Requirement FR-088**: Users shall be able to edit focus sessions:
- Modify start time
- Modify end time
- Delete sessions

**Requirement FR-089**: Session editing shall validate:
- Start time must be before end time
- Duration must be at least 1 second
- Duration must not exceed 24 hours
- End time cannot be in the future (with 1 minute tolerance)

**Requirement FR-090**: Invalid session edits shall be rejected with appropriate error messages.

**Requirement FR-091**: Session edits shall be persisted immediately.

### 6.4 Session Import/Export
**Requirement FR-092**: Users shall be able to import sessions from exported data files (Premium feature).

**Requirement FR-093**: Session import shall:
- Detect and skip duplicate sessions (based on start time and duration within 1 second tolerance)
- Report number of sessions imported and duplicates skipped
- Validate session data before importing

**Requirement FR-094**: Users shall be able to export sessions as part of data export (Premium feature).

---

## 7. License & Premium Features

### 7.1 License Management
**Requirement FR-095**: The system shall support license-based feature access:
- **Free Tier**: Limited features (3 apps, 3 URLs)
- **Premium Tier**: Unlimited features (or as specified by license)

**Requirement FR-096**: License validation shall occur:
- On application startup (if license exists and validation needed)
- When license key is entered
- Periodically (default: once per week)
- On-demand by user

**Requirement FR-097**: License validation shall communicate with license server:
- Endpoint: `https://auto-focus.app/api/v1/licenses/validate`
- Method: POST
- Payload: License key, app version
- Response: License validity, owner info, expiry date, max apps allowed

**Requirement FR-098**: License validation shall verify HMAC signature on server responses.

**Requirement FR-099**: License validation shall check response timestamp (must be within 5 minutes).

**Requirement FR-100**: License status shall be one of:
- **Inactive**: No license key entered
- **Valid**: License is active and valid
- **Expired**: License has expired
- **Invalid**: License key is invalid
- **Network Error**: Unable to validate (grace period applies)

### 7.2 Grace Period & Offline Support
**Requirement FR-101**: The system shall support grace period for offline operation:
- Default grace period: 30 days
- License remains valid during grace period if last validation was successful
- License invalidates after grace period expires

**Requirement FR-102**: If network error occurs during validation:
- License remains valid if within grace period
- License remains valid if expiry date hasn't passed locally
- License invalidates if grace period expired

**Requirement FR-103**: The system shall store last validation timestamp locally.

### 7.3 Beta Period Support
**Requirement FR-104**: The system shall support beta period access:
- Beta period ends: August 31, 2025
- During beta: All features available without license
- After beta: Requires valid license

**Requirement FR-105**: Beta access shall only be enabled if user doesn't have a valid license.

### 7.4 Premium Feature Limits
**Requirement FR-106**: Free tier limits:
- Maximum 3 focus applications
- Maximum 3 focus URLs
- No data export/import

**Requirement FR-107**: Premium tier limits:
- Unlimited focus applications (or as specified by license `maxAppsAllowed`)
- Unlimited focus URLs
- Data export/import available
- Premium URL presets available

**Requirement FR-108**: The system shall check license status before:
- Adding focus applications (if at limit)
- Adding focus URLs (if at limit)
- Exporting data
- Importing data
- Adding premium URLs

**Requirement FR-109**: The system shall display appropriate UI messages when premium features are blocked.

### 7.5 License UI
**Requirement FR-110**: Users shall be able to:
- Enter license key
- Activate license
- View license status
- View license owner information
- View license expiry date
- Deactivate license

**Requirement FR-111**: License UI shall display:
- Current license status with icon and color
- License owner name and email
- License expiry date (if applicable)
- Validation errors (if any)
- Activation status (loading indicator)

---

## 8. Data Export/Import

### 8.1 Data Export
**Requirement FR-112**: Users shall be able to export application data (Premium feature).

**Requirement FR-113**: Export data shall include:
- Focus sessions (optionally filtered by date range)
- Focus applications list
- User settings (threshold, buffer, onboarding status)

**Requirement FR-114**: Export format shall be JSON with version metadata:
- Version: "1.0"
- Export date
- App version

**Requirement FR-115**: Export shall use macOS file save dialog:
- Default filename: `auto-focus-export-{timestamp}.json`
- File type: JSON
- User-selectable save location

**Requirement FR-116**: Export shall handle errors gracefully:
- Encoding errors
- File write errors
- User cancellation

### 8.2 Data Import
**Requirement FR-117**: Users shall be able to import application data (Premium feature).

**Requirement FR-118**: Import shall use macOS file open dialog:
- File type: JSON
- Single file selection

**Requirement FR-119**: Import shall validate:
- File format (must be valid JSON)
- Version compatibility (must be version "1.0")
- Data integrity (sessions, apps, settings structure)

**Requirement FR-120**: Import shall:
- Skip duplicate sessions (based on start time and duration)
- Skip duplicate focus apps (based on bundle identifier)
- Import settings (non-zero values only)
- Report import summary (sessions imported, apps imported, duplicates skipped)

**Requirement FR-121**: Import shall handle errors:
- Invalid file format
- Unsupported version
- Corrupted data
- Read errors

**Requirement FR-122**: Import results shall be displayed to user (success summary or error message).

---

## 9. User Interface

### 9.1 Menu Bar Interface
**Requirement FR-123**: The application shall run as a menu bar application (not dock application).

**Requirement FR-124**: Menu bar icon shall display:
- Brain icon (filled when in focus mode, outline when not)
- Pause icon when system is paused
- Timer display (if configured and focus app active)
- Buffer countdown (if in buffer period)

**Requirement FR-125**: Timer display modes:
- **Hidden**: No timer displayed
- **Full**: Display with seconds (e.g., "12:34")
- **Simplified**: Display in minutes only (e.g., "12m")

**Requirement FR-126**: Timer display mode shall be configurable and persistent.

**Requirement FR-127**: Menu bar window shall open when icon is clicked, displaying:
- Current focus status
- Time spent
- Quick actions (pause/resume)
- Link to settings

### 9.2 Settings Window
**Requirement FR-128**: Settings window shall be accessible via:
- Menu bar icon click
- System Preferences → Auto-Focus
- Keyboard shortcut (if configured)

**Requirement FR-129**: Settings window shall display:
- Focus applications list (add/remove)
- Focus URLs list (add/remove/edit)
- Focus threshold configuration
- Buffer period configuration
- Timer display mode configuration
- License management
- Data export/import
- Insights/analytics
- Debug information (debug builds)

**Requirement FR-130**: Settings window shall be non-resizable (content size).

**Requirement FR-131**: Settings window shall use unified compact toolbar style.

### 9.3 Onboarding
**Requirement FR-132**: First-time users shall see an onboarding flow:
- Welcome screen
- Explanation of how Auto-Focus works
- Instructions to install Shortcut
- Option to add focus applications
- Option to add focus URLs

**Requirement FR-133**: Onboarding completion shall be tracked and stored persistently.

**Requirement FR-134**: Users shall be able to reset onboarding (for testing/debugging).

**Requirement FR-135**: Onboarding shall only display once per installation.

### 9.4 Focus Applications UI
**Requirement FR-136**: Focus applications list shall display:
- Application name
- Application icon (if available)
- Remove button
- Add button (if under limit)

**Requirement FR-137**: Adding focus application shall:
- Open file picker
- Filter to show applications only
- Default to `/Applications` directory
- Extract bundle identifier and name
- Add to list (if not duplicate)

**Requirement FR-138**: Removing focus application shall:
- Remove from list immediately
- Persist removal
- Update app monitor

### 9.5 Focus URLs UI
**Requirement FR-139**: Focus URLs list shall display:
- URL name
- Domain/URL pattern
- Match type
- Category icon
- Enabled/disabled status
- Premium indicator (if applicable)
- Edit/remove buttons

**Requirement FR-140**: Adding focus URL shall:
- Allow manual entry (name, domain, match type, category)
- Allow selection from presets
- Validate domain format
- Check premium limits
- Suppress immediate activation (2 seconds)

**Requirement FR-141**: Editing focus URL shall:
- Allow modification of name, domain, match type, category
- Allow enable/disable toggle
- Persist changes immediately

**Requirement FR-142**: Removing focus URL shall:
- Remove from list immediately
- Persist removal
- Update browser manager

### 9.6 Insights/Analytics UI
**Requirement FR-143**: The system shall provide insights view displaying:
- Today's total focus time
- Week's total focus time
- Month's total focus time
- Session count (today/week/month)
- Average session duration
- Focus sessions list (editable)

**Requirement FR-144**: Insights shall update in real-time as sessions are recorded.

**Requirement FR-145**: Session list shall support:
- Viewing session details
- Editing sessions
- Deleting sessions
- Filtering by date range

### 9.7 Browser Extension Popup UI
**Requirement FR-146**: Browser extension shall provide popup UI displaying:
- Connection status
- Current URL focus status
- Option to add current URL as focus URL
- Connection diagnostics
- Manual reconnect option

**Requirement FR-147**: Extension popup shall update in real-time as connection state changes.

---

## 10. Configuration & Settings

### 10.1 Persistent Settings
**Requirement FR-148**: The following settings shall be stored persistently:
- Focus applications list
- Focus URLs list
- Focus threshold (default: 12 minutes)
- Buffer period duration (default: 2 seconds)
- Timer display mode (default: full)
- Pause state
- Onboarding completion status
- License key and data
- Focus sessions

**Requirement FR-149**: Settings shall be stored in UserDefaults under app bundle identifier.

**Requirement FR-150**: Settings shall be restored on application launch.

### 10.2 Configuration Constants
**Requirement FR-151**: The system shall use configurable constants:
- Check interval: 1 second
- Buffer timer interval: 1 second
- Connection timeout: 90 seconds
- Server health check interval: 60 seconds
- Heartbeat interval: 30 seconds
- Max startup retries: 3
- Validation interval: 168 hours (1 week)
- Grace period: 30 days

**Requirement FR-152**: Configuration constants shall be defined in `AppConfiguration` struct.

### 10.3 User Preferences
**Requirement FR-153**: Users shall be able to configure:
- Focus threshold (time before DND activates)
- Buffer period duration (grace period after leaving focus)
- Timer display mode (hidden/full/simplified)
- Notifications enabled/disabled

**Requirement FR-154**: User preferences shall have sensible defaults and validation:
- Focus threshold: Minimum 1 minute, maximum 60 minutes
- Buffer period: Minimum 1 second, maximum 60 seconds
- Timer display mode: Must be valid enum value

---

## 11. System Integration

### 11.1 macOS Integration
**Requirement FR-155**: The application shall integrate with macOS:
- Use NSWorkspace for application monitoring
- Use AppleScript/Shortcuts Events for Do Not Disturb control
- Use UserDefaults for persistence
- Use NSApplication for menu bar integration
- Use SwiftUI for UI

**Requirement FR-156**: The application shall request necessary permissions:
- Accessibility permissions (for application monitoring)
- Network permissions (for HTTP server and license validation)

**Requirement FR-157**: The application shall handle system events:
- Sleep/wake notifications
- Screen sleep/wake notifications
- Application termination

### 11.2 Shortcuts Integration
**Requirement FR-158**: The application shall require a Shortcut named "Toggle Do Not Disturb" to be installed.

**Requirement FR-159**: The application shall verify Shortcut installation:
- On startup
- Before activating Do Not Disturb
- Periodically (on demand)

**Requirement FR-160**: The application shall provide instructions for installing the Shortcut.

**Requirement FR-161**: The application shall handle Shortcut errors gracefully:
- Shortcut not found
- Shortcuts app not installed
- AppleScript errors

### 11.3 HTTP Server
**Requirement FR-162**: The application shall run an HTTP server for browser extension communication:
- Port: 8942 (configurable)
- Protocol: HTTP (not HTTPS for localhost)
- Endpoint: `/browser` (POST only)

**Requirement FR-163**: HTTP server shall:
- Start automatically on application launch
- Retry on startup failure (exponential backoff)
- Perform health checks periodically
- Restart on health check failure (if configured)
- Handle multiple concurrent connections

**Requirement FR-164**: HTTP server shall handle CORS headers for browser extension compatibility.

**Requirement FR-165**: HTTP server shall validate request format:
- Must be POST request
- Must have JSON body
- Must include command field

---

## 12. Error Handling & Logging

### 12.1 Error Handling
**Requirement FR-166**: The system shall handle errors gracefully:
- Network errors (license validation, HTTP server)
- File system errors (export/import, persistence)
- AppleScript errors (Shortcut execution)
- Invalid state transitions
- Invalid user input

**Requirement FR-167**: Errors shall be logged with context:
- Error type
- Error message
- Timestamp
- Relevant state information
- User action (if applicable)

**Requirement FR-168**: User-facing errors shall display:
- Clear error message
- Suggested resolution (if applicable)
- Error code/reference (for support)

**Requirement FR-169**: Non-critical errors shall not crash the application.

### 12.2 Logging
**Requirement FR-170**: The system shall provide structured logging:
- Focus events (state changes, timer ticks)
- Browser events (tab changes, connection state)
- Network events (HTTP server, license validation)
- Session events (start, end, edit)
- Error events

**Requirement FR-171**: Logs shall include:
- Timestamp
- Log level (debug, info, warning, error)
- Category/component
- Metadata (relevant state, IDs, etc.)

**Requirement FR-172**: Logs shall be written to:
- Console (for development)
- Log files (for production debugging)
- Debug view (in debug builds)

**Requirement FR-173**: Log files shall be:
- Rotated periodically
- Limited in size
- Accessible via debug UI

### 12.3 Debug Features
**Requirement FR-174**: Debug builds shall include:
- Debug view with logs
- Sample data generation
- Session clearing
- State machine inspection
- Connection diagnostics

**Requirement FR-175**: Debug features shall be disabled in production builds.

---

## 13. Performance & Reliability

### 13.1 Performance Requirements
**Requirement FR-176**: Application monitoring shall have minimal CPU impact:
- Check interval: 1 second (configurable)
- Efficient application detection
- Minimal memory footprint

**Requirement FR-177**: Timer updates shall be efficient:
- Update interval: 1 second
- Batch UI updates to prevent excessive redraws
- Defer delegate notifications to avoid publishing during view updates

**Requirement FR-178**: HTTP server shall handle requests efficiently:
- Non-blocking I/O
- Quick response times (< 100ms)
- Minimal resource usage

### 13.2 Reliability Requirements
**Requirement FR-179**: The application shall recover from:
- HTTP server startup failures
- Extension disconnections
- Network errors
- System sleep/wake events
- Invalid state transitions

**Requirement FR-180**: The application shall maintain state consistency:
- Timer state synchronized with state machine
- Focus mode state synchronized with Do Not Disturb
- Connection state synchronized with extension

**Requirement FR-181**: The application shall handle edge cases:
- Rapid app switching
- Browser tab switching during focus
- System sleep during focus session
- Extension reconnection during focus session
- Multiple focus contexts active simultaneously

---

## 14. Security & Privacy

### 14.1 Data Privacy
**Requirement FR-182**: All user data shall be stored locally:
- Focus sessions
- Focus applications
- Focus URLs
- Settings
- License information

**Requirement FR-183**: No user data shall be transmitted except:
- License validation (license key only)
- License deactivation (license key and instance ID)

**Requirement FR-184**: Browser extension communication shall be:
- Local only (localhost)
- No external network requests
- No data collection

### 14.2 Security
**Requirement FR-185**: License validation shall:
- Verify HMAC signatures
- Check response timestamps
- Validate response format
- Handle invalid responses securely

**Requirement FR-186**: HTTP server shall:
- Accept connections from localhost only
- Validate request format
- Handle malformed requests gracefully
- Not expose sensitive data

**Requirement FR-187**: File operations shall:
- Validate file formats
- Handle malicious input safely
- Prevent path traversal attacks

---

## 15. Browser Extension Requirements

### 15.1 Extension Functionality
**Requirement FR-188**: Browser extension shall:
- Monitor active tab URL changes
- Detect browser window focus changes
- Communicate with Auto-Focus app via HTTP
- Display connection status in popup
- Allow adding current URL as focus URL

**Requirement FR-189**: Extension shall use Manifest V3 service worker architecture.

**Requirement FR-190**: Extension shall handle service worker suspension:
- Save state before suspension
- Restore state on wake
- Reinitialize listeners on wake
- Maintain connection state across suspensions

### 15.2 Extension Communication
**Requirement FR-191**: Extension shall send messages:
- `handshake`: On startup/reconnection
- `heartbeat`: Every 30 seconds (via alarm)
- `tab_changed`: When tab URL changes
- `browser_lost_focus`: When browser window loses focus
- `add_focus_url`: When user adds URL from popup

**Requirement FR-192**: Extension shall handle connection failures:
- Retry with exponential backoff (up to 5 attempts)
- Fall back to alarm-based retry (1 minute)
- Display connection status in popup
- Provide manual reconnect option

**Requirement FR-193**: Extension shall track connection health:
- Connection errors
- Consecutive failures
- Last successful connection timestamp
- Connection state (connected/disconnected)

### 15.3 Extension UI
**Requirement FR-194**: Extension popup shall display:
- Connection status (connected/disconnected)
- Current URL
- Focus URL match status
- Option to add current URL
- Connection diagnostics
- Manual reconnect button

**Requirement FR-195**: Extension icon shall reflect state:
- Normal: Default icon
- Active: Active session icon
- Focus: Focus URL active icon
- Inactive: Inactive icon

---

## 16. Testing & Quality Assurance

### 16.1 Test Coverage
**Requirement FR-196**: The system shall include unit tests for:
- State machine transitions
- Timer functionality
- Session management
- URL matching logic
- License validation
- Data import/export

**Requirement FR-197**: The system shall include integration tests for:
- Application monitoring
- Browser integration
- HTTP server communication
- Focus mode activation
- Buffer period handling

### 16.2 Test Scenarios
**Requirement FR-198**: Critical test scenarios:
- Switching between focus apps (timer preservation)
- Switching between app and browser focus (timer preservation)
- Switching browser tabs (timer reset)
- Buffer period expiration
- System sleep during focus session
- Extension disconnection/reconnection
- License validation (success/failure/offline)
- Data export/import (success/failure)

---

## 17. Deployment & Distribution

### 17.1 Build & Release
**Requirement FR-199**: The application shall support:
- Debug builds (with debug features)
- Release builds (production optimized)
- Automated release via GitHub Actions

**Requirement FR-200**: Release process shall:
- Build and archive app
- Code sign with Developer ID
- Notarize with Apple
- Package app and extension
- Create git tag
- Create GitHub release
- Update distribution files

### 17.2 Distribution
**Requirement FR-201**: Application shall be distributed as:
- macOS application bundle (.app)
- Browser extension (.zip)
- Release notes
- Installation instructions

**Requirement FR-202**: Distribution files shall be:
- Hosted on GitHub releases
- Available via website downloads
- Versioned appropriately

---

## Appendix A: Data Models

### A.1 Core Models
- **AppInfo**: Application identifier, name, bundle identifier
- **FocusURL**: URL identifier, name, domain, match type, category, enabled status, premium flag
- **FocusSession**: Session identifier, start time, end time, duration
- **BrowserTabInfo**: URL, title, timestamp, focus status, matched URL
- **ExtensionHealth**: Version, installation date, errors, consecutive failures
- **ConnectionQuality**: Connection quality enum (excellent/good/fair/poor/disconnected/unknown)

### A.2 State Models
- **FocusState**: Idle, Counting, Focus Mode, Buffer
- **FocusTransition**: From state, to state, timestamp
- **LicenseStatus**: Inactive, Valid, Expired, Invalid, Network Error

### A.3 Export/Import Models
- **AutoFocusExportData**: Metadata, sessions, apps, settings
- **ExportMetadata**: Version, export date, app version
- **UserSettings**: Threshold, buffer, onboarding status
- **ImportResult**: Success summary or error
- **ImportSummary**: Sessions imported, apps imported, duplicates skipped

---

## Appendix B: Configuration Reference

### B.1 Default Values
- Focus threshold: 12 minutes
- Buffer period: 2 seconds
- Check interval: 1 second
- Connection timeout: 90 seconds
- Server port: 8942
- Free app limit: 3
- Free URL limit: 3
- Validation interval: 168 hours (1 week)
- Grace period: 30 days

### B.2 Time Multipliers
- Debug: 1.0 (1 second = 1 second)
- Production: 60.0 (1 second = 1 minute)

---

## Document Version
**Version**: 1.0
**Date**: 2025-01-27
**Status**: Draft for Review

---

## Notes
- This specification is based on analysis of the existing Auto-Focus codebase
- Requirements are numbered for traceability (FR-001 through FR-202)
- Some requirements may be refined during implementation
- This document serves as the foundation for spec-driven development


