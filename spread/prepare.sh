#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Canonical Ltd.
set -xeu

# Show kernel version and system information. All the files with the .debug
# extension are displayed by project-wide debug handler.
uname -a
if [ -f /etc/os-release ]; then
	tee os-release.debug </etc/os-release
fi

case "$SPREAD_SYSTEM" in
debian-cloud-*)
	if [ "$X_SPREAD_CI_MODE_CLEAN_INSTALL" = "true" ]; then
		apt remove --purge -y snapd
	fi
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
	elif [ -n "${X_SPREAD_LOCAL_SNAPD_PKG:-}" ]; then
		apt install -y "$SPREAD_PATH"/incoming/"$X_SPREAD_LOCAL_SNAPD_PKG"
		# Show the version of classically updated snapd.
		snap version | tee snap-version.local.debug
	elif [ ! -x /usr/bin/snap ]; then
		apt install -y snapd
	fi
	;;
oracle-* | almalinux-* | rocky-* | fedora-* | centos-*)
	# If requested, download and install a custom build of snapd from the
	# Fedora update system, Bodhi.
	if [ -n "$X_SPREAD_BODHI_ADVISORY_ID" ]; then
		if [ "$X_SPREAD_CI_MODE_CLEAN_INSTALL" = "true" ]; then
			dnf remove -y snapd
		fi
		dnf upgrade --refresh --advisory="$X_SPREAD_BODHI_ADVISORY_ID"
		# Show the version of classically updated snapd.
		snap version | tee snap-version.bodhi.debug
	elif [ -n "${X_SPREAD_LOCAL_SNAPD_PKG:-}" ]; then
		if [ "$X_SPREAD_CI_MODE_CLEAN_INSTALL" = "true" ]; then
			dnf remove -y snapd
		fi
		X_SPREAD_LOCAL_SNAP_CONFINE_PKG="${X_SPREAD_LOCAL_SNAPD_PKG/snapd/snap-confine}"
		X_SPREAD_LOCAL_SNAPD_SELINUX_PKG="${X_SPREAD_LOCAL_SNAPD_PKG/snapd/snapd-selinux}"
		X_SPREAD_LOCAL_SNAPD_SELINUX_PKG="${X_SPREAD_LOCAL_SNAPD_SELINUX_PKG/%x86_64.rpm/noarch.rpm}"
		dnf install -y \
			"$SPREAD_PATH"/incoming/"$X_SPREAD_LOCAL_SNAPD_PKG" \
			"$SPREAD_PATH"/incoming/"$X_SPREAD_LOCAL_SNAP_CONFINE_PKG" \
			"$SPREAD_PATH"/incoming/"$X_SPREAD_LOCAL_SNAPD_SELINUX_PKG"
		# Show the version of classically updated snapd.
		snap version | tee snap-version.local.debug
	elif [ ! -x /usr/bin/snap ]; then
		# snapd is in Fedora repository, for others epel-release is installed by
		# image-garden
		dnf install -y snapd
		systemctl enable --now snapd.socket
	fi
	;;
archlinux-*)
	if [ -n "$X_SPREAD_ARCH_SNAPD_PR" ]; then
		if [ "$X_SPREAD_CI_MODE_CLEAN_INSTALL" = "true" ]; then
			pacman -Rnsc --noconfirm snapd
		fi
		rm -rf /var/tmp/snapd
		upstream_repo="${X_SPREAD_ARCH_SNAPD_PR%/pull/*}"
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
	elif [ ! -x /usr/bin/snap ]; then
		# We cannot build the package as root so switch to the archlinux user.
		sudo -u archlinux git clone https://aur.archlinux.org/snapd.git /var/tmp/snapd
		cd /var/tmp/snapd && sudo -u archlinux makepkg -si --noconfirm
		systemctl enable --now snapd.socket
		systemctl enable --now snapd.apparmor.service
	fi
	;;
opensuse-*)
	if [ -n "$X_SPREAD_OPENSUSE_OBS_PROJECT" ]; then
		if [ "$X_SPREAD_CI_MODE_CLEAN_INSTALL" = "true" ]; then
			zypper rm -y snapd
		fi
		# eg. home:maciek_borzecki:branches:system:snappy
		# the repo path is: https://download.opensuse.org/repositories/home:/maciek_borzecki:/branches:/system:/snappy/<opensuse-version>
		# e.g: https://download.opensuse.org/repositories/home:/maciek_borzecki:/branches:/system:/snappy/openSUSE_Tumbleweed
		# TODO support more releases than just tumbleweed
		zypper ar --refresh \
			"https://download.opensuse.org/repositories/${X_SPREAD_OPENSUSE_OBS_PROJECT//:/:/}/openSUSE_Tumbleweed" \
			test-snappy
		zypper --gpg-auto-import-keys refresh
		# needs --allow-vendor-change to change the package vendor from default
		# system:snappy to one corresponding to the provided project
		zypper in --allow-vendor-change --from test-snappy -y snapd
		systemctl enable --now snapd.socket
		if aa-enabled; then
			systemctl enable --now snapd.apparmor.service
		fi
	elif [ ! -x /usr/bin/snap ]; then
		# repository called 'snappy' is added by image-garden
		zypper dup --from snappy
		zypper install -y snapd
		systemctl enable --now snapd.socket
		if aa-enabled; then
			systemctl enable --now snapd.apparmor.service
		fi
	fi
	;;
amazonlinux-*)
	if [ -n "$X_SPREAD_AMAZON_REPO_FILE" ]; then
		if [ "$X_SPREAD_CI_MODE_CLEAN_INSTALL" = "true" ]; then
			case "$SPREAD_SYSTEM" in
			amazonlinux-cloud-2023*)
				dnf remove -y snapd
				;;
			*)
				yum remove -y snapd
				;;
			esac
		fi
		rm -v /etc/yum.repos.d/snapd.repo
		# this contains a directory named repo containing snapd.repo file
		tar xvf "$X_SPREAD_AMAZON_REPO_FILE"
		# update the repo to point to the local directory
		sed -e "s#^baseurl=.*\(\$basearch\|sources\)#baseurl=file://$PWD/repo/\1#" <repo/snapd.repo >/etc/yum.repos.d/snapd.repo
		# since snapd is already installed this should sync snapd to whatever
		# version is available in the repository
		case "$SPREAD_SYSTEM" in
		amazonlinux-cloud-2023*)
			dnf distro-sync -y
			;;
		*)
			yum distro-sync -y
			;;
		esac
	elif [ ! -x /usr/bin/snap ]; then
		# repository is added by image-garden setup
		case "$SPREAD_SYSTEM" in
		amazonlinux-cloud-2023*)
			dnf install -y snapd
			;;
		*)
			yum install -y snapd
			;;
		esac
	fi
	;;
esac

# Show the version of classically packaged snapd.
snap version | tee snap-version.distro.debug

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
