package pkg

import (
	"bytes"
	"fmt"
	"os/exec"
)

func HandleNotifications(enable bool, repoPath string) {
	var scriptPath string
	if enable {
		scriptPath = fmt.Sprintf("%s/auto-focus/disableFocus.scpt", repoPath)
	} else {
		scriptPath = fmt.Sprintf("%s/auto-focus/enableFocus.scpt", repoPath)
	}

	cmd := exec.Command("osascript", scriptPath)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	err := cmd.Run()
	if err != nil {
		fmt.Printf("Failed to set Focus mode: %v, %s\n", err, stderr.String())
	}
}
