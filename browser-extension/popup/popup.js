// Auto-Focus Browser Extension - Popup Script

document.addEventListener('DOMContentLoaded', async () => {
  await initializePopup();
  setupEventListeners();
});

// Initialize popup with current state
async function initializePopup() {
  try {
    // Get current state from background script
    const response = await chrome.runtime.sendMessage({ action: 'getCurrentState' });
    
    updateUI(response);
    
    // Get current tab info
    const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
    if (tabs.length > 0) {
      updateCurrentTab(tabs[0]);
    }
    
  } catch (error) {
    console.error('Failed to initialize popup:', error);
    showError('Failed to load extension state');
  }
}

// Setup event listeners
function setupEventListeners() {
  // Add Current Site button
  document.getElementById('addCurrentSiteButton')?.addEventListener('click', async () => {
    try {
      const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
      if (tabs.length > 0) {
        const currentTab = tabs[0];
        const url = new URL(currentTab.url);
        const domain = url.hostname;
        
        // Send request to add this domain as a focus URL
        const response = await fetch('http://localhost:8942/browser', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            command: 'add_focus_url',
            domain: domain,
            name: domain,
            url: currentTab.url
          })
        });
        
        if (response.ok) {
          const result = await response.json();
          if (result.success) {
            showMessage('✅ Added ' + domain + ' as focus URL');
          } else {
            showMessage('❌ Failed to add: ' + (result.error || 'Unknown error'));
          }
        }
      }
    } catch (error) {
      showMessage('❌ Error: ' + error.message);
    }
  });
  
  // Open App button
  document.getElementById('openAppButton')?.addEventListener('click', () => {
    // Open Auto-Focus settings
    chrome.runtime.sendMessage({ action: 'openApp' });
    window.close();
  });
}

// Update UI with current state
function updateUI(state) {
  // Update connection status
  updateConnectionStatus(state.isConnectedToApp);
  
  // Update focus status
  updateFocusStatus(state.isFocusUrl, state.currentUrl);
  
  // Update status indicator
  updateStatusIndicator(state);
}

// Update current tab display
function updateCurrentTab(tab) {
  const tabUrl = document.getElementById('tabUrl');
  const tabStatus = document.getElementById('tabStatus');
  
  if (tabUrl) {
    const url = new URL(tab.url);
    tabUrl.textContent = url.hostname;
    tabUrl.title = tab.url;
  }
  
  if (tabStatus) {
    tabStatus.textContent = tab.title || 'Loading...';
  }
}

// Update connection status
function updateConnectionStatus(isConnected) {
  const connectionStatus = document.getElementById('connectionStatus');
  const connectionDot = connectionStatus?.querySelector('.connection-dot');
  const connectionText = connectionStatus?.querySelector('.connection-text');
  
  if (isConnected) {
    connectionDot?.classList.add('connected');
    connectionDot?.classList.remove('error');
    if (connectionText) {
      connectionText.textContent = 'Connected to Auto-Focus';
    }
  } else {
    connectionDot?.classList.remove('connected');
    connectionDot?.classList.add('error');
    if (connectionText) {
      connectionText.textContent = 'Auto-Focus app not running';
    }
  }
}

// Update focus status
function updateFocusStatus(isFocusUrl, currentUrl) {
  const focusStatus = document.getElementById('focusStatus');
  const focusIcon = document.getElementById('focusIndicator')?.querySelector('.focus-icon');
  const focusText = document.getElementById('focusIndicator')?.querySelector('.focus-text');
  
  if (isFocusUrl) {
    focusStatus?.classList.add('active');
    if (focusIcon) focusIcon.textContent = '🎯';
    if (focusText) focusText.textContent = 'Focus URL active';
  } else {
    focusStatus?.classList.remove('active');
    if (focusIcon) focusIcon.textContent = '⚪';
    if (focusText) focusText.textContent = 'Not a focus URL';
  }
}

// Update status indicator
function updateStatusIndicator(state) {
  const statusDot = document.querySelector('.status-dot');
  const statusText = document.querySelector('.status-text');
  
  if (!state.isConnectedToApp) {
    statusDot?.classList.add('error');
    statusDot?.classList.remove('warning');
    if (statusText) statusText.textContent = 'Disconnected';
  } else if (state.isFocusUrl) {
    statusDot?.classList.remove('error', 'warning');
    if (statusText) statusText.textContent = 'Focus Active';
  } else {
    statusDot?.classList.remove('error');
    statusDot?.classList.add('warning');
    if (statusText) statusText.textContent = 'Ready';
  }
}

// Show error message
function showError(message) {
  const container = document.querySelector('.container');
  const errorDiv = document.createElement('div');
  errorDiv.className = 'error-message';
  errorDiv.textContent = message;
  errorDiv.style.cssText = `
    padding: 12px;
    background: #ffe6e6;
    border: 1px solid #ffcccc;
    border-radius: 6px;
    color: #cc0000;
    font-size: 12px;
    margin-bottom: 16px;
  `;
  
  container?.insertBefore(errorDiv, container.firstChild);
  
  // Remove error after 5 seconds
  setTimeout(() => {
    errorDiv.remove();
  }, 5000);
}

// Show message to user
function showMessage(message) {
  const container = document.querySelector('.container');
  const messageDiv = document.createElement('div');
  messageDiv.className = 'success-message';
  messageDiv.textContent = message;
  messageDiv.style.cssText = `
    padding: 12px;
    background: #e6ffe6;
    border: 1px solid #ccffcc;
    border-radius: 6px;
    color: #008000;
    font-size: 12px;
    margin-bottom: 16px;
    text-align: center;
  `;
  
  container?.insertBefore(messageDiv, container.firstChild);
  
  // Remove message after 3 seconds
  setTimeout(() => {
    messageDiv.remove();
  }, 3000);
}

// Utility function to format URLs
function formatUrl(url) {
  try {
    const urlObj = new URL(url);
    return urlObj.hostname + (urlObj.pathname !== '/' ? urlObj.pathname : '');
  } catch {
    return url;
  }
}