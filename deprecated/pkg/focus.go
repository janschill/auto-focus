package pkg

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

var (
	notificationsEnabled = true
	timeSpent            = time.Duration(0)
	isFocusAppActive     = false
)

func IsFocusAppInFront(focusApp string) (bool, error) {
	cmd := exec.Command("osascript", "-e", `tell application "System Events" to get bundle identifier of application processes whose frontmost is true`)
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		return false, err
	}

	if strings.TrimSpace(out.String()) == focusApp {
		return true, nil
	}
	return false, nil
}

func MonitorFocusApp(appCtx AppContext) {
	for {
		inFront, err := IsFocusAppInFront(appCtx.FocusApp)
		if err != nil {
			fmt.Println("Failed to get active window:", err)
			time.Sleep(appCtx.CheckInterval)
			continue
		}

		if inFront {
			if !isFocusAppActive {
				isFocusAppActive = true
				timeSpent = 0
			} else {
				timeSpent += appCtx.CheckInterval
				if notificationsEnabled && timeSpent >= appCtx.FocusTime {
					HandleNotifications(false, appCtx.RepoPath)
					notificationsEnabled = false
				}
			}
		} else {
			if isFocusAppActive || !notificationsEnabled {
				isFocusAppActive = false
				timeSpent = 0
				if !notificationsEnabled {
					HandleNotifications(true, appCtx.RepoPath)
					notificationsEnabled = true
				}
			}
		}

		if appCtx.ShowMenuItem {
			appCtx.CurrentTimer.SetTitle(fmt.Sprintf("Current Timer: %02d:%02d", int(timeSpent.Minutes()), int(timeSpent.Seconds())%60))
		}
		time.Sleep(appCtx.CheckInterval)
	}
}
