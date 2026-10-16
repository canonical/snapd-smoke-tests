#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Canonical Ltd.
set -xeu

# Ensure that installing snaps with classic confinement is allowed.
if [ ! -e /snap ] && [ -d /var/lib/snapd/snap ]; then
	ln -s /var/lib/snapd/snap /snap
fi

# Pre-install snapd as a snap. Use the latest/beta channel
# to always test upcoming updates.
#
# Base snaps (bare, core, core18, core20, core22, core24, ...) are not
# pre-installed here: snapd installs whichever bases a given test's snaps
# actually depend on, automatically, as part of installing those snaps.
snap install snapd --channel=latest/"${X_SPREAD_SNAPD_RISK_LEVEL}"
