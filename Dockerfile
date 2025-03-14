# Stage 1: Builder
FROM ubuntu:22.04 AS builder

ENV USERNAME=developer

# Install required tools
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    software-properties-common \
    wget \
    gnupg \
    dbus-x11 \
    policykit-1 \
    xfce4-power-manager-plugins \
    && rm -rf /var/lib/apt/lists/*

# Add Chromium PPA
RUN add-apt-repository ppa:saiarcot895/chromium-beta

# Stage 2: Runtime
FROM ubuntu:22.04

# Copy repository configuration from builder
COPY --from=builder /etc/apt/sources.list.d /etc/apt/sources.list.d
COPY --from=builder /etc/apt/trusted.gpg.d /etc/apt/trusted.gpg.d

# Install packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    sudo \
    xfce4 xfce4-terminal xfce4-goodies x11vnc xvfb \
    curl libx11-6 libxkbfile1 libsecret-1-0 \
    tigervnc-standalone-server \
    chromium-browser \
    libnss3 \
    libxss1 \
    libasound2 \
    libgbm1 \
    libgtk-3-0 \
    fonts-liberation \
    xterm \
    python3 python3-pip vim \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Python configuration
RUN ln -s /usr/bin/python3 /usr/bin/python

# User setup
RUN useradd -m -u 1000 -s /bin/bash developer \
    && mkdir -p /etc/sudoers.d \
    && echo "developer ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/developer \
    && chmod 440 /etc/sudoers.d/developer


# VNC setup
RUN mkdir -p /home/${USERNAME}/.vnc \
    && echo "changeme" | vncpasswd -f > /home/${USERNAME}/.vnc/passwd \
    && chmod 600 /home/${USERNAME}/.vnc/passwd


COPY entrypoint.sh /home/developer/entrypoint.sh
RUN chmod +x /home/developer/entrypoint.sh

# Set up environment
WORKDIR /home/developer
EXPOSE 5901

# EXPOSE 8080 5900

# Set user and entrypoint
# USER user
ENTRYPOINT ["/home/developer/entrypoint.sh"]
