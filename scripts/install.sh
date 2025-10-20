#!/bin/bash

DIR="$HOME/.local/share/btrfs_observer"
mkdir -p "$DIR"

TIMEOUT_FILE="$DIR/timeout.txt"
read -p "Timeout(seconds): " TIMEOUT
echo "$TIMEOUT" > "$TIMEOUT_FILE"

DISKS_FILE="$DIR/disks.txt"
echo "Enter disks(Ctrl+D to finish):"
cat > "$DISKS_FILE"

BIN_URL="https://github.com/Mir04ka/btrfs-observer/releases/download/beta/btrfs-observer-0.1-beta"
BIN_NAME=$(basename "$BIN_URL")
sudo curl -L "$BIN_URL" -o "/usr/local/bin/$BIN_NAME"
sudo chmod +x "/usr/local/bin/$BIN_NAME"

SERVICE_FILE="/etc/systemd/system/$BIN_NAME.service"
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=$BIN_NAME Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/$BIN_NAME
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable "$BIN_NAME.service"
sudo systemctl start "$BIN_NAME.service"

echo "$BIN_NAME is installed!"
