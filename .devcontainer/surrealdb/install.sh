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

# This script will pass the appropriate command-line flags to the
# SurrealDB installation script based on the version option.
#
# The SurrealDB installation script takes command-line flags:
# - --alpha (or -a)
# - --beta (or -b)
# - --nightly (or -n)
# - --version x.y.z (or -v x.y.z)
# depending on what release channel you want to install from.

# Determine the appropriate flag to pass to the install script
INSTALL_ARGS=""

if [ "$VERSION" = "alpha" ]; then
  INSTALL_ARGS="--alpha"
elif [ "$VERSION" = "beta" ]; then
  INSTALL_ARGS="--beta"
elif [ "$VERSION" = "nightly" ]; then
  INSTALL_ARGS="--nightly"
elif [ "$VERSION" = "latest" ]; then
  # For latest, don't pass any version flags - let the script use the default
  INSTALL_ARGS=""
else
  # For specific versions, remove the "v" prefix if present and pass --version flag
  VERSION_CLEAN="${VERSION#v}"
  INSTALL_ARGS="--version $VERSION_CLEAN"
fi

curl -sSf https://install.surrealdb.com | sh -s -- $INSTALL_ARGS
