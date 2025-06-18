# Stage 1: Builder - VSCodium extensions setup
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget gnupg git ca-certificates apt-transport-https && \
    wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | \
      gpg --dearmor -o /usr/share/keyrings/vscodium-archive-keyring.gpg && \
    echo 'deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main' \
      > /etc/apt/sources.list.d/vscodium.list && \
    apt-get update && \
    apt-get install -y codium && \
    rm -rf /var/lib/apt/lists/*

# Stage 2: Runtime
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    XDG_RUNTIME_DIR=/tmp/runtime-developer \
    HOME=/home/developer \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/runtime-developer/bus

# Copy Codium extensions and repo config
COPY --from=builder /usr/share/keyrings/vscodium-archive-keyring.gpg /usr/share/keyrings/
COPY --from=builder /etc/apt/sources.list.d/vscodium.list /etc/apt/sources.list.d/

# Install core packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo xfce4 xfce4-goodies x11vnc xvfb \
    firefox dbus-x11 dbus-user-session light-locker \
    wget curl vim git nano \
    openjdk-17-jre \
    python3 python3-pip python3-venv \
    r-base bash-completion ca-certificates xauth \
    iputils-ping telnet net-tools traceroute dnsutils \
    unixodbc gnupg software-properties-common && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    wget -O /tmp/dbeaver.deb https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb && \
    apt-get install -y /tmp/dbeaver.deb && rm /tmp/dbeaver.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Microsoft ODBC Driver 18
RUN curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg && \
    echo "deb [arch=amd64] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 mssql-tools && \
    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> /etc/profile.d/mssql.sh && \
    rm -rf /var/lib/apt/lists/*

#RUN useradd -m containeruser && groupadd containergroup


# Fix UID conflict: Remove existing user 1000 if present
RUN if getent passwd 1000; then userdel -r -f $(getent passwd 1000 | cut -d: -f1); fi

# Create developer user
RUN usermod -l developer && \
    usermod -d /home/developer -m developer && \
    groupmod -n developer && \
    usermod -s /bin/bash developer && \
    usermod -p '$(openssl passwd -6 changeme)' developer && \
    mkdir -p /etc/sudoers.d && \
    echo "developer ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/developer && \
    chmod 0440 /etc/sudoers.d/developer 
    # chown -R developer:developer /opt/vscodium-extensions

# Als root – Standard
RUN mkdir -p /var/tmp/dbus && \
    chmod 755 /var/tmp/dbus

 RUN mkdir -p /var/run/dbus && \
    chown root:root /var/run/dbus && \
    chmod 755 /var/run/dbus


# VNC Setup
RUN mkdir -p /home/developer/.vnc && \
    x11vnc -storepasswd mypassword /home/developer/.vnc/passwd && \
    chown -R developer:developer /home/developer/.vnc && chmod 600 /home/developer/.vnc/passwd

# Runtime directories
RUN mkdir -p /tmp/runtime-developer /tmp/.X11-unix && \
    chown developer:developer /tmp/runtime-developer && \
    chmod 0700 /tmp/runtime-developer && chmod 1777 /tmp/.X11-unix

# Shell Config
RUN echo '# ~/.bashrc' > /home/developer/.bashrc && \
    echo 'if [ -f /etc/bash_completion ]; then . /etc/bash_completion; fi' >> /home/developer/.bashrc && \
    echo 'PS1="\\u@\\h:\\w\\$ "' >> /home/developer/.bashrc && \
    echo 'alias ll="ls -alF"' >> /home/developer/.bashrc && \
    echo 'alias la="ls -A"' >> /home/developer/.bashrc && \
    echo 'alias l="ls -CF"' >> /home/developer/.bashrc && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/developer/.bashrc && \
    chown developer:developer /home/developer/.bashrc

# Entrypoint setup
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /home/developer
EXPOSE 5901
USER developer

ENTRYPOINT ["/bin/bash", "-c", "x11vnc -usepw -forever -display :1 -listen 0.0.0.0 & /entrypoint.sh"]