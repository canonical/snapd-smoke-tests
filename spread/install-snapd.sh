#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Canonical Ltd.
set -xeu

# Ensure that installing snaps with classic confinement is allowed.
if [ ! -e /snap ] && [ -d /var/lib/snapd/snap ]; then
	ln -s /var/lib/snapd/snap /snap
fi

# Install snapd as a snap from the risk level under test, beta by default, to
# always test upcoming updates. Base snaps and default providers are
# installed by snapd, when the tests install snaps that need them. All of
# them are downloaded through the pkgproxy that image-garden set the system
# up with, which caches them.
snap install --channel=latest/"$X_SPREAD_SNAPD_RISK_LEVEL" snapd

# Show the version of snapd from the snap.
snap version | tee snap-version.snapd-snap.debug
