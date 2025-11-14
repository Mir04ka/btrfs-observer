#!/bin/bash
set -euo pipefail

# User-phase
if [[ "${1:-}" == "--as-user" ]]; then
    # Reload and enable user service
    systemctl --user daemon-reload
    systemctl --user enable --now btrfs-observer.service
    systemctl --user start --now btrfs-observer.service

    echo "BTRFS observer installed!"
    exit 0
fi

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

chown -R $USER_NAME:$USER_NAME $TIMEOUT_FILE

# Create disks.txt file
DISKS_FILE="$DIR/disks.txt"
echo "Enter disks (one per line, Ctrl+D to finish):"
cat > "$DISKS_FILE"

chown -R $USER_NAME:$USER_NAME $DISKS_FILE

# Change the user
chown -R $USER_NAME:$USER_NAME $USER_HOME/.local/share/btrfs_observer/

# Create btrfs-stats-wrapper script
SCRIPT_DIR="$USER_HOME/.local/bin"
SCRIPT_PATH="$SCRIPT_DIR/btrfs-stats-wrapper.sh"
SUDOERS_FILE="/etc/sudoers.d/btrfs_stats_nopasswd"

mkdir -p $SCRIPT_DIR

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
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Script $SCRIPT_PATH not found"
    exit 1
fi

SUDOERS_FILE="/etc/sudoers.d/btrfs-observer-$USER_NAME"
echo "$USER_NAME ALL=(root) NOPASSWD: $SCRIPT_PATH" > "$SUDOERS_FILE"
chmod 440 "$SUDOERS_FILE"

if ! visudo -c; then
    echo "Sudoers file mistake! Removing file..."
    rm -f "$SUDOERS_FILE"
    exit 1
fi

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
# curl -L "$BIN_URL" -o "$USER_HOME/.local/bin/$BIN_NAME"
chmod +x "$USER_HOME/.local/bin/$BIN_NAME"
chown $USER_NAME:$USER_NAME $USER_HOME/.local/bin/btrfs-observer

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

chown "$USER_NAME":"$USER_NAME" "$UNIT_FILE"

# Enable linger to allow background user services
loginctl enable-linger "$USER_NAME"

# systemctl --user daemon-reload
# sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u $USER_NAME)" systemctl --user daemon-reload
# sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$(id -u $USER_NAME)" systemctl --user enable --now btrfs-observer.service

echo "Entering user mode..."
SELF_PATH="$(realpath "${BASH_SOURCE[0]}")"
chmod +x $SELF_PATH
exec sudo -u "$USER_NAME" --preserve-env=HOME,USER,BASH_ENV "$SELF_PATH" --as-user

