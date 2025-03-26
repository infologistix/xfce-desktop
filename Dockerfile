# Stage 1: Builder
FROM gwq-vpgitlab01.gwq-serviceplus.de:5005/base/base:latest AS builder

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
FROM gwq-vpgitlab01.gwq-serviceplus.de:5005/base/base:latest 

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

# VS Code configuration
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && \
    install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/ && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y code && \
    rm -f packages.microsoft.gpg && \
    ln -s /usr/share/code/bin/code /usr/local/bin/code

# VS Code configuration
USER developer
WORKDIR /home/developer
RUN code --install-extension ms-python.python --force && \
    code --install-extension eamodio.gitlens --force && \
    echo "export ELECTRON_DISABLE_SANDBOX=1" >> ~/.bashrc && \
    echo "export PATH=\$PATH:/usr/share/code/bin" >> ~/.bashrc

COPY entrypoint.sh /home/entrypoint.sh
USER root
RUN chmod +x /home/entrypoint.sh

EXPOSE 5901
ENTRYPOINT ["/home/entrypoint.sh"] 
WORKDIR /app


