#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Canonical Ltd.
set -xeu
# Reset PATH to work around a bug in spread which rewrites path on host-side scripts.
if [ -n "${SPREAD_HOST_PATH-}" ]; then
	PATH="$SPREAD_HOST_PATH"
fi

# Check which architecture we will run on.
: "${ARCH:="$(uname -m)"}"

ALLOCATE_TIMEOUT="${ALLOCATE_TIMEOUT-5m}"

# Give each virtual machine 2 gigabytes of RAM.
export QEMU_MEM_OPTION='-m 2048'

# Allocate the system through image-garden allocator.
# TODO: use timeout
if ADDR="$(image-garden allocate "$SPREAD_SYSTEM"."$ARCH")"; then
	echo "<ADDRESS $ADDR>"
	exit 0
else
	echo "<FATAL cannot start>"
	exit 213
fi
