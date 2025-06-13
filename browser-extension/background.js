// Auto-Focus Browser Extension - Background Service Worker
// Handles tab monitoring and communication with Auto-Focus native app

let currentTabId = null;
let currentUrl = null;
let focusUrls = [];
let isConnectedToApp = false;
let nativePort = null;
let reconnectAttempts = 0;
let maxReconnectAttempts = 10;
let heartbeatInterval = null;
let connectionHealth = {
  lastSuccessfulConnection: null,
  lastHeartbeat: null,
  consecutiveFailures: 0,
  connectionState: 'disconnected', // 'disconnected', 'connecting', 'connected', 'error'
  errorDetails: null
};
let extensionHealth = {
  version: chrome.runtime.getManifest().version,
  installationDate: null,
  lastUpdateCheck: null,
  errors: []
};

// Initialize extension
chrome.runtime.onInstalled.addListener((details) => {
  console.log('Auto-Focus extension installed/updated:', details);
  extensionHealth.installationDate = Date.now();
  
  if (details.reason === 'install') {
    console.log('First time installation detected');
    showWelcomeNotification();
  } else if (details.reason === 'update') {
    console.log('Extension updated from', details.previousVersion, 'to', extensionHealth.version);
    showUpdateNotification(details.previousVersion);
  }
  
  initializeExtension();
});

chrome.runtime.onStartup.addListener(() => {
  console.log('Auto-Focus extension started');
  initializeExtension();
});

// Handle extension suspension/revival
chrome.runtime.onSuspend.addListener(() => {
  console.log('Extension suspending - cleaning up');
  stopHeartbeat();
  connectionHealth.connectionState = 'suspended';
});

chrome.runtime.onSuspendCanceled.addListener(() => {
  console.log('Extension suspension canceled - reconnecting');
  initializeExtension();
});

// Initialize extension state
async function initializeExtension() {
  try {
    console.log('Initializing Auto-Focus extension...');
    connectionHealth.connectionState = 'initializing';
    
    // Load stored data
    await loadExtensionData();
    
    // Check extension health
    await performHealthCheck();

    // Connect to native app with retry
    connectToNativeApp();

    // Start monitoring tabs
    startTabMonitoring();
    
    // Set up periodic health monitoring
    startHealthMonitoring();
    
    console.log('Extension initialization complete');
  } catch (error) {
    console.error('Failed to initialize extension:', error);
    recordError('initialization_failed', error);
    connectionHealth.connectionState = 'error';
    connectionHealth.errorDetails = error.message;
    
    // Try again after delay
    setTimeout(() => {
      console.log('Retrying extension initialization...');
      initializeExtension();
    }, 5000);
  }
}

// Load stored extension data
async function loadExtensionData() {
  try {
    const result = await chrome.storage.sync.get(['focusUrls', 'extensionHealth', 'connectionHealth']);
    
    focusUrls = result.focusUrls || [];
    if (result.extensionHealth) {
      extensionHealth = { ...extensionHealth, ...result.extensionHealth };
    }
    if (result.connectionHealth) {
      connectionHealth = { ...connectionHealth, ...result.connectionHealth };
    }
    
    console.log('Loaded extension data:', { 
      focusUrlsCount: focusUrls.length,
      lastConnection: connectionHealth.lastSuccessfulConnection 
    });
  } catch (error) {
    console.error('Failed to load extension data:', error);
    recordError('data_load_failed', error);
  }
}

// Perform extension health check
async function performHealthCheck() {
  try {
    extensionHealth.lastUpdateCheck = Date.now();
    
    // Check if we have permissions
    const hasPermissions = await chrome.permissions.contains({
      permissions: ['tabs', 'storage'],
      origins: ['<all_urls>']
    });
    
    if (!hasPermissions) {
      throw new Error('Missing required permissions');
    }
    
    // Check if we can access tabs
    const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
    if (!tabs || tabs.length === 0) {
      console.warn('Cannot access current tabs - may need permission');
    }
    
    console.log('Extension health check passed');
  } catch (error) {
    console.error('Extension health check failed:', error);
    recordError('health_check_failed', error);
    throw error;
  }
}

// Record and persist errors
function recordError(type, error) {
  const errorRecord = {
    type,
    message: error.message || error.toString(),
    timestamp: Date.now(),
    stack: error.stack
  };
  
  extensionHealth.errors.push(errorRecord);
  
  // Keep only last 50 errors
  if (extensionHealth.errors.length > 50) {
    extensionHealth.errors = extensionHealth.errors.slice(-50);
  }
  
  // Persist to storage
  chrome.storage.sync.set({ extensionHealth }).catch(console.error);
  
  console.error('Recorded error:', errorRecord);
}

// Start periodic health monitoring
function startHealthMonitoring() {
  setInterval(async () => {
    try {
      // Check connection health
      if (connectionHealth.lastHeartbeat && 
          Date.now() - connectionHealth.lastHeartbeat > 60000) { // 1 minute
        console.warn('Connection health degraded - no recent heartbeat');
        if (connectionHealth.connectionState === 'connected') {
          connectionHealth.connectionState = 'degraded';
          attemptRecovery();
        }
      }
      
      // Persist health data
      await chrome.storage.sync.set({ connectionHealth, extensionHealth });
      
    } catch (error) {
      console.error('Health monitoring error:', error);
      recordError('health_monitoring_failed', error);
    }
  }, 30000); // Every 30 seconds
}

// Connect to Auto-Focus HTTP server
async function connectToNativeApp() {
  connectionHealth.connectionState = 'connecting';
  
  console.log(`Attempting to connect to Auto-Focus HTTP server... (attempt ${reconnectAttempts + 1}/${maxReconnectAttempts})`);
  
  try {
    // Check if Auto-Focus app might be running
    const isAppRunning = await checkIfAppIsRunning();
    if (!isAppRunning) {
      throw new Error('Auto-Focus app does not appear to be running');
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000); // 5 second timeout

    const response = await fetch('http://localhost:8942/browser', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        command: 'handshake',
        version: extensionHealth.version,
        extensionId: chrome.runtime.id,
        timestamp: Date.now(),
        healthData: {
          errors: extensionHealth.errors.slice(-5), // Last 5 errors
          consecutiveFailures: connectionHealth.consecutiveFailures
        }
      }),
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    if (response.ok) {
      const result = await response.json();
      console.log('Handshake response from Auto-Focus app:', result);

      if (result.command === 'handshake_response') {
        // Successful connection
        isConnectedToApp = true;
        reconnectAttempts = 0;
        connectionHealth.consecutiveFailures = 0;
        connectionHealth.connectionState = 'connected';
        connectionHealth.lastSuccessfulConnection = Date.now();
        connectionHealth.errorDetails = null;
        
        console.log('✅ Connected to Auto-Focus HTTP server');
        
        // Start heartbeat to maintain connection
        startHeartbeat();
        
        // Show success notification if we had previous failures
        if (connectionHealth.consecutiveFailures > 0) {
          showConnectionRestoredNotification();
        }
        
        // Process any queued messages
        setTimeout(() => {
          processQueuedMessages();
        }, 1000); // Small delay to ensure connection is stable
        
        return;
      }
    }

    throw new Error(`Handshake failed: ${response.status} ${response.statusText}`);

  } catch (error) {
    console.error('Failed to connect to Auto-Focus app:', error);
    recordError('connection_failed', error);
    
    isConnectedToApp = false;
    connectionHealth.consecutiveFailures++;
    connectionHealth.connectionState = 'error';
    connectionHealth.errorDetails = error.message;
    
    // Stop heartbeat on connection failure
    stopHeartbeat();

    // Determine retry strategy based on error type
    const shouldRetry = shouldRetryConnection(error);
    
    if (shouldRetry && reconnectAttempts < maxReconnectAttempts) {
      reconnectAttempts++;
      const delay = calculateRetryDelay(reconnectAttempts, error);
      
      console.log(`Retrying connection in ${delay}ms... (${getErrorCategory(error)})`);
      setTimeout(connectToNativeApp, delay);
    } else {
      console.error('Max reconnection attempts reached or permanent error detected.');
      handlePermanentConnectionFailure(error);
    }
  }
}

// Check if Auto-Focus app is likely running
async function checkIfAppIsRunning() {
  try {
    // Try a quick HEAD request to see if server is responding
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 2000);
    
    const response = await fetch('http://localhost:8942/', {
      method: 'HEAD',
      signal: controller.signal
    });
    
    clearTimeout(timeoutId);
    return response.status !== 0; // Any response means server is running
  } catch (error) {
    return false;
  }
}

// Determine if we should retry based on error type
function shouldRetryConnection(error) {
  const errorMessage = error.message.toLowerCase();
  
  // Don't retry on permanent errors
  if (errorMessage.includes('port') && errorMessage.includes('denied')) {
    return false; // Permission denied
  }
  
  if (errorMessage.includes('network error') || 
      errorMessage.includes('fetch')) {
    return false; // Network stack issues
  }
  
  // Retry on temporary errors
  return true;
}

// Calculate retry delay with exponential backoff
function calculateRetryDelay(attempt, error) {
  const baseDelay = 2000; // 2 seconds
  const maxDelay = 60000; // 1 minute
  
  // Different strategies based on error type
  const errorCategory = getErrorCategory(error);
  
  let delay;
  switch (errorCategory) {
    case 'app_not_running':
      delay = Math.min(10000 * attempt, maxDelay); // Slower retry for app not running
      break;
    case 'network':
      delay = Math.min(baseDelay * Math.pow(1.5, attempt - 1), maxDelay);
      break;
    default:
      delay = Math.min(baseDelay * Math.pow(2, attempt - 1), maxDelay);
  }
  
  return delay;
}

// Categorize error types
function getErrorCategory(error) {
  const message = error.message.toLowerCase();
  
  if (message.includes('app does not appear to be running') ||
      message.includes('connection refused') ||
      message.includes('econnrefused')) {
    return 'app_not_running';
  }
  
  if (message.includes('timeout') || message.includes('aborted')) {
    return 'timeout';
  }
  
  if (message.includes('network') || message.includes('fetch')) {
    return 'network';
  }
  
  return 'unknown';
}

// Handle permanent connection failure
function handlePermanentConnectionFailure(error) {
  connectionHealth.connectionState = 'permanently_failed';
  
  const errorCategory = getErrorCategory(error);
  
  if (errorCategory === 'app_not_running') {
    showAppNotRunningNotification();
  } else {
    showConnectionFailedNotification(error);
  }
  
  // Reset attempts so we can try again later if user takes action
  reconnectAttempts = 0;
  
  // Schedule a retry in 5 minutes
  setTimeout(() => {
    console.log('Attempting recovery after permanent failure...');
    connectToNativeApp();
  }, 300000); // 5 minutes
}

// Heartbeat to detect connection loss
function startHeartbeat() {
  stopHeartbeat(); // Clear any existing heartbeat
  
  heartbeatInterval = setInterval(async () => {
    if (isConnectedToApp) {
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 10000); // 10 second timeout
        
        const response = await fetch('http://localhost:8942/browser', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            command: 'heartbeat',
            timestamp: Date.now(),
            connectionHealth: {
              state: connectionHealth.connectionState,
              consecutiveFailures: connectionHealth.consecutiveFailures
            }
          }),
          signal: controller.signal
        });
        
        clearTimeout(timeoutId);
        
        if (!response.ok) {
          throw new Error(`Heartbeat failed: ${response.status}`);
        }
        
        connectionHealth.lastHeartbeat = Date.now();
        console.log('Heartbeat successful');
        
      } catch (error) {
        console.error('Heartbeat failed, connection lost:', error);
        recordError('heartbeat_failed', error);
        
        isConnectedToApp = false;
        connectionHealth.connectionState = 'lost';
        stopHeartbeat();
        
        // Reset reconnect attempts and try to reconnect
        reconnectAttempts = 0;
        connectToNativeApp();
      }
    }
  }, 30000); // Heartbeat every 30 seconds
}

function stopHeartbeat() {
  if (heartbeatInterval) {
    clearInterval(heartbeatInterval);
    heartbeatInterval = null;
  }
}

// Recovery attempt function
async function attemptRecovery() {
  console.log('Attempting connection recovery...');
  
  try {
    // First try a simple heartbeat
    const isAlive = await checkIfAppIsRunning();
    if (isAlive) {
      console.log('App appears to be running, attempting reconnection...');
      reconnectAttempts = 0;
      connectToNativeApp();
    } else {
      console.log('App not responding, will retry later');
      connectionHealth.connectionState = 'app_not_running';
    }
  } catch (error) {
    console.error('Recovery attempt failed:', error);
    recordError('recovery_failed', error);
  }
}

// Notification functions
function showWelcomeNotification() {
  if (chrome.notifications) {
    chrome.notifications.create('welcome', {
      type: 'basic',
      iconUrl: 'icons/icon48.png',
      title: 'Auto-Focus Extension Installed',
      message: 'The Auto-Focus browser extension is now active. Make sure the Auto-Focus app is running for full functionality.'
    });
  }
}

function showUpdateNotification(previousVersion) {
  if (chrome.notifications) {
    chrome.notifications.create('updated', {
      type: 'basic',
      iconUrl: 'icons/icon48.png',
      title: 'Auto-Focus Extension Updated',
      message: `Updated from v${previousVersion} to v${extensionHealth.version}. Reconnecting to Auto-Focus app...`
    });
  }
}

function showConnectionRestoredNotification() {
  if (chrome.notifications) {
    chrome.notifications.create('connected', {
      type: 'basic',
      iconUrl: 'icons/icon48.png',
      title: 'Auto-Focus Connected',
      message: 'Successfully reconnected to Auto-Focus app. Browser focus tracking is now active.'
    });
  }
}

function showAppNotRunningNotification() {
  if (chrome.notifications) {
    chrome.notifications.create('app-not-running', {
      type: 'basic',
      iconUrl: 'icons/icon48.png',
      title: 'Auto-Focus App Not Running',
      message: 'Please start the Auto-Focus app to enable browser focus tracking. The extension will automatically reconnect.',
      buttons: [
        { title: 'Retry Connection' },
        { title: 'Open App Store' }
      ]
    });
  }
}

function showConnectionFailedNotification(error) {
  if (chrome.notifications) {
    const message = getErrorCategory(error) === 'timeout' 
      ? 'Connection timed out. Check if Auto-Focus app is running and try again.'
      : 'Failed to connect to Auto-Focus app. Please check if the app is running.';
      
    chrome.notifications.create('connection-failed', {
      type: 'basic',
      iconUrl: 'icons/icon48.png',
      title: 'Auto-Focus Connection Failed',
      message: message,
      buttons: [{ title: 'Retry Now' }]
    });
  }
}

// Handle notification clicks
if (chrome.notifications) {
  chrome.notifications.onButtonClicked.addListener((notificationId, buttonIndex) => {
    if (notificationId === 'app-not-running') {
      if (buttonIndex === 0) { // Retry Connection
        reconnectAttempts = 0;
        connectToNativeApp();
      } else if (buttonIndex === 1) { // Open App Store
        chrome.tabs.create({ url: 'https://apps.apple.com/app/auto-focus/id1234567890' }); // Replace with actual App Store URL
      }
    } else if (notificationId === 'connection-failed' && buttonIndex === 0) { // Retry Now
      reconnectAttempts = 0;
      connectToNativeApp();
    }
    
    chrome.notifications.clear(notificationId);
  });

  chrome.notifications.onClicked.addListener((notificationId) => {
    if (notificationId === 'app-not-running' || notificationId === 'connection-failed') {
      reconnectAttempts = 0;
      connectToNativeApp();
    }
    chrome.notifications.clear(notificationId);
  });
}

// Handle messages from native app
function handleNativeMessage(message) {
  switch (message.command) {
    case 'focus_state_changed':
      console.log('Focus state changed:', message.isFocusActive);
      updateIcon(message.isFocusActive ? 'focus' : 'normal');
      break;

    case 'focus_session_started':
      console.log('Focus session started in app');
      updateIcon('active');
      break;

    case 'focus_session_ended':
      console.log('Focus session ended in app');
      updateIcon('inactive');
      break;

    case 'handshake_response':
      console.log('Handshake successful with app');
      break;

    default:
      console.log('Unknown message from app:', message);
  }
}

// Start monitoring tab changes
function startTabMonitoring() {
  // Listen for tab activation (switching between tabs)
  chrome.tabs.onActivated.addListener(async (activeInfo) => {
    await handleTabChange(activeInfo.tabId);
  });

  // Listen for tab updates (URL changes within same tab)
  chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
    if (changeInfo.url && tab.active) {
      await handleTabChange(tabId);
    }
  });

  // Listen for window focus changes
  chrome.windows.onFocusChanged.addListener(async (windowId) => {
    console.log('Window focus changed:', windowId);
    if (windowId !== chrome.windows.WINDOW_ID_NONE) {
      const tabs = await chrome.tabs.query({ active: true, windowId });
      if (tabs.length > 0) {
        console.log('Chrome regained focus, checking current tab');
        await handleTabChange(tabs[0].id, true); // Force immediate check
      }
    } else {
      console.log('Chrome lost focus - notifying app');
      // Chrome lost focus - send update to app
      sendToNativeApp({
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
async function handleTabChange(tabId, forcedByFocus = false) {
  try {
    const tab = await chrome.tabs.get(tabId);

    if (!tab.url || tab.url.startsWith('chrome://') || tab.url.startsWith('chrome-extension://')) {
      return; // Ignore chrome internal pages
    }

    currentTabId = tabId;
    currentUrl = tab.url;

    console.log('Tab changed to:', currentUrl, forcedByFocus ? '(due to Chrome focus)' : '');

    // Just send the URL to the app - let the app decide if it's a focus URL
    sendToNativeApp({
      command: 'tab_changed',
      url: currentUrl,
      title: tab.title || '',
      timestamp: Date.now(),
      forcedByFocus: forcedByFocus // Add flag to indicate this was triggered by browser focus
    });

  } catch (error) {
    console.error('Error handling tab change:', error);
  }
}

// Check if URL matches any focus URLs
function checkIfFocusUrl(url) {
  if (!url || focusUrls.length === 0) {
    return false;
  }

  try {
    const urlObj = new URL(url);
    const domain = urlObj.hostname;
    const fullUrl = url.toLowerCase();

    return focusUrls.some(focusUrl => {
      const pattern = focusUrl.domain.toLowerCase();

      switch (focusUrl.matchType) {
        case 'exact':
          return fullUrl === pattern;
        case 'domain':
          return domain === pattern || domain.endsWith('.' + pattern);
        case 'contains':
          return fullUrl.includes(pattern);
        default:
          return domain.includes(pattern);
      }
    });
  } catch (error) {
    console.error('Error checking focus URL:', error);
    return false;
  }
}

// Send message to Auto-Focus HTTP server with retry logic
async function sendToNativeApp(message, retryCount = 0) {
  const maxRetries = 3;
  
  try {
    if (!isConnectedToApp && retryCount === 0) {
      console.log('Not connected to app, attempting reconnection before sending message');
      await connectToNativeApp();
      if (!isConnectedToApp) {
        throw new Error('Unable to establish connection to Auto-Focus app');
      }
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 8000); // 8 second timeout

    const response = await fetch('http://localhost:8942/browser', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        ...message,
        extensionId: chrome.runtime.id,
        retryCount
      }),
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    if (response.ok) {
      const result = await response.json();
      console.log('Response from Auto-Focus app:', result);
      handleNativeMessage(result);
      
      // Reset connection health on successful message
      if (connectionHealth.consecutiveFailures > 0) {
        connectionHealth.consecutiveFailures = 0;
        connectionHealth.connectionState = 'connected';
      }
      
    } else {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

  } catch (error) {
    console.error(`Error sending to Auto-Focus app (attempt ${retryCount + 1}):`, error);
    recordError('message_send_failed', error);
    
    connectionHealth.consecutiveFailures++;
    
    // Determine if we should retry
    if (retryCount < maxRetries && shouldRetryMessage(error)) {
      const delay = Math.min(1000 * Math.pow(2, retryCount), 5000); // Max 5 second delay
      console.log(`Retrying message in ${delay}ms...`);
      
      setTimeout(() => {
        sendToNativeApp(message, retryCount + 1);
      }, delay);
      
    } else {
      // Max retries reached or permanent error
      console.error('Failed to send message after retries, marking as disconnected');
      isConnectedToApp = false;
      connectionHealth.connectionState = 'error';
      
      // For critical messages (like tab changes), queue them for later
      if (isCriticalMessage(message)) {
        queueMessageForLater(message);
      }
      
      // Attempt to reconnect
      if (shouldAttemptReconnection(error)) {
        setTimeout(() => {
          console.log('Attempting reconnection after message failure...');
          reconnectAttempts = 0;
          connectToNativeApp();
        }, 2000);
      }
    }
  }
}

// Determine if we should retry a message based on error
function shouldRetryMessage(error) {
  const message = error.message.toLowerCase();
  
  // Don't retry on permanent errors
  if (message.includes('400') || message.includes('404')) {
    return false; // Bad request or not found
  }
  
  // Retry on temporary errors
  return message.includes('timeout') || 
         message.includes('500') || 
         message.includes('502') || 
         message.includes('503') ||
         message.includes('aborted') ||
         message.includes('fetch');
}

// Check if a message is critical and should be queued
function isCriticalMessage(message) {
  return message.command === 'tab_changed' || 
         message.command === 'browser_lost_focus';
}

// Queue critical messages for retry when connection is restored
let messageQueue = [];

function queueMessageForLater(message) {
  messageQueue.push({
    ...message,
    queuedAt: Date.now()
  });
  
  // Keep only last 10 messages
  if (messageQueue.length > 10) {
    messageQueue = messageQueue.slice(-10);
  }
  
  console.log(`Queued message: ${message.command}`);
}

// Process queued messages when connection is restored
async function processQueuedMessages() {
  if (messageQueue.length === 0) return;
  
  console.log(`Processing ${messageQueue.length} queued messages...`);
  
  const messages = [...messageQueue];
  messageQueue = [];
  
  for (const message of messages) {
    // Skip old messages (older than 5 minutes)
    if (Date.now() - message.queuedAt > 300000) {
      console.log(`Skipping old queued message: ${message.command}`);
      continue;
    }
    
    try {
      await sendToNativeApp(message);
      // Small delay between messages
      await new Promise(resolve => setTimeout(resolve, 100));
    } catch (error) {
      console.error('Failed to process queued message:', error);
    }
  }
}

// Check if we should attempt reconnection based on error
function shouldAttemptReconnection(error) {
  const message = error.message.toLowerCase();
  
  // Don't reconnect on client-side errors
  if (message.includes('400') || message.includes('401') || message.includes('403')) {
    return false;
  }
  
  return true;
}

// Update extension icon based on state
function updateIcon(state) {
  let iconPath;
  let title;

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
      title = 'Auto-Focus: Focus URL Active';
    case 'normal':
    default:
      iconPath = 'icons/icon';
      title = 'Auto-Focus: Ready';
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

// Expose API for popup
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  switch (request.action) {
    case 'getCurrentState':
      sendResponse({
        currentUrl,
        isConnectedToApp,
        focusUrls,
        isFocusUrl: checkIfFocusUrl(currentUrl)
      });
      break;

    case 'testFocusUrl':
      sendResponse({
        isFocusUrl: checkIfFocusUrl(request.url)
      });
      break;

    default:
      sendResponse({ error: 'Unknown action' });
  }
});
