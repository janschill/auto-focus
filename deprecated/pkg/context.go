package pkg

import (
	"time"

	"github.com/getlantern/systray"
)

type AppContext struct {
	CurrentTimer  *systray.MenuItem
	RepoPath      string
	FocusApp      string
	ShowMenuItem  bool
	CheckInterval time.Duration
	FocusTime     time.Duration
}
