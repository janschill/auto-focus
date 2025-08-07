// Auto-Focus Browser Extension - Background Service Worker
// Fixed version with proper Manifest V3 service worker handling

const CONFIG = {
  HTTP_PORT: 8942,
  HEARTBEAT_INTERVAL: 20, // 20 seconds (more frequent for better connection monitoring)
  MAX_RECONNECT_ATTEMPTS: 8, // Increased attempts
  RECONNECT_DELAY: 1500,
  LONG_RETRY_DELAY: 30000, // Reduced from 60s to 30s for faster recovery
  CONNECTION_TIMEOUT: 6000, // Reduced from 8s to 6s for faster failure detection
  HEARTBEAT_TIMEOUT: 10000 // Separate timeout for heartbeats
};

// Global state (will be lost when service worker suspends)
let isConnectedToApp = false;
let reconnectAttempts = 0;
let connectionErrors = [];
let lastSuccessfulConnection = null;
let initializationInProgress = false;
let pendingTabEvents = []; // Queue for tab events when disconnected
let isServiceWorkerActive = true;

// Service worker lifecycle detection
let lastActivityTime = Date.now();
const ACTIVITY_UPDATE_INTERVAL = 15000; // 15 seconds

// Update activity periodically to detect suspensions
setInterval(() => {
  const now = Date.now();
  const timeSinceLastActivity = now - lastActivityTime;
  
  // If more than 25 seconds have passed, we might have been suspended
  if (timeSinceLastActivity > 25000) {
    console.log(`Service worker may have been suspended (${Math.round(timeSinceLastActivity/1000)}s gap)`);
    isServiceWorkerActive = false;
    handleServiceWorkerReactivation();
  }
  
  lastActivityTime = now;
}, ACTIVITY_UPDATE_INTERVAL);

// Initialize extension
chrome.runtime.onInstalled.addListener((details) => {
  console.log('Auto-Focus extension installed/updated:', details.reason);
  initializeExtension();
  
  // Set up alarms for periodic tasks
  chrome.alarms.create('heartbeat', { periodInMinutes: CONFIG.HEARTBEAT_INTERVAL / 60 }); // Convert seconds to minutes
  chrome.alarms.create('connectionCheck', { periodInMinutes: 0.5 }); // 30 seconds
  chrome.alarms.create('activityTracker', { periodInMinutes: 0.25 }); // 15 seconds
});

chrome.runtime.onStartup.addListener(() => {
  console.log('Auto-Focus extension started');
  initializeExtension();
});

// Handle alarms for periodic tasks
chrome.alarms.onAlarm.addListener(async (alarm) => {
  lastActivityTime = Date.now(); // Update activity tracker
  console.log('Alarm triggered:', alarm.name);
  
  if (alarm.name === 'heartbeat') {
    await performHeartbeat();
  } else if (alarm.name === 'connectionCheck') {
    await checkConnection();
  } else if (alarm.name === 'activityTracker') {
    isServiceWorkerActive = true; // We're clearly active if alarms are firing
    await processPendingTabEvents(); // Process any queued tab events
  } else if (alarm.name === 'retryConnection') {
    console.log('Retrying connection from alarm...');
    reconnectAttempts = 0;
    await connectToApp();
  }
});

// Keep service worker alive during critical operations
async function keepAlive(operation) {
  const keepAliveInterval = setInterval(() => {
    chrome.runtime.getPlatformInfo(() => {
      // This keeps the service worker alive
    });
  }, 20000); // Every 20 seconds
  
  try {
    return await operation();
  } finally {
    clearInterval(keepAliveInterval);
  }
}

async function initializeExtension() {
  if (initializationInProgress) {
    console.log('Initialization already in progress, skipping...');
    return;
  }
  
  initializationInProgress = true;
  
  try {
    // Mark as active and reset activity time
    isServiceWorkerActive = true;
    lastActivityTime = Date.now();
    
    // Restore connection state
    await restoreConnectionState();
    
    // Start connection
    await connectToApp();
    
    // Start monitoring tabs
    startTabMonitoring();
    
    // Process any pending tab events from before suspension
    await processPendingTabEvents();
  } catch (error) {
    console.error('Failed to initialize extension:', error);
  } finally {
    initializationInProgress = false;
  }
}

// Handle service worker reactivation after suspension
async function handleServiceWorkerReactivation() {
  console.log('🔄 Service worker reactivated, re-initializing...');
  isServiceWorkerActive = true;
  
  // Re-initialize without marking as in progress (allow concurrent init)
  await restoreConnectionState();
  
  // If we're supposed to be connected but aren't, try to reconnect
  const state = await chrome.storage.local.get('af_connection_state');
  if (state.af_connection_state?.isConnectedToApp && !isConnectedToApp) {
    console.log('Expected to be connected but not connected, attempting reconnection');
    reconnectAttempts = 0;
    await connectToApp();
  }
  
  // Process any pending events
  await processPendingTabEvents();
}

// Save connection state before service worker suspends
async function saveConnectionState() {
  try {
    await chrome.storage.local.set({
      'af_connection_state': {
        isConnectedToApp,
        lastSuccessfulConnection,
        connectionErrors: connectionErrors.slice(-5),
        timestamp: Date.now(),
        pendingTabEvents: pendingTabEvents.slice(-10) // Save up to 10 pending events
      }
    });
    console.log('Connection state saved');
  } catch (error) {
    console.error('Failed to save connection state:', error);
  }
}

// Restore connection state
async function restoreConnectionState() {
  try {
    const result = await chrome.storage.local.get('af_connection_state');
    if (result.af_connection_state) {
      const state = result.af_connection_state;
      const timeSinceSave = Date.now() - state.timestamp;
      
      console.log(`Restoring state from ${Math.round(timeSinceSave/1000)}s ago`);
      
      // Restore state
      lastSuccessfulConnection = state.lastSuccessfulConnection;
      connectionErrors = state.connectionErrors || [];
      
      // Restore pending events if any
      if (state.pendingTabEvents && state.pendingTabEvents.length > 0) {
        pendingTabEvents = state.pendingTabEvents;
        console.log(`Restored ${pendingTabEvents.length} pending tab events`);
      }
      
      // Always try to reconnect after restoration
      isConnectedToApp = false;
      reconnectAttempts = 0;
    }
  } catch (error) {
    console.error('Failed to restore connection state:', error);
  }
}

// Connect to Auto-Focus HTTP server
async function connectToApp() {
  return keepAlive(async () => {
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
          connectionErrors: connectionErrors.slice(-5),
          lastSuccessfulConnection: lastSuccessfulConnection,
          serviceWorkerActive: isServiceWorkerActive,
          pendingEventsCount: pendingTabEvents.length
        }),
        signal: AbortSignal.timeout(CONFIG.CONNECTION_TIMEOUT)
      });

      const connectionTime = Date.now() - connectionStart;

      if (response.ok) {
        const result = await response.json();
        if (result.command === 'handshake_response') {
          isConnectedToApp = true;
          reconnectAttempts = 0;
          lastSuccessfulConnection = Date.now();
          connectionErrors = [];
          
          console.log(`✅ Connected to Auto-Focus app (${connectionTime}ms)`);
          console.log('📊 Connection established - app version:', result.appVersion);
          
          // Save successful connection state
          await saveConnectionState();
          
          // Send current tab info
          const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
          if (tabs.length > 0) {
            await handleTabChange(tabs[0].id);
          }
          
          // Process any pending tab events
          await processPendingTabEvents();
          
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
        connectionErrors = connectionErrors.slice(-10);
      }
      
      console.error(`❌ Connection attempt ${attemptNumber} failed:`, error.message);
      isConnectedToApp = false;
      
      // Save failed state
      await saveConnectionState();
      
      if (reconnectAttempts < CONFIG.MAX_RECONNECT_ATTEMPTS) {
        reconnectAttempts++;
        const delay = Math.min(
          CONFIG.RECONNECT_DELAY * Math.pow(1.5, reconnectAttempts - 1),
          15000 // Cap at 15 seconds
        );
        console.log(`⏳ Retrying connection in ${Math.round(delay/1000)}s... (${CONFIG.MAX_RECONNECT_ATTEMPTS - reconnectAttempts} attempts remaining)`);
        setTimeout(() => connectToApp(), delay);
      } else {
        console.error(`❌ Max reconnection attempts (${CONFIG.MAX_RECONNECT_ATTEMPTS}) reached`);
        console.log('🔄 Will retry connection in 30 seconds...');
        reconnectAttempts = 0;
        chrome.alarms.create('retryConnection', { delayInMinutes: 0.5 }); // 30 seconds
      }
    }
  });
}

// Check connection status
async function checkConnection() {
  const state = await chrome.storage.local.get('af_connection_state');
  if (state.af_connection_state) {
    const timeSinceLastSuccess = Date.now() - (state.af_connection_state.lastSuccessfulConnection || 0);
    
    // If no successful connection in last 2 minutes, try to reconnect
    if (timeSinceLastSuccess > 120000) {
      console.log('No recent successful connection, attempting to reconnect...');
      isConnectedToApp = false;
      reconnectAttempts = 0;
      await connectToApp();
    }
  } else {
    // No saved state, try to connect
    await connectToApp();
  }
}

// Perform heartbeat
async function performHeartbeat() {
  // Load current connection state
  const state = await chrome.storage.local.get('af_connection_state');
  if (!state.af_connection_state?.isConnectedToApp && !isConnectedToApp) {
    console.log('Not connected, skipping heartbeat');
    return;
  }
  
  try {
    const heartbeatStart = Date.now();
    const response = await fetch(`http://localhost:${CONFIG.HTTP_PORT}/browser`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        command: 'heartbeat',
        timestamp: Date.now(),
        extensionId: chrome.runtime.id,
        serviceWorkerActive: isServiceWorkerActive,
        pendingEventsCount: pendingTabEvents.length,
        connectionHealth: {
          state: 'connected',
          consecutiveFailures: 0,
          lastError: connectionErrors.length > 0 ? connectionErrors[connectionErrors.length - 1] : null,
          activityTime: lastActivityTime
        }
      }),
      signal: AbortSignal.timeout(CONFIG.HEARTBEAT_TIMEOUT)
    });
    
    const heartbeatTime = Date.now() - heartbeatStart;
    
    if (response.ok) {
      console.log(`💓 Heartbeat OK (${heartbeatTime}ms)`);
      isConnectedToApp = true;
      lastSuccessfulConnection = Date.now();
      await saveConnectionState();
      
      // Process pending events after successful heartbeat
      await processPendingTabEvents();
    } else {
      throw new Error(`HTTP ${response.status} ${response.statusText}`);
    }
  } catch (error) {
    console.error('💔 Heartbeat failed:', error.message);
    isConnectedToApp = false;
    await saveConnectionState();
    
    // Try to reconnect
    reconnectAttempts = 0;
    await connectToApp();
  }
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
    }
    // Don't notify when Chrome loses focus - let the app determine focus state
  });
}

// Handle tab change events
async function handleTabChange(tabId) {
  try {
    const tab = await chrome.tabs.get(tabId);
    
    if (!tab.url || tab.url.startsWith('chrome://') || tab.url.startsWith('chrome-extension://')) {
      return; // Ignore chrome internal pages
    }
    
    const tabEvent = {
      command: 'tab_changed',
      url: tab.url,
      title: tab.title || '',
      timestamp: Date.now(),
      tabId: tabId
    };
    
    // If not connected, queue the event
    if (!isConnectedToApp) {
      console.log('Not connected, queueing tab event:', tab.url);
      pendingTabEvents.push(tabEvent);
      
      // Keep only the latest 10 events to avoid memory issues
      if (pendingTabEvents.length > 10) {
        pendingTabEvents = pendingTabEvents.slice(-10);
      }
      
      // Save to storage
      await saveConnectionState();
      
      // Try to reconnect if not already attempting
      if (reconnectAttempts === 0) {
        await connectToApp();
      }
      return;
    }
    
    // Send immediately if connected
    await sendToApp(tabEvent);
  } catch (error) {
    console.error('Error handling tab change:', error);
  }
}

// Process pending tab events when reconnected
async function processPendingTabEvents() {
  if (pendingTabEvents.length === 0) {
    return;
  }
  
  if (!isConnectedToApp) {
    console.log('Cannot process pending events - not connected');
    return;
  }
  
  console.log(`Processing ${pendingTabEvents.length} pending tab events...`);
  
  // Process events in order
  const eventsToProcess = [...pendingTabEvents];
  pendingTabEvents = []; // Clear the queue
  
  for (const event of eventsToProcess) {
    try {
      await sendToApp(event);
      console.log(`✅ Processed pending event for ${event.url}`);
    } catch (error) {
      console.error(`❌ Failed to process pending event for ${event.url}:`, error);
      // Re-queue the event if it failed
      pendingTabEvents.push(event);
    }
  }
  
  // Save updated state
  await saveConnectionState();
  
  if (eventsToProcess.length > 0) {
    console.log(`Processed ${eventsToProcess.length - pendingTabEvents.length}/${eventsToProcess.length} pending events`);
  }
}

// Send message to Auto-Focus app
async function sendToApp(message) {
  // Check connection state from storage and local state
  const state = await chrome.storage.local.get('af_connection_state');
  if (!state.af_connection_state?.isConnectedToApp && !isConnectedToApp && message.command !== 'handshake') {
    console.log('Not connected to app, attempting to connect first');
    await connectToApp();
    
    // Re-check after connection attempt
    const newState = await chrome.storage.local.get('af_connection_state');
    if (!newState.af_connection_state?.isConnectedToApp && !isConnectedToApp) {
      console.log('Still not connected, cannot send message');
      throw new Error('Connection to Auto-Focus app failed');
    }
  }

  try {
    const response = await fetch(`http://localhost:${CONFIG.HTTP_PORT}/browser`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ...message,
        extensionId: chrome.runtime.id
      }),
      signal: AbortSignal.timeout(CONFIG.CONNECTION_TIMEOUT)
    });

    if (response.ok) {
      const result = await response.json();
      handleAppMessage(result);
      
      // Update last successful connection
      lastSuccessfulConnection = Date.now();
      await saveConnectionState();
    } else {
      throw new Error(`HTTP ${response.status} ${response.statusText}`);
    }
  } catch (error) {
    console.error('Error sending to Auto-Focus app:', error);
    
    // Mark as disconnected if send fails (except for handshake)
    if (message.command !== 'handshake') {
      isConnectedToApp = false;
      await saveConnectionState();
      
      // Re-queue the message if it wasn't a handshake
      if (message.command === 'tab_changed') {
        pendingTabEvents.push(message);
        if (pendingTabEvents.length > 10) {
          pendingTabEvents = pendingTabEvents.slice(-10);
        }
        console.log('Re-queued failed tab event');
      }
    }
    
    throw error; // Re-throw for caller to handle
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
  (async () => {
    switch (request.action) {
      case 'getCurrentState':
        const state = await chrome.storage.local.get('af_connection_state');
        const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
        sendResponse({
          currentUrl: tabs[0]?.url,
          isConnectedToApp: state.af_connection_state?.isConnectedToApp || isConnectedToApp,
          reconnectAttempts,
          lastSuccessfulConnection: state.af_connection_state?.lastSuccessfulConnection,
          connectionErrors: state.af_connection_state?.connectionErrors || [],
          pendingEventsCount: pendingTabEvents.length,
          serviceWorkerActive: isServiceWorkerActive,
          extensionVersion: chrome.runtime.getManifest().version
        });
        break;
        
      case 'getConnectionDiagnostics':
        const diagnosticState = await chrome.storage.local.get('af_connection_state');
        sendResponse({
          connectionStatus: (diagnosticState.af_connection_state?.isConnectedToApp || isConnectedToApp) ? 'connected' : 'disconnected',
          reconnectAttempts,
          maxReconnectAttempts: CONFIG.MAX_RECONNECT_ATTEMPTS,
          lastSuccessfulConnection: diagnosticState.af_connection_state?.lastSuccessfulConnection,
          connectionErrors: diagnosticState.af_connection_state?.connectionErrors || [],
          pendingEventsCount: pendingTabEvents.length,
          serviceWorkerActive: isServiceWorkerActive,
          extensionVersion: chrome.runtime.getManifest().version,
          config: {
            heartbeatInterval: CONFIG.HEARTBEAT_INTERVAL,
            connectionTimeout: CONFIG.CONNECTION_TIMEOUT
          }
        });
        break;
        
      case 'forceReconnect':
        console.log('🔄 Manual reconnection requested from popup');
        reconnectAttempts = 0;
        isConnectedToApp = false;
        pendingTabEvents = []; // Clear pending events on manual reconnect
        await connectToApp();
        sendResponse({ status: 'reconnecting' });
        break;
        
      case 'clearPendingEvents':
        console.log('🗑️ Clearing pending events requested from popup');
        pendingTabEvents = [];
        await saveConnectionState();
        sendResponse({ status: 'cleared', message: 'Pending events cleared' });
        break;
        
      default:
        sendResponse({ error: 'Unknown action' });
    }
  })();
  return true; // Keep message channel open for async response
});