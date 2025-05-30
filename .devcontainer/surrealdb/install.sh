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

# This script will set the appropriate environment variable for the
# SurrealDB installation script based on the version option.
#
# The SurrealDB installation script takes different environment variables:
# - ALPHA=true
# - BETA=true
# - NIGHTLY=true
# - VERSION=x.y.z
# depending on what release channel you want to install from.
# The developer of this devcontainer feature thinks having to specify different
# feature options for different release channels is not ideal.

if [ "$VERSION" = "alpha" ]; then
  export ALPHA="true"
elif [ "$VERSION" = "beta" ]; then
  export BETA="true"
elif [ "$VERSION" = "nightly" ]; then
  export NIGHTLY="true"
elif [ "$VERSION" = "latest" ]; then
  # For latest, don't set VERSION - let the script use the default
  unset VERSION
else
  # For specific versions, remove the "v" prefix if present
  export VERSION="${VERSION#v}"
fi

curl -sSf https://install.surrealdb.com | sh
