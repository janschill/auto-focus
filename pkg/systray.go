package pkg

import (
	"github.com/getlantern/systray"
)

func OnReady(appCtx AppContext) {
	if appCtx.ShowMenuItem {
		systray.SetTitle("Auto-Focus")
		systray.SetTooltip("Blocks Slack notifications when focused in VSCode")
		mQuit := systray.AddMenuItem("Quit", "Quit the whole app")
		appCtx.CurrentTimer = systray.AddMenuItem("Current Timer: 00:00", "Shows the current timer")

		go func() {
			<-mQuit.ClickedCh
			systray.Quit()
		}()
	}

	go MonitorFocusApp(appCtx)
}

func OnExit() {
	// Clean up here if necessary
}
