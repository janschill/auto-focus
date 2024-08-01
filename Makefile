stop:
	@echo "Stopping program ..."
	@if launchctl list | grep -q "com.jschill.auto-focus"; then \
		launchctl unload ~/Library/LaunchAgents/com.jschill.auto-focus.plist; \
		echo "Program stopped."; \
	else \
		echo "Program is not running."; \
	fi

load:
	@echo "Copying plist to LaunchAgents directory ..."
	cp com.jschill.auto-focus.plist ~/Library/LaunchAgents/
	@echo "Loading plist ..."
	launchctl load ~/Library/LaunchAgents/com.jschill.auto-focus.plist
	@echo "Program is running."

run:
	$(MAKE) stop
	$(MAKE) build
	$(MAKE) load

init: build
	@echo "Initializing ..."
	@if [ ! -f .env ]; then \
		echo "Copying .env.example to .env"; \
		cp .env.example .env; \
		REPO_PATH=$$(pwd); \
		sed -i.bak "s|REPO_PATH=.*|REPO_PATH=$$REPO_PATH|" .env; \
		rm .env.bak; \
	fi
	$(MAKE) generate-plist

generate-plist: build
	@echo "Generating plist ..."
	./auto-focus -init

build:
	@echo "Building ..."
	go build -o auto-focus main.go
