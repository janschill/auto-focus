// Auto-Focus Browser Extension - Popup Script
// Simplified version

document.addEventListener('DOMContentLoaded', async () => {
  await initializePopup();
  setupEventListeners();

  // Refresh connection state periodically
  setInterval(async () => {
    try {
      const response = await chrome.runtime.sendMessage({ action: 'getCurrentState' });
      updateUI(response);
    } catch (error) {
      console.error('Failed to refresh state:', error);
    }
  }, 2000); // Refresh every 2 seconds
});

// Initialize popup with current state
async function initializePopup() {
  try {
    // Display version from manifest
    const manifest = chrome.runtime.getManifest();
    const versionElement = document.getElementById('versionText');
    if (versionElement && manifest.version) {
      versionElement.textContent = `v${manifest.version}`;
    }

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
        } else {
          showMessage('❌ Cannot connect to Auto-Focus app. Make sure it\'s running.');
        }
      }
    } catch (error) {
      showMessage('❌ Error: ' + error.message);
    }
  });

  // Reconnect button
  document.getElementById('reconnectButton')?.addEventListener('click', async () => {
    const reconnectButton = document.getElementById('reconnectButton');
    const connectionText = document.getElementById('connectionText');
    const connectionDot = document.getElementById('connectionDot');

    if (reconnectButton && connectionText) {
      reconnectButton.disabled = true;
      connectionText.textContent = 'Reconnecting...';
      connectionDot?.classList.add('connecting');
      connectionDot?.classList.remove('error');

      try {
        // Send message to background script to reconnect
        await chrome.runtime.sendMessage({ action: 'forceReconnect' });

        // Wait a moment and refresh state
        setTimeout(async () => {
          const response = await chrome.runtime.sendMessage({ action: 'getCurrentState' });
          updateUI(response);
          reconnectButton.disabled = false;
        }, 1500);
      } catch (error) {
        console.error('Reconnect failed:', error);
        connectionText.textContent = 'Reconnection failed';
        connectionDot?.classList.remove('connecting');
        connectionDot?.classList.add('error');
        reconnectButton.disabled = false;
      }
    }
  });
}

// Update UI with current state
function updateUI(state) {
  updateConnectionStatus(state.isConnectedToApp, {
    reconnectAttempts: state.reconnectAttempts || 0,
    maxReconnectAttempts: 15,
    connectionErrors: state.connectionErrors || []
  });
  updateCurrentUrl(state.currentUrl);
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
  const connectionDot = document.getElementById('connectionDot');
  const connectionText = document.getElementById('connectionText');
  const reconnectButton = document.getElementById('reconnectButton');

  if (isConnected) {
    connectionDot?.classList.add('connected');
    connectionDot?.classList.remove('error', 'connecting');

    if (connectionText) {
      connectionText.textContent = 'Connected to Auto-Focus';
    }

    if (reconnectButton) {
      reconnectButton.style.display = 'none';
    }
  } else {
    connectionDot?.classList.remove('connected');
    connectionDot?.classList.add('error');
    connectionDot?.classList.remove('connecting');

    if (connectionText) {
      if (diagnostics?.reconnectAttempts > 0) {
        connectionText.textContent = `Reconnecting... (${diagnostics.reconnectAttempts}/${diagnostics.maxReconnectAttempts})`;
        connectionDot?.classList.add('connecting');
        connectionDot?.classList.remove('error');
      } else {
        connectionText.textContent = 'Not connected to Auto-Focus app';
      }
    }

    // Show reconnect button when disconnected
    if (reconnectButton) {
      reconnectButton.style.display = 'flex';
    }
  }

  // Add diagnostics info if available
  if (diagnostics?.connectionErrors?.length > 0) {
    const lastError = diagnostics.connectionErrors[diagnostics.connectionErrors.length - 1];
    console.log('Last connection error:', lastError);
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
