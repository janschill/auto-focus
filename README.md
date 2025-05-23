# Auto-Focus

Automatically enable Do Not Disturb mode when you're in deep work.

Auto-Focus periodically checks what application is in the front and enables Do Not Disturb mode after 12 minutes of focused work in your chosen applications. When you switch to non-work apps, it gives you a buffer period before re-enabling notifications.

## How Does It Work?

Auto-Focus runs as a menu bar app that monitors which application is currently active. When you're using one of your designated focus applications (like VSCode, Xcode, or any other app you choose), it starts a timer. Once you've been focused for 12 minutes (configurable), it automatically enables Do Not Disturb mode.

To prevent losing focus during quick context switches (like checking documentation), Auto-Focus includes a configurable buffer period. This means your focus session won't end immediately when you switch apps - you have a grace period to switch back to your work.

## Getting Started

1. Download the latest version of Auto-Focus from the releases page
2. Install the required Shortcut:
   - Open the Shortcuts folder in the downloaded DMG and install the Shortcut
   - or later through Settings of the app iteself
3. Launch Auto-Focus and configure your focus applications
4. Enjoy your uninterrupted work sessions! 🚀

## Features

- **Automatic Focus Detection**: Detects when you're in deep work and enables focus mode automatically
- **Smart Buffer**: Configurable buffer time prevents losing focus during quick switches
- **Focus Insights**: Track your focus sessions and productivity patterns
- **Menu Bar Interface**: Quick access to your focus status and settings
- **Multiple Apps Support**: Choose which applications should trigger focus mode
- **Configurable Thresholds**: Customize how long before focus mode activates

## Future Plans

### Export/Import of Data

- Maybe use the cloud, maybe not

### Auto-Focus+

- Hide some features behind a paywall

### More Integrations

- **Slack Integration**: Set Slack status automatically and manage notifications
- **Calendar Integration**: Respect your meeting schedule and adjust focus mode accordingly
- **Browser Extension**: Detect protective websites
- **More Focus Providers**: Support for other focus/DND implementations beyond macOS Focus

### Enhanced Detection

- **Activity Detection**: Smarter detection of actual work vs. idle time
- **Context Awareness**: Better understanding of work contexts and patterns
- **Custom Rules**: Allow users to create their own rules for when to enable/disable focus mode
