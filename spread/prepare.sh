#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Canonical Ltd.
set -xeu

# Show kernel version and system information. All the files with the .debug
# extension are displayed by project-wide debug handler.
uname -a
if [ -f /etc/os-release ]; then
	tee os-release.debug </etc/os-release
fi

# Show the version of classically packaged snapd.
snap version | tee snap-version.distro.debug

case "$SPREAD_SYSTEM" in
debian-cloud-sid)
	# If requested, download a custom build of snapd from salsa.debian.org
	# artifact page. An example job is https://salsa.debian.org/debian/snapd/-/jobs/7311035/
	# from pipeline https://salsa.debian.org/debian/snapd/-/pipelines/838704
	# This is the "build" job from standard Salsa CI pipeline. The job offers
	# x86_64 debian packages to install from the debian/output/ directory inside
	# the zip file that is the artifact transport container.
	#
	# The limitation on the system name is because snapd built on Salsa is only
	# really compatible with Debian unstable (given that it is also built there).
	if [ -n "$X_SPREAD_SALSA_JOB_ID" ]; then
		curl \
			--location \
			--insecure \
			--fail \
			--output /var/tmp/snapd.salsa.zip \
			https://salsa.debian.org/debian/snapd/-/jobs/"$X_SPREAD_SALSA_JOB_ID"/artifacts/download
		mkdir -p /var/tmp/snapd.salsa
		unzip -d /var/tmp/snapd.salsa /var/tmp/snapd.salsa.zip
		apt install -y \
			/var/tmp/snapd.salsa/debian/output/snapd_*.deb \
			/var/tmp/snapd.salsa/debian/output/snap-confine_*.deb
		rm -rf /var/tmp/snapd.salsa
		# Show the version of classically updated snapd.
		snap version | tee snap-version.salsa.debug
	fi
	;;
fedora-* | centos-*)
	# If requested, download and install a custom build of snapd from the
	# Fedora update system, Bodhi.
	if [ -n "$X_SPREAD_BODHI_ADVISORY_ID" ]; then
		dnf upgrade --refresh --advisory="$X_SPREAD_BODHI_ADVISORY_ID"
		# Show the version of classically updated snapd.
		snap version | tee snap-version.bodhi.debug
	fi
	;;
archlinux-*)
	if [ -n "$X_SPREAD_ARCH_SNAPD_PR" ]; then
		rm -rf /var/tmp/snapd
		upstream_repo="$(echo "$X_SPREAD_ARCH_SNAPD_PR" | sed -e 's#/pull/[0-9]\+##')"
		pr_num="$(basename "$X_SPREAD_ARCH_SNAPD_PR")"
		sudo -u archlinux git clone "$upstream_repo" /var/tmp/snapd
		sudo -u archlinux sh -c "cd /var/tmp/snapd && git fetch origin pull/$pr_num/head:pr && git checkout pr"
		(
			cd /var/tmp/snapd
			if [ -n "$X_SPREAD_ARCH_SNAPD_REPO_SUBDIR" ]; then
				cd "$X_SPREAD_ARCH_SNAPD_REPO_SUBDIR" || exit 1
			fi
			sudo -u archlinux sh -c 'makepkg -si --noconfirm'
		)
		systemctl enable --now snapd.socket
		systemctl enable --now snapd.apparmor.service
	fi
	;;
esac

# Show the list of pre-installed snaps.
snap list | tee snap-list-preinstalled.debug

# We don't expect any snaps. This will change once we start testing with
# desktop images. Currently we remove pre-installed snaps that some Ubuntu
# releases ship. This includes snapd snap.
snap list 2>&1 | grep -q 'No snaps are installed yet'

# Show network config.
ip addr list | tee ip-addr-list.debug

# See if we can resolve snapcraft.io
getent hosts snapcraft.io | tee getent-hosts-snapcraft-io.debug

mkdir "$X_SPREAD_CACHE_DIR"
# Opportunistically mount the architecture-specific cache directory.
# NOTE: We don't enable DAX support as that is not universally enabled
# in guest kernels. Failure to mount is non-fatal, as it only affects
# performance.
mount -t virtiofs spread-cache "$X_SPREAD_CACHE_DIR" || true

exec "$SPREAD_PATH"/spread/install-snapd-and-bases.sh
