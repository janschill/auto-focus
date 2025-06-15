// Auto-Focus Browser Extension - Content Script
// Minimal content script for page interaction if needed

(function() {
  'use strict';

  console.log('boop')
  // Track page visibility changes
  let isVisible = !document.hidden;
  let lastActivity = Date.now();

  // Listen for visibility changes
  document.addEventListener('visibilitychange', () => {
    isVisible = !document.hidden;

    if (isVisible) {
      lastActivity = Date.now();
      notifyBackgroundScript('page_visible');
    } else {
      notifyBackgroundScript('page_hidden');
    }
  });

  // Track user activity on the page
  ['mousedown', 'mousemove', 'keypress', 'scroll', 'touchstart'].forEach(event => {
    document.addEventListener(event, () => {
      if (isVisible) {
        lastActivity = Date.now();
      }
    }, { passive: true });
  });

  // Send periodic activity updates
  setInterval(() => {
    if (isVisible && Date.now() - lastActivity < 30000) { // Active within last 30 seconds
      notifyBackgroundScript('page_active');
    }
  }, 15000); // Check every 15 seconds

  // Notify background script of events
  function notifyBackgroundScript(event) {
    chrome.runtime.sendMessage({
      action: 'content_event',
      event: event,
      url: window.location.href,
      timestamp: Date.now()
    }).catch(() => {
      // Extension might be reloading, ignore errors
    });
  }

  // Initial page load notification
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      notifyBackgroundScript('page_loaded');
    });
  } else {
    notifyBackgroundScript('page_loaded');
  }
})();
