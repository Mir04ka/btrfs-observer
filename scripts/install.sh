#!/bin/bash

DIR="$HOME/.local/share/btrfs_observer"
mkdir -p "$DIR"

TIMEOUT_FILE="$DIR/timeout.txt"
read -p "Timeout(seconds): " TIMEOUT
echo "$TIMEOUT" > "$TIMEOUT_FILE"

DISKS_FILE="$DIR/disks.txt"
echo "Enter disks(Ctrl+D to finish):"
cat > "$DISKS_FILE"

BIN_URL="https://github.com/Mir04ka/btrfs-observer/releases/download/beta/btrfs-observer-0.2-beta"
BIN_NAME=$(basename "$BIN_URL")
sudo curl -L "$BIN_URL" -o "/usr/local/bin/$BIN_NAME"
sudo chmod +x "/usr/local/bin/$BIN_NAME"

SERVICE_FILE="/etc/systemd/system/btrfs-observer.service"
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=BTRFS Observer Service
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/local/bin/$BIN_NAME
Restart=on-failure

[Install]
WantedBy=default.target
EOL

sudo systemctl --user daemon-reload
sudo systemctl --user enable "btrfs-observer.service"
sudo systemctl --user -u btrfs-observer -f

echo "$BIN_NAME is installed!"
