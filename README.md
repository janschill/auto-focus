# auto-focus

Disable notifications when you are *in the flow*.

`auto-focus` detects if you have been in VSCode for at least 12 minutes and will stop notifications from coming in.

## How Does It Work?

Using osascript the Go script will ask every second what application is in the front. If the application is VSCode it will start/increment a timer. As soon as another application is in front, it will stop and reset the timer.
If the timer reaches 12 minutes, it will use a combination of osascript and AppleScript to set a Focus profile.
The Go script is launched as a LaunchAgent to start on boot.

## Getting Started

1. Compile the code

    ```sh
    go build -o auto-focus main.go
    ```

2. Set up a macOS Focus profile and configure the applications that are *mission critical* and you still want to receive notifications from. I allow the Zoom client, as it sends me reminders when a meeting is about to start.
3. Update the profile name in `enableFocus.scpt` and `disableFocus.scpt` with the profile you just created.
4. Update the `plist` file with your computer's username.
5. Copy the `plist` file to `~/Library/LaunchAgents`

    ```sh
    cp com.jschill.auto-focus.plist ~/Library/LaunchAgents
    ```

6. Load your new LaunchAgent

    ```sh
    launchctl load ~/Library/LaunchAgents/com.jschill.auto-focus.plist
    ```

7. Enjoy your uninterupted coding sessions! 🚀

**Disclaimer:** The first time the script wants to set your focus, it will need permission to communicate to StatusEvents. A popup will interupt your first session and ask if it is allowed. Sorry about that!

## Troubleshooting

The LaunchAgent logs StandardError and StandardOut to `/tmp/auto-focus.out` and `/tmp/auto-cous.err`.

### Stopping `auto-focus`

To completely stop `auto-focus` and clean up after youself. You can run

```sh
launchctl unload ~/Library/LaunchAgents/com.jschill.auto-focus.plist
rm ~/Library/LaunchAgents/com.jschill.auto-focus.plist
```

The script also launches with a Menu Bar item. You can quit the script from running by pressing *Quit*. This does not stop the LaunchAgent fully, and it will start `auto-focus` again when you log in.

### LaunchAgent

The LaunchAgent won't keep the script running if it fails or gets stopped. If you want this behaviour just add the following to the `.plist` file.

```xml
<key>KeepAlive</key>
<true/>
```

## Future

### Slack Integration

Ideally, I would like to set a Slack status and stop notification from that layer, as it would also inform people that I am currently focussing and if really needed, they could still bypass my status and reach me if something is burning.
Integrating with Slack requires a Slack App and API access. This is not impossible, but a bit more involved. Consider this an MVP and if it works well, we can iterate and ask IT for a Slack App.

### Support Other IDEs

Not everyone is using VSCode or other applications could be also considered to be part of being in focus. Replacing VSCode as the main application is trivial, just change `com.microsoft.VSCode` in `main.go` to your IDE. Of course, we can also make this configurable or have a list, but again: MVP.

### Detect Activity

Sometimes you leave your computer to pet your dog or grab a coffee. It is not really important, but this should not be considered to your focus time. Adding a check to detect some general user activity on the machine could solve this.
