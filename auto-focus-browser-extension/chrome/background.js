// Auto-Focus Browser Extension - Background Service Worker
// Simplified version focused on core functionality

const CONFIG = {
  HTTP_PORT: 8942,
  HEARTBEAT_INTERVAL: 30000, // 30 seconds
  MAX_RECONNECT_ATTEMPTS: 15, // Increased from 5 to 15
  RECONNECT_DELAY: 2000, // 2 seconds
  LONG_RETRY_DELAY: 60000 // 1 minute for long retries
};

let currentTabId = null;
let currentUrl = null;
let isConnectedToApp = false;
let reconnectAttempts = 0;
let heartbeatInterval = null;
let connectionErrors = [];
let lastSuccessfulConnection = null;

// Initialize extension
chrome.runtime.onInstalled.addListener((details) => {
  console.log('Auto-Focus extension installed/updated:', details.reason);
  initializeExtension();
});

chrome.runtime.onStartup.addListener(() => {
  console.log('Auto-Focus extension started');
  initializeExtension();
});

chrome.runtime.onSuspend.addListener(() => {
  console.log('Extension suspending - cleaning up');
  cleanup();
});

async function initializeExtension() {
  try {
    await connectToApp();
    startTabMonitoring();
  } catch (error) {
    console.error('Failed to initialize extension:', error);
  }
}

function cleanup() {
  if (heartbeatInterval) {
    clearInterval(heartbeatInterval);
    heartbeatInterval = null;
  }
}

// Connect to Auto-Focus HTTP server
async function connectToApp() {
  const attemptNumber = reconnectAttempts + 1;
  console.log(`🔄 Connecting to Auto-Focus app... (attempt ${attemptNumber}/${CONFIG.MAX_RECONNECT_ATTEMPTS})`);
  
  try {
    const connectionStart = Date.now();
    const response = await fetch(`http://localhost:${CONFIG.HTTP_PORT}/browser`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        command: 'handshake',
        version: chrome.runtime.getManifest().version,
        extensionId: chrome.runtime.id,
        timestamp: Date.now(),
        connectionErrors: connectionErrors.slice(-5), // Send last 5 errors for diagnostics
        lastSuccessfulConnection: lastSuccessfulConnection
      }),
      signal: AbortSignal.timeout(8000) // Increased to 8 second timeout
    });

    const connectionTime = Date.now() - connectionStart;

    if (response.ok) {
      const result = await response.json();
      if (result.command === 'handshake_response') {
        isConnectedToApp = true;
        reconnectAttempts = 0;
        lastSuccessfulConnection = Date.now();
        connectionErrors = []; // Clear errors on successful connection
        
        console.log(`✅ Connected to Auto-Focus app (${connectionTime}ms)`);
        console.log('📊 Connection established - app version:', result.appVersion);
        
        startHeartbeat();
        return;
      }
    }

    throw new Error(`Handshake failed: HTTP ${response.status} ${response.statusText}`);
  } catch (error) {
    const errorInfo = {
      timestamp: Date.now(),
      attempt: attemptNumber,
      error: error.message,
      type: error.name || 'ConnectionError'
    };
    
    connectionErrors.push(errorInfo);
    if (connectionErrors.length > 10) {
      connectionErrors = connectionErrors.slice(-10); // Keep only last 10 errors
    }
    
    console.error(`❌ Connection attempt ${attemptNumber} failed:`, error.message);
    isConnectedToApp = false;
    
    if (reconnectAttempts < CONFIG.MAX_RECONNECT_ATTEMPTS) {
      reconnectAttempts++;
      const delay = Math.min(
        CONFIG.RECONNECT_DELAY * Math.pow(1.5, reconnectAttempts - 1), // Gentler exponential backoff
        30000 // Cap at 30 seconds
      );
      console.log(`⏳ Retrying connection in ${Math.round(delay/1000)}s... (${CONFIG.MAX_RECONNECT_ATTEMPTS - reconnectAttempts} attempts remaining)`);
      setTimeout(connectToApp, delay);
    } else {
      console.error(`❌ Max reconnection attempts (${CONFIG.MAX_RECONNECT_ATTEMPTS}) reached`);
      console.log('🔄 Will retry connection in 1 minute...');
      reconnectAttempts = 0;
      // Try again in 1 minute instead of 5
      setTimeout(connectToApp, CONFIG.LONG_RETRY_DELAY);
    }
  }
}

// Start heartbeat to maintain connection
function startHeartbeat() {
  if (heartbeatInterval) {
    clearInterval(heartbeatInterval);
  }
  
  let consecutiveHeartbeatFailures = 0;
  
  heartbeatInterval = setInterval(async () => {
    if (!isConnectedToApp) return;
    
    try {
      const heartbeatStart = Date.now();
      const response = await fetch(`http://localhost:${CONFIG.HTTP_PORT}/browser`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          command: 'heartbeat',
          timestamp: Date.now(),
          consecutiveFailures: consecutiveHeartbeatFailures,
          connectionHealth: {
            state: 'connected',
            consecutiveFailures: consecutiveHeartbeatFailures,
            lastError: connectionErrors.length > 0 ? connectionErrors[connectionErrors.length - 1] : null
          }
        }),
        signal: AbortSignal.timeout(12000) // Increased timeout for heartbeat
      });
      
      const heartbeatTime = Date.now() - heartbeatStart;
      
      if (response.ok) {
        consecutiveHeartbeatFailures = 0;
        console.log(`💓 Heartbeat OK (${heartbeatTime}ms)`);
      } else {
        throw new Error(`HTTP ${response.status} ${response.statusText}`);
      }
    } catch (error) {
      consecutiveHeartbeatFailures++;
      console.error(`💔 Heartbeat failed (${consecutiveHeartbeatFailures}):`, error.message);
      
      // Only disconnect after 3 consecutive failures to avoid false positives
      if (consecutiveHeartbeatFailures >= 3) {
        console.error('❌ Connection lost after 3 consecutive heartbeat failures');
        isConnectedToApp = false;
        clearInterval(heartbeatInterval);
        heartbeatInterval = null;
        
        // Add error to tracking
        connectionErrors.push({
          timestamp: Date.now(),
          error: `Heartbeat failed: ${error.message}`,
          type: 'HeartbeatFailure',
          consecutiveFailures: consecutiveHeartbeatFailures
        });
        
        // Try to reconnect
        reconnectAttempts = 0;
        console.log('🔄 Attempting to reconnect...');
        connectToApp();
      }
    }
  }, CONFIG.HEARTBEAT_INTERVAL);
}

// Start monitoring tab changes
function startTabMonitoring() {
  // Listen for tab activation
  chrome.tabs.onActivated.addListener(async (activeInfo) => {
    await handleTabChange(activeInfo.tabId);
  });

  // Listen for tab updates
  chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
    if (changeInfo.url && tab.active) {
      await handleTabChange(tabId);
    }
  });

  // Listen for window focus changes
  chrome.windows.onFocusChanged.addListener(async (windowId) => {
    if (windowId !== chrome.windows.WINDOW_ID_NONE) {
      const tabs = await chrome.tabs.query({ active: true, windowId });
      if (tabs.length > 0) {
        await handleTabChange(tabs[0].id);
      }
    } else {
      // Chrome lost focus
      sendToApp({
        command: 'browser_lost_focus',
        timestamp: Date.now()
      });
    }
  });

  // Get current active tab on startup
  chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
    if (tabs.length > 0) {
      handleTabChange(tabs[0].id);
    }
  });
}

// Handle tab change events
async function handleTabChange(tabId) {
  try {
    const tab = await chrome.tabs.get(tabId);
    
    if (!tab.url || tab.url.startsWith('chrome://') || tab.url.startsWith('chrome-extension://')) {
      return; // Ignore chrome internal pages
    }

    currentTabId = tabId;
    currentUrl = tab.url;
    
    sendToApp({
      command: 'tab_changed',
      url: currentUrl,
      title: tab.title || '',
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Error handling tab change:', error);
  }
}

// Send message to Auto-Focus app
async function sendToApp(message) {
  if (!isConnectedToApp) {
    console.log('Not connected to app, cannot send message');
    return;
  }

  try {
    const response = await fetch(`http://localhost:${CONFIG.HTTP_PORT}/browser`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ...message,
        extensionId: chrome.runtime.id
      }),
      signal: AbortSignal.timeout(8000)
    });

    if (response.ok) {
      const result = await response.json();
      handleAppMessage(result);
    } else {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
  } catch (error) {
    console.error('Error sending to Auto-Focus app:', error);
    // Don't immediately disconnect on message failures
  }
}

// Handle messages from the app
function handleAppMessage(message) {
  switch (message.command) {
    case 'focus_state_changed':
      updateIcon(message.isFocusActive ? 'focus' : 'normal');
      break;
    case 'focus_session_started':
      updateIcon('active');
      break;
    case 'focus_session_ended':
      updateIcon('inactive');
      break;
    default:
      // Handle other message types if needed
      break;
  }
}

// Update extension icon
function updateIcon(state) {
  let iconPath = 'icons/icon';
  let title = 'Auto-Focus: Ready';

  switch (state) {
    case 'active':
      iconPath = 'icons/icon-active';
      title = 'Auto-Focus: Session Active';
      break;
    case 'focus':
      iconPath = 'icons/icon-focus';
      title = 'Auto-Focus: Focus URL Active';
      break;
    case 'inactive':
      iconPath = 'icons/icon-inactive';
      title = 'Auto-Focus: Inactive';
      break;
  }

  chrome.action.setIcon({
    path: {
      16: iconPath + '16.png',
      32: iconPath + '32.png',
      48: iconPath + '48.png',
      128: iconPath + '128.png'
    }
  });

  chrome.action.setTitle({ title });
}

// API for popup
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  switch (request.action) {
    case 'getCurrentState':
      sendResponse({
        currentUrl,
        isConnectedToApp,
        reconnectAttempts,
        lastSuccessfulConnection,
        connectionErrors: connectionErrors.slice(-3) // Last 3 errors for popup
      });
      break;
    case 'getConnectionDiagnostics':
      sendResponse({
        connectionStatus: isConnectedToApp ? 'connected' : 'disconnected',
        reconnectAttempts,
        maxReconnectAttempts: CONFIG.MAX_RECONNECT_ATTEMPTS,
        lastSuccessfulConnection,
        connectionErrors,
        heartbeatInterval: heartbeatInterval ? 'active' : 'inactive',
        extensionVersion: chrome.runtime.getManifest().version
      });
      break;
    case 'forceReconnect':
      console.log('🔄 Manual reconnection requested from popup');
      reconnectAttempts = 0;
      isConnectedToApp = false;
      if (heartbeatInterval) {
        clearInterval(heartbeatInterval);
        heartbeatInterval = null;
      }
      connectToApp();
      sendResponse({ status: 'reconnecting' });
      break;
    default:
      sendResponse({ error: 'Unknown action' });
  }
});