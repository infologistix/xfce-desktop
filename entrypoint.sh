#!/bin/bash

# Set runtime environment
export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime-developer
export XAUTHORITY=/home/developer/.Xauthority  # Ensure correct XAuthority file

# Start virtual frameb uffer (Xvfb) in the background
Xvfb :1 -screen 0 1920x1080x24 &

# Wait for Xvfb to initialize
sleep 2

# Create a new Xauthority cookie for the developer user
xauth add $DISPLAY . $(mcookie)

# Ensure that the .vnc directory and password file exist and have correct permissions
mkdir -p /home/developer/.vnc
x11vnc -storepasswd mypassword /home/developer/.vnc/passwd
chown developer:developer /home/developer/.vnc/passwd
chmod 600 /home/developer/.vnc/passwd

# ✅ Install VSCodium extensions at runtime (if not already installed)
EXTDIR=/opt/vscodium-extensions
if [ -d "$EXTDIR" ]; then
  for vsix in "$EXTDIR"/*.vsix; do
    if [ -f "$vsix" ]; then
      ext_id=$(basename "$vsix" .vsix)
      if ! codium --list-extensions | grep -q "$ext_id"; then
        echo "🔧 Installing extension: $vsix"
        codium --no-sandbox --user-data-dir="$HOME/.vscode-oss" --install-extension "$vsix"
      else
        echo "✅ Already installed: $ext_id"
      fi
    fi
  done
fi

# Start XFCE session as the current user
startxfce4 &

# Start VNC server with password protection
x11vnc -usepw -display :1 -forever -shared -rfbport 5901 -listen 0.0.0.0 -auth $XAUTHORITY &

# Keep the container alive
tail -f /dev/null
