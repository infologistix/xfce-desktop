# Stage 1: Builder
FROM ubuntu:24.04 AS builder

ENV USERNAME=developer

# Install required tools
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y \
    software-properties-common \
    wget \
    pm-utils \
    gnupg \
    dbus-x11 \
    policykit-1 \
    xfce4-power-manager-plugins \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: Runtime
FROM ubuntu:24.04

# Copy repository configuration from builder
COPY --from=builder /etc/apt/sources.list.d /etc/apt/sources.list.d
COPY --from=builder /etc/apt/trusted.gpg.d /etc/apt/trusted.gpg.d

# Install packages
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y --fix-missing \
    sudo \
    xfce4 xfce4-terminal xfce4-goodies x11vnc xvfb \
    curl libx11-6 libxkbfile1 libsecret-1-0 \
    tigervnc-standalone-server \
    chromium-browser \
    xterm \
    python3 python3-pip vim \
    git \
    wget \
    gpg \
    libnss3 \
    libxss1 \
    libgtk-3-0 \
    dbus-x11 \
    dbus-user-session \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Visual Studio Code
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && \
    install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/ && \
    sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list' && \
    apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y code && \
    rm -f packages.microsoft.gpg && \
    apt-get clean

# Create symbolic link to bypass Snap check
RUN ln -s /usr/bin/chromium-browser /usr/bin/chromium

# Python configuration
RUN ln -s /usr/bin/python3 /usr/bin/python

# User setup - checks if user exists first
RUN set -ex; \
    # Try to get username for UID 1000 (ignore error if not found)
    existing_user=$(getent passwd 1000 | cut -d: -f1 || true); \
    # If a user with UID 1000 exists and is not 'developer', rename them
    if [ -n "$existing_user" ] && [ "$existing_user" != "developer" ]; then \
        usermod -l developer "$existing_user"; \
        groupmod -n developer "$(getent group 1000 | cut -d: -f1)"; \
        usermod -d /home/developer -m developer; \
    # If no user with UID 1000 exists, create 'developer'
    elif [ -z "$existing_user" ]; then \
        useradd -m -u 1000 -s /bin/bash developer; \
    fi; \
    # Ensure home directory and sudo access
    mkdir -p /home/developer && \
    chown -R developer:developer /home/developer && \
    mkdir -p /etc/sudoers.d && \
    echo "developer ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/developer && \
    chmod 440 /etc/sudoers.d/developer

# Set permissions for developer user
RUN mkdir -p /home/developer/.vscode /home/developer/.config && \
    chown -R developer:developer /home/developer

# VS Code configuration
USER developer
WORKDIR /home/developer
RUN code --install-extension ms-python.python --force && \
    code --install-extension eamodio.gitlens --force && \
    echo "export ELECTRON_DISABLE_SANDBOX=1" >> ~/.bashrc && \
    echo "export PATH=\$PATH:/usr/share/code/bin" >> ~/.bashrc && \
    #echo "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus" >> ~/.bashrc && \
    echo "export DISPLAY=:1" >> ~/.bashrc && \
    echo "export TMPDIR=/home/developer/tmp" >> ~/.bashrc && \
    echo "alias code='code --disable-gpu --disable-software-rasterizer'" >> ~/.bashrc

# Xvfb und D-Bus vorbereiten
RUN mkdir -p /tmp/.X11-unix /tmp/.dbus /tmp/.xdg-runtime /tmp/runtime-developer && \
    chmod 1777 /tmp/.X11-unix /tmp/.dbus /tmp/.xdg-runtime /tmp/runtime-developer && \
    chown -R developer:developer /tmp/.X11-unix /tmp/.dbus /tmp/.xdg-runtime /tmp/runtime-developer

# Standardwerte für X11 & D-Bus setzen
ENV DISPLAY=:1
ENV XDG_RUNTIME_DIR=/tmp/runtime-developer

# Hier noch was machen, da root
COPY entrypoint.sh /home/entrypoint.sh
USER root
RUN chmod +x /home/entrypoint.sh
USER developer
EXPOSE 5901
ENTRYPOINT ["/home/entrypoint.sh"] 



