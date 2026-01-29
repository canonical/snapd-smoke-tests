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
# Note that this is in sync with the "-object memory-backend" entry below.
export QEMU_MEM_OPTION='-m 2048'

# If we have virtiofsd available then use it to provide efficient cache for each virtual machine.
if [ -x "${SNAP-}"/usr/libexec/virtiofsd ]; then
	# Prepare the architecture-specific cache directory.
	mkdir -p .image-garden/cache-"$ARCH"

	# Find a socket path that is not used. This is NOT synchronized here but
	# image-garden allocate auto-synchronizes on spread.yaml so there should be
	# meaningful protection from clashes.
	VIRTIOFSD_SOCK_PATH=/dev/null
	N=
	while test -e "$VIRTIOFSD_SOCK_PATH"; do
		N="$(shuf -i 1-9999 -n 1)"
		VIRTIOFSD_SOCK_PATH="$(pwd)"/.image-garden/vhostqemu."$N".sock
	done

	# Use virtiofsd to expose host file-system to the guest in a very efficient
	# manner. Yes, I had to say very efficient because it tool some work and this
	# justifies it more.
	# For details see https://virtio-fs.gitlab.io/howto-qemu.html
	"${SNAP-}"/usr/libexec/virtiofsd \
		--shared-dir ./.image-garden/cache-"$ARCH" \
		--socket-path "$VIRTIOFSD_SOCK_PATH" \
		--sandbox "$(if test -n "${SNAP-}"; then echo none; else echo namespace; fi)" \
		--seccomp "$(if test -n "${SNAP-}"; then echo none; else echo kill; fi)" \
		</dev/null >.image-garden/virtiofsd."$N".log 2>.image-garden/virtiofsd."$N".err.log &
	VIRTIOFSD_PID=$!

	# Wait for virtiofsd to start.
	for _ in $(seq 5); do
		if [ -S "$VIRTIOFSD_SOCK_PATH" ]; then
			break
		fi
		sleep 1
	done

	if [ ! -S "$VIRTIOFSD_SOCK_PATH" ]; then
		rm -f "$SHM_PATH"
		echo "<FATAL cannot find virtiofsd socket: $(tail -n 1 .image-garden/virtiofsd."$N".err.log)>"
		exit 213
	fi

	# Remove the extra PID file (we save ours separately).
	# Yes the PID file is just the socket path with the .pid extension.
	rm -f "$VIRTIOFSD_SOCK_PATH".pid

	SHM_PATH=/dev/shm/"$(if test -n "${SNAP-}"; then echo snap."${SNAP_INSTANCE_NAME}"; else echo virtiofsd; fi)".spread-cache."$N"

	# Allocate the system through image-garden allocator.
	if ADDR="$(timeout -p "$ALLOCATE_TIMEOUT" image-garden allocate \
		"$SPREAD_SYSTEM"."$ARCH" \
		-chardev socket,id=char0,path="$VIRTIOFSD_SOCK_PATH" \
		-device vhost-user-fs-pci,queue-size=1024,chardev=char0,tag=spread-cache \
		-object memory-backend-file,id=mem,size=2048M,mem-path="$SHM_PATH",share=on \
		-numa node,memdev=mem)"; then
		# Save the PID so that we can kill the poor-man's-service later.
		echo "$VIRTIOFSD_PID" >.image-garden/vhostqemu."$ADDR".pid
		rm -f "$SHM_PATH"
		echo "<ADDRESS $ADDR>"
		exit 0
	else
		kill %1 || true
		rm -f "$SHM_PATH"
		# XXX: We don't know which port "image-garden allocate" picked so use * here.
		echo "<FATAL cannot start qemu: $(tail -n 1 .image-garden/"$SPREAD_SYSTEM"."$ARCH".*.stderr.log)>"
		exit 213
	fi
else
	# Allocate the system through image-garden allocator.
	if ADDR="$(timeout -p "$ALLOCATE_TIMEOUT" image-garden allocate "$SPREAD_SYSTEM"."$ARCH")"; then
		echo "<ADDRESS $ADDR>"
		exit 0
	else
		echo "<FATAL cannot start>"
		exit 213
	fi
fi
