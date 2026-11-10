#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Canonical Ltd.
set -xeu
# Reset PATH to work around a bug in spread which rewrites path on host-side scripts.
if [ -n "${SPREAD_HOST_PATH-}" ]; then
	PATH="$SPREAD_HOST_PATH"
fi

# Spread system names cannot contain @, which separates the name of an
# image-garden instance from its base system, so spread.yaml spells it -at-.
SYSTEM="$(printf '%s' "$SPREAD_SYSTEM" | sed 's/-at-/@/')"

# Give each virtual machine 2 gigabytes of RAM.
export QEMU_MEM_OPTION='-m 2048'

# In spread mode image-garden prints the address for spread, and waits until
# the SSH server of the virtual machine answers.
exec image-garden allocate --spread "$SYSTEM"."$(uname -m)"
