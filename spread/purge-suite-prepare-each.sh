#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Canonical Ltd.
set -xeu
# See the comment in purge-suite-restore.sh for explanation as to why we need
# to re-install snapd in the prepare-each step.
if [ -n "$(command -v apt)" ]; then
	apt install -y snapd
elif [ -n "$(command -v dnf)" ]; then
	dnf install -y snapd
elif [ -n "$(command -v yum)" ]; then
	yum install -y snapd
elif [ -n "$(command -v zypper)" ]; then
	zypper install -y snapd
elif [ -n "$(command -v pacman)" ]; then
	pacman --noconfirm -U /var/tmp/snapd/snapd-*.tar.zst
else
	echo "How do I re-install snapd on this system? $(cat /etc/os-release)"
	exit 1
fi
systemctl enable --now snapd.socket
if [ -f /usr/lib/systemd/system/snapd.apparmor.service ]; then
	systemctl enable --now snapd.apparmor.service
fi
snap wait system seed.loaded

exec "$SPREAD_PATH"/spread/install-snapd.sh
