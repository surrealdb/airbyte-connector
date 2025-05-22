#!/bin/bash
set -ex

# See the below for how other devcontainer features are implemented
# https://github.com/devcontainers/features/tree/main/src

apt_get_update() {
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

check_packages curl ca-certificates

if [ -z "${VERSION}" ]; then
	VERSION=latest
fi

if [ "${VERSION}" == "latest" ]; then
	versionStr=$(curl https://api.github.com/repos/airbytehq/abctl/releases/latest | jq -r '.tag_name')
else
	versionStr=v${VERSION}
fi

echo "Installing Kind version ${versionStr}"

architecture=$(dpkg --print-architecture)
case "${architecture}" in
	amd64) architectureStr=amd64 ;;
	arm64) architectureStr=arm64 ;;
	*)
		echo "abctl does not support machine architecture '$architecture'."
		exit 1
esac

curl -L "https://github.com/airbytehq/abctl/releases/download/${versionStr}/abctl-${versionStr}-linux-${architectureStr}.tar.gz" \
	-o /usr/local/bin/abctl.tar.gz

tar -xzf /usr/local/bin/abctl.tar.gz -C /usr/local/bin --strip=1 abctl-${versionStr}-linux-${architectureStr}/abctl

chmod +x /usr/local/bin/abctl
