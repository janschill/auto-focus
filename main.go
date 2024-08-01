package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/getlantern/systray"
	"github.com/joho/godotenv"
	"github.com/zendesk/auto-focus/pkg"
)

var appCtx pkg.AppContext

func init() {
	execPath, err := os.Executable()
	if err != nil {
		fmt.Println("Failed to get executable path:", err)
		return
	}
	execDir := filepath.Dir(execPath)
	envPath := filepath.Join(execDir, ".env")
	fmt.Println("Loading .env file from:", envPath) // Debug print
	err = godotenv.Load(envPath)
	if err != nil {
		fmt.Println("Failed to load .env file")
		return
	}

	showMenuItem, err := strconv.ParseBool(os.Getenv("SHOW_IN_MENU"))
	if err != nil {
		fmt.Println("Failed to parse SHOW_IN_MENU:", err)
		return
	}
	checkInterval, err := strconv.Atoi(os.Getenv("INTERVAL_TIME_IN_SECONDS"))
	if err != nil {
		fmt.Println("Failed to parse FOCUS_TIME_IN_MINUTES:", err)
		return
	}
	focusTime, err := strconv.Atoi(os.Getenv("FOCUS_TIME_IN_MINUTES"))
	if err != nil {
		fmt.Println("Failed to parse FOCUS_TIME_IN_MINUTES:", err)
		return
	}
	appCtx = pkg.AppContext{
		CurrentTimer:  nil,
		RepoPath:      os.Getenv("REPO_PATH"),
		FocusApp:      os.Getenv("FOCUS_APP_BUNDLE_IDENTIFIER"),
		ShowMenuItem:  showMenuItem,
		CheckInterval: time.Duration(checkInterval) * time.Second,
		FocusTime:     time.Duration(focusTime) * time.Minute,
	}
}

func main() {
	generatePlistFlag := flag.Bool("init", false, "Generate the plist file")
	flag.Parse()

	if *generatePlistFlag {
		err := pkg.GeneratePlist(appCtx.RepoPath)
		if err != nil {
			fmt.Println("Failed to generate plist:", err)
		}
		return
	}

	systray.Run(func() { pkg.OnReady(appCtx) }, pkg.OnExit)
}
