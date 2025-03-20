#!/bin/bash

# Initialize D-Bus
mkdir -p /var/run/dbus
dbus-daemon --system --fork
export $(dbus-launch)

# User-mode D-Bus setup
export DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-session
mkdir -p /tmp/dbus-session
dbus-daemon --session --address="$DBUS_SESSION_BUS_ADDRESS" --fork

# Set up VNC password
USERNAME=developer
VNC_PASSWORD=$(cat /etc/vnc-secret/password)

# .vnc-Verzeichnis erstellen
mkdir -p /home/$USERNAME/.vnc
chown -R $USERNAME:$USERNAME /home/$USERNAME/.vnc
chmod 700 /home/$USERNAME/.vnc

# Passwortdatei erstellen
echo -n "$VNC_PASSWORD" | vncpasswd -f > /home/$USERNAME/.vnc/passwd
chown $USERNAME:$USERNAME /home/$USERNAME/.vnc/passwd
chmod 600 /home/$USERNAME/.vnc/passwd

# UNIX-Passwort für developer setzen
echo "developer:changeme" | chpasswd

# Start Xvfb and wait for it
export DISPLAY=:1
Xvfb :1 -screen 0 1280x720x16 -ac +extension GLX +render -noreset &

# Warte, bis Xvfb läuft
sleep 2
while ! xdpyinfo -display :1 >/dev/null 2>&1; do
    echo "Waiting for X server..."
    sleep 1
done

# Chromium vorbereiten
chown developer:developer /home/developer
mkdir -p /home/developer/.config/chromium
chown -R developer:developer /home/developer/.config

# Start Chromium mit optimierten Flags
sudo -u developer chromium-browser \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --single-process \
  --disable-background-mode \
  --disable-software-rasterizer \
  --no-first-run \
  --window-size=1280,720 \
  --window-position=0,0 \
  > /tmp/chromium.log 2>&1 &

# Warte, bis Chromium läuft
sleep 5

# Disable compositing for better performance
sudo -u $USERNAME xfconf-query -c xfwm4 -p /general/use_compositing -s false --create

# Start XFCE und logge Fehler
sudo -u $USERNAME startxfce4 > /tmp/xfce.log 2>&1 &

# Starte VNC-Server mit mehr Logs
x11vnc -display :1 -forever -shared -rfbauth "/home/${USERNAME}/.vnc/passwd" -rfbport 5901 -noxdamage -listen 0.0.0.0 > /tmp/x11vnc.log 2>&1 &

# Keep container alive
tail -f /tmp/xfce.log /tmp/x11vnc.log /tmp/chromium.log
