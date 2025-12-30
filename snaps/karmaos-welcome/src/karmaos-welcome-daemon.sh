#!/bin/bash
# KarmaOS Welcome Daemon
# Auto-starts the welcome wizard after console-conf creates a user

SETUP_COMPLETE="/var/snap/karmaos-welcome/common/setup-complete"

if [ -f "$SETUP_COMPLETE" ]; then
    echo "Setup already completed, exiting"
    exit 0
fi

# Wait for a user to be created by console-conf
echo "Waiting for console-conf to create initial user..."
while true; do
    # Check if there's at least one non-system user
    if getent passwd | grep -q ":/home/"; then
        echo "User detected, waiting for display server..."
        break
    fi
    sleep 10
done

# Wait for display server to be ready
for i in {1..60}; do
    if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
        break
    fi
    sleep 1
done

# Launch GUI
exec "$SNAP/bin/karmaos-welcome-gui.py"
