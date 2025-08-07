// Auto-Focus Browser Extension - Popup Script
// Simplified version

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

  // Reconnect button
  document.getElementById('reconnectButton')?.addEventListener('click', async () => {
    try {
      const response = await chrome.runtime.sendMessage({ action: 'forceReconnect' });
      if (response?.status === 'reconnecting') {
        showMessage('🔄 Attempting to reconnect...');
        // Refresh the popup state after a short delay
        setTimeout(() => {
          initializePopup();
        }, 2000);
      }
    } catch (error) {
      showMessage('❌ Reconnection failed: ' + error.message);
    }
  });
}

// Update UI with current state
function updateUI(state) {
  updateConnectionStatus(state.isConnectedToApp, {
    reconnectAttempts: state.reconnectAttempts || 0,
    maxReconnectAttempts: 8,
    connectionErrors: state.connectionErrors || [],
    pendingEventsCount: state.pendingEventsCount || 0,
    serviceWorkerActive: state.serviceWorkerActive || false
  });
  updateCurrentUrl(state.currentUrl);
  updateVersionInfo(state.extensionVersion);
  updateDiagnostics(state);
}

// Update current tab display
function updateCurrentTab(tab) {
  const tabUrl = document.getElementById('tabUrl');
  const tabStatus = document.getElementById('tabStatus');
  
  if (tabUrl) {
    try {
      const url = new URL(tab.url);
      tabUrl.textContent = url.hostname;
      tabUrl.title = tab.url;
    } catch {
      tabUrl.textContent = 'Invalid URL';
    }
  }
  
  if (tabStatus) {
    tabStatus.textContent = tab.title || 'Loading...';
  }
}

// Update current URL display
function updateCurrentUrl(url) {
  if (url) {
    try {
      const urlObj = new URL(url);
      const domain = urlObj.hostname;
      document.getElementById('tabUrl').textContent = domain;
    } catch {
      // Invalid URL
    }
  }
}

// Update connection status
function updateConnectionStatus(isConnected, diagnostics = null) {
  const connectionStatus = document.getElementById('connectionStatus');
  const connectionDot = connectionStatus?.querySelector('.connection-dot');
  const connectionText = connectionStatus?.querySelector('.connection-text');
  const connectionDetails = document.getElementById('connectionDetails');
  const statusDot = document.querySelector('.status-dot');
  const statusText = document.querySelector('.status-text');
  const reconnectButton = document.getElementById('reconnectButton');
  
  if (isConnected) {
    connectionDot?.classList.add('connected');
    connectionDot?.classList.remove('error');
    statusDot?.classList.remove('error');
    reconnectButton.style.display = 'none';
    
    if (connectionText) {
      connectionText.textContent = 'Connected to Auto-Focus';
    }
    if (statusText) {
      statusText.textContent = 'Ready';
    }
    if (connectionDetails) {
      connectionDetails.style.display = 'none';
    }
  } else {
    connectionDot?.classList.remove('connected');
    connectionDot?.classList.add('error');
    statusDot?.classList.add('error');
    reconnectButton.style.display = 'block';
    
    if (connectionText) {
      if (diagnostics?.reconnectAttempts > 0) {
        connectionText.textContent = `Reconnecting... (${diagnostics.reconnectAttempts}/${diagnostics.maxReconnectAttempts})`;
      } else {
        connectionText.textContent = 'Auto-Focus app not running';
      }
    }
    if (statusText) {
      statusText.textContent = 'Disconnected';
    }
    
    // Show connection details for disconnected state
    if (connectionDetails && diagnostics) {
      const detailText = connectionDetails.querySelector('.detail-text');
      if (detailText) {
        const pendingCount = diagnostics.pendingEventsCount || 0;
        const lastError = diagnostics.connectionErrors?.slice(-1)[0];
        
        let details = [];
        if (pendingCount > 0) {
          details.push(`${pendingCount} pending events`);
        }
        if (lastError) {
          const timeSince = Math.round((Date.now() - lastError.timestamp) / 1000);
          details.push(`Last error: ${timeSince}s ago`);
        }
        
        if (details.length > 0) {
          detailText.textContent = details.join(' • ');
          connectionDetails.style.display = 'block';
        } else {
          connectionDetails.style.display = 'none';
        }
      }
    }
  }
  
  // Add diagnostics info if available
  if (diagnostics?.connectionErrors?.length > 0) {
    const lastError = diagnostics.connectionErrors[diagnostics.connectionErrors.length - 1];
    console.log('Last connection error:', lastError);
  }
}

// Update version info
function updateVersionInfo(version) {
  const versionElement = document.getElementById('versionInfo');
  if (versionElement && version) {
    versionElement.textContent = `v${version}`;
  }
}

// Update diagnostics display
function updateDiagnostics(state) {
  const diagnostics = document.getElementById('diagnostics');
  const pendingEventsCount = document.getElementById('pendingEventsCount');
  const serviceWorkerStatus = document.getElementById('serviceWorkerStatus');
  
  // Show diagnostics if there are issues
  const shouldShowDiagnostics = !state.isConnectedToApp || 
                                (state.pendingEventsCount && state.pendingEventsCount > 0) ||
                                !state.serviceWorkerActive;
  
  if (diagnostics) {
    diagnostics.style.display = shouldShowDiagnostics ? 'block' : 'none';
  }
  
  if (pendingEventsCount) {
    pendingEventsCount.textContent = state.pendingEventsCount || '0';
  }
  
  if (serviceWorkerStatus) {
    serviceWorkerStatus.textContent = state.serviceWorkerActive ? 'Active' : 'Suspended';
    serviceWorkerStatus.style.color = state.serviceWorkerActive ? '#008000' : '#cc6600';
  }
}

// Show error message
function showError(message) {
  showMessage(message, 'error');
}

// Show message to user
function showMessage(message, type = 'success') {
  const container = document.querySelector('.container');
  const messageDiv = document.createElement('div');
  messageDiv.className = `${type}-message`;
  messageDiv.textContent = message;
  
  const styles = type === 'error' ? {
    background: '#ffe6e6',
    border: '1px solid #ffcccc',
    color: '#cc0000'
  } : {
    background: '#e6ffe6',
    border: '1px solid #ccffcc',
    color: '#008000'
  };
  
  messageDiv.style.cssText = `
    padding: 12px;
    background: ${styles.background};
    border: ${styles.border};
    border-radius: 6px;
    color: ${styles.color};
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