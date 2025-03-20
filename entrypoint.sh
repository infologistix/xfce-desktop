#!/bin/bash

# Initialize D-Bus
mkdir -p /var/run/dbus
chown root:messagebus /var/run/dbus
dbus-uuidgen --ensure
dbus-daemon --system --fork
export $(dbus-launch)


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


# Install Python packages
# sudo -u $USERNAME pip3 install --user -r /home/$USERNAME/requirements.txt || { echo "Python package installation failed"; exit 1; }

# Start code-server
#sudo -u $USERNAME code-server --bind-addr 0.0.0.0:8080 --auth none &

# Start Xvfb and wait for it
export DISPLAY=:1
Xvfb :1 -screen 0 1280x720x16 &

# Chromium prep
chown developer:developer /home/developer
mkdir -p /home/developer/.config/chromium
chown -R developer:developer /home/developer/.config

# Start Chromium automatically (optional)
sudo -u developer chromium-browser --no-sandbox --disable-dev-shm-usage &

# Wait for X server
while [ ! -e /tmp/.X11-unix/X1 ]; do sleep 0.5; done

# Set up Chromium environment
export XAUTHORITY=/tmp/.Xauthority
touch $XAUTHORITY
chown $USERNAME:$USERNAME $XAUTHORITY



# Disable compositing FIRST
sudo -u $USERNAME xfconf-query -c xfwm4 -p /general/use_compositing -s false --create



# Start XFCE and VNC
sudo -u $USERNAME xfce4-session &

# Start Chromium with proper environment
sudo -u $USERNAME chromium-browser \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --no-first-run \
  --window-size=1280,720 \
  --window-position=0,0 \
  > /tmp/chromium.log 2>&1 &


x11vnc -display :1 -forever -shared -rfbauth "/home/${USERNAME}/.vnc/passwd" -rfbport 5901 -localhost no -noxdamage &

# Keep container alive
tail -f /dev/null