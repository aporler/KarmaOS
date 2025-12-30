#!/bin/bash
# KarmaOS Welcome Daemon
# Auto-starts the welcome wizard on first boot

SETUP_COMPLETE="/var/snap/karmaos-welcome/common/setup-complete"

if [ -f "$SETUP_COMPLETE" ]; then
    echo "Setup already completed, exiting"
    exit 0
fi

# Wait for display server
sleep 5

# Launch GUI
exec "$SNAP/bin/karmaos-welcome-gui"
