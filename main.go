package main

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
	"time"

	"github.com/getlantern/systray"
)

var (
	vscodeActive         bool = false
	timeSpent            time.Duration
	notificationsEnabled bool = true
)

const (
	checkInterval = 1 * time.Second
	focusTime     = 12 * time.Minute
)

func main() {
	systray.Run(onReady, onExit)
}

func onReady() {
	systray.SetTitle("Auto-Focus")
	systray.SetTooltip("Blocks Slack notifications when focused in VSCode")

	mQuit := systray.AddMenuItem("Quit", "Quit the whole app")

	go monitorVSCode()
	go func() {
		<-mQuit.ClickedCh
		systray.Quit()
	}()
}

func onExit() {
	// Clean up here if necessary
}

func monitorVSCode() {
	for {
		inFront, err := isVSCodeInFront()
		if err != nil {
			fmt.Println("Failed to get active window:", err)
			time.Sleep(checkInterval)
			continue
		}

		if inFront {
			if !vscodeActive {
				vscodeActive = true
				timeSpent = 0
			} else {
				timeSpent += checkInterval
				if notificationsEnabled && timeSpent >= focusTime {
					handleNotifications(false)
					notificationsEnabled = false
				}
			}
		} else {
			if vscodeActive || !notificationsEnabled {
				vscodeActive = false
				timeSpent = 0
				if !notificationsEnabled {
					handleNotifications(true)
					notificationsEnabled = true
				}
			}
		}

		time.Sleep(checkInterval)
	}
}

func isVSCodeInFront() (bool, error) {
	cmd := exec.Command("osascript", "-e", `tell application "System Events" to get bundle identifier of application processes whose frontmost is true`)
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		return false, err
	}

	if strings.TrimSpace(out.String()) == "com.microsoft.VSCode" {
		return true, nil
	}
	return false, nil
}

func handleNotifications(enable bool) {
	var scriptPath string
	if enable {
		scriptPath = "/Users/jschill/Code/zendesk/auto-focus/disableFocus.scpt"
	} else {
		scriptPath = "/Users/jschill/Code/zendesk/auto-focus/enableFocus.scpt"
	}

	cmd := exec.Command("osascript", scriptPath)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	err := cmd.Run()
	if err != nil {
		fmt.Printf("Failed to set Focus mode: %v, %s\n", err, stderr.String())
	}
}
