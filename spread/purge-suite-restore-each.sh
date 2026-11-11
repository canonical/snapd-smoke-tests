#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Canonical Ltd.
set -xeu

# The restore-each step is unorthodox in the sense that it does not restore but
# rather, contains the property we care about measuring - it purges snapd from
# the system using the classic packaging system.
if [ -n "$(command -v apt)" ]; then
	apt remove --purge -y snapd
elif [ -n "$(command -v dnf)" ]; then
	dnf remove -y snapd
elif [ -n "$(command -v yum)" ]; then
	yum remove -y snapd
elif [ -n "$(command -v zypper)" ]; then
	# due to https://bugzilla.suse.com/show_bug.cgi?id=1245551 subsequent
	# installations and removals are broken we need to stop snapd explicitly or
	# force a specific code path in systemd-update-helper
	rm -rfv /run/systemd/rpm/
	zypper remove -y snapd
elif [ -n "$(command -v pacman)" ]; then
	pacman --noconfirm -R snapd
else
	echo "How do I uninstall snapd on this system? $(cat /etc/os-release)"
	exit 1
fi

# Purging snapd leaves the data that snaps kept in home directories, such as
# /root/snap/firefox/9181. Show what is left, which is part of what purging
# does, then remove it: a later task may install another revision of the same
# snap, as a progressive release may give the new device that snapd registers
# after the purge another revision, and removing that snap then fails, as
# /root/snap/firefox still holds the data of the old one.
if [ -d /root/snap ]; then
	find /root/snap -maxdepth 2 -ls
	rm -rf /root/snap
fi
