#!/bin/bash
set -euo pipefail

# Sudo only
if [ "$(id -u)" -ne 0 ]; then
    echo "I need sudo" >&2
    exit 1
fi

# Get real user and home
USER_NAME="${SUDO_USER:-$(logname)}"
USER_HOME="$(eval echo "~$USER_NAME")"

# Create program folder
DIR="$USER_HOME/.local/share/btrfs_observer"
mkdir -p "$DIR"

# Create timeout.txt file
TIMEOUT_FILE="$DIR/timeout.txt"
read -p "Timeout(seconds): " TIMEOUT
echo "$TIMEOUT" > "$TIMEOUT_FILE"

sudo chown -R $USER_NAME:$USER_NAME $TIMEOUT_FILE

# Create disks.txt file
DISKS_FILE="$DIR/disks.txt"
echo "Enter disks (one per line, Ctrl+D to finish):"
cat > "$DISKS_FILE"

sudo chown -R $USER_NAME:$USER_NAME $DISKS_FILE

# Change the user
sudo chown -R $USER_NAME:$USER_NAME ~/.local/share/btrfs_observer/

# Create btrfs-stats-wrapper script
SCRIPT_PATH="$USER_HOME/.local/bin/btrfs-stats-wrapper.sh"
SUDOERS_FILE="/etc/sudoers.d/btrfs_stats_nopasswd"

cat > "$SCRIPT_PATH" <<'EOL'
#!/bin/bash

if [ $# -ne 1 ]; then
    exit 1
fi

DISK_PATH="$1"

exec /usr/bin/btrfs device stats "$DISK_PATH"
EOL

# Make executable
chmod +x $SCRIPT_PATH

# Add btrfs-stats-wrapper to sudoers
echo "$USER_NAME ALL=(ALL) NOPASSWD: $SCRIPT_PATH" > "$SUDOERS_FILE"

# Check sudoers syntax
visudo -cf "$SUDOERS_FILE"
if [ $? -ne 0 ]; then
  echo "❌ Sudoers syntax error"
  rm -f "$SUDOERS_FILE"
  exit 1
fi

# Add rights
chmod 440 "$SUDOERS_FILE"

# Get latest version
LATEST_VERSION_URL="https://raw.githubusercontent.com/Mir04ka/btrfs-observer/refs/heads/master/latest-version"
LATEST_VERSION=$(curl -s "$LATEST_VERSION_URL")
echo "Latest version found: $LATEST_VERSION"

# Install binary
BIN_URL="https://github.com/Mir04ka/btrfs-observer/releases/download/$LATEST_VERSION/btrfs-observer"
BIN_NAME=$(basename "$BIN_URL")

mkdir -p "$USER_HOME/.local/bin"
curl -L "$BIN_URL" -o "$USER_HOME/.local/bin/$BIN_NAME"
chmod +x "$USER_HOME/.local/bin/$BIN_NAME"
sudo chown $USER_NAME:$USER_NAME $USER_HOME/.local/bin/btrfs-observer

# Create user unit
USER_UNIT_DIR="$USER_HOME/.config/systemd/user"
mkdir -p "$USER_UNIT_DIR"
UNIT_FILE="$USER_UNIT_DIR/btrfs-observer.service"
cat > "$UNIT_FILE" <<EOL
[Unit]
Description=BTRFS Observer (user)
After=graphical-session.target

[Service]
Type=simple
ExecStart=$USER_HOME/.local/bin/$BIN_NAME
Restart=on-failure

[Install]
WantedBy=default.target
EOL

# Enable linger to allow background user services
loginctl enable-linger "$USER_NAME"

# Reload and enable user service
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u $USER_NAME)" systemctl --user daemon-reload
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u $USER_NAME)" systemctl --user enable --now btrfs-observer.service

echo "BTRFS observer installed!"
