#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Canonical Ltd.
set -xeu

# Remove all the snaps, leaving the system as prepare.sh found it, without
# any. Tests install bases and default providers on demand, so remove
# whatever is there: first the applications, including content snaps such as
# mesa-2404 and gnome-46-2404, then the bases, then snapd itself.
snaps_with_notes() {
	snap list 2>/dev/null | awk -v want="$1" 'NR > 1 {
		kind = ($NF ~ /(^|,)(base|core)(,|$)/) ? "base" : ($NF ~ /(^|,)snapd(,|$)/) ? "snapd" : "app"
		if (kind == want) print $1
	}'
}
for kind in app base snapd; do
	for snap in $(snaps_with_notes "$kind"); do
		snap remove --purge "$snap"
	done
done

# Remove /snap if it is a symbolic link.
if [ -L /snap ]; then
	rm /snap
fi
