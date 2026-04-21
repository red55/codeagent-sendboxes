#!/bin/bash

set -eux -o pipefail
userdel node || true

apt-get update
apt-get install -yy --no-install-recommends \
    ca-certificates \
    curl \
    gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

tee /etc/apt/sources.list.d/docker.sources <<EOFI
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOFI

# Create non-root user
useradd --create-home --uid 1000 --shell /bin/bash agent
groupadd -f docker
usermod -aG sudo agent
usermod -aG docker agent

# Configure sudoers
mkdir /etc/sudoers.d
chmod 0755 /etc/sudoers.d
echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent
echo "Defaults:%sudo env_keep += \"http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY SSL_CERT_FILE NODE_EXTRA_CA_CERTS REQUESTS_CA_BUNDLE JAVA_TOOL_OPTIONS\"" > /etc/sudoers.d/proxyconfig

# Create sandbox config
mkdir -p /home/agent/.docker/sandbox/locks

# Pre-create .local directories with correct ownership to prevent OCI runtime
# from creating them as root when mounting volumes at deep paths like
# /home/agent/.local/share/opencode (see docker/dash#914).
mkdir -p /home/agent/.local/share /home/agent/.local/state

chown -R agent:agent /home/agent

# Set up npm global package folder under /usr/local/share
mkdir -p /usr/local/share/npm-global

touch /etc/sandbox-persistent.sh
chmod 644 /etc/sandbox-persistent.sh
chown agent:agent /etc/sandbox-persistent.sh
echo 'if [ -f /etc/sandbox-persistent.sh ]; then . /etc/sandbox-persistent.sh; fi; export BASH_ENV=/etc/sandbox-persistent.sh' \
    | tee /etc/profile.d/sandbox-persistent.sh /tmp/sandbox-bashrc-prepend /home/agent/.bashrc > /dev/null
chmod 644 /etc/profile.d/sandbox-persistent.sh
cat /tmp/sandbox-bashrc-prepend /etc/bash.bashrc > /tmp/new-bashrc
mv /tmp/new-bashrc /etc/bash.bashrc
chmod 644 /etc/bash.bashrc
rm /tmp/sandbox-bashrc-prepend
chmod 644 /home/agent/.bashrc
chown agent:agent /home/agent/.bashrc