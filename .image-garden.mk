# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Canonical Ltd.
#
# This file defines cloud-init profiles for virtual machine images that are
# used by the spread "garden" backend. In all the cases we install "jq" and
# "curl" for the needs of the test suite. For most systems we also ensure that
# a repository from which snapd can be installed is available.

# The copy of snapd that is currently in most systems is susceptible to a bug
# where snapd will deactivate itself in a racy and problematic wait. Increase
# the timeout to 15 minutes to avoid this problem.
define snapd_suspend_workaround
- |
    # Work around a bug in snapd auto-suspend feature by making snapd wait for at least 15 minutes.
    mkdir -p /etc/systemd/system/snapd.service.d;
    echo "[Service]" >/etc/systemd/system/snapd.service.d/standby.conf;
    echo "Environment=SNAPD_STANDBY_WAIT=15m" >>/etc/systemd/system/snapd.service.d/standby.conf;
endef

define ARCHLINUX_CLOUD_INIT_USER_DATA_TEMPLATE
$(BASE_CLOUD_INIT_USER_DATA_TEMPLATE)
$(snapd_suspend_workaround)
# enable AppArmor
- sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 lsm=landlock,lockdown,yama,integrity,apparmor,bpf"/' /etc/default/grub
- grub-mkconfig -o /boot/grub/grub.cfg
- systemctl enable --now apparmor.service
# https://documentation.ubuntu.com/lxd/latest/howto/network_bridge_firewalld/#prevent-connectivity-issues-with-lxd-and-docker
- echo net.ipv4.conf.all.forwarding=1 >/etc/sysctl.d/99-forwarding.conf
package_update: true
package_upgrade: true
packages:
- apparmor
- curl
- jq
# To clone and build snapd.
- base-devel
- git
bootcmd:
# systemd-time-wait-sync is enabled and will delay the boot until time has been
# updated over NTP, however all UDP traffic is blocked in self-hosted
# environments
- systemctl disable --now systemd-time-wait-sync.service
endef

define AMAZONLINUX_2_CLOUD_INIT_USER_DATA_TEMPLATE
$(BASE_CLOUD_INIT_USER_DATA_TEMPLATE)
$(snapd_suspend_workaround)
# https://documentation.ubuntu.com/lxd/latest/howto/network_bridge_firewalld/#prevent-connectivity-issues-with-lxd-and-docker
- echo net.ipv4.conf.all.forwarding=1 >/etc/sysctl.d/99-forwarding.conf
- systemctl enable --now snapd.socket
# Amazon 2 does not implement the power_state cloud-init plugin.
- shutdown --poweroff now
package_update: true
package_upgrade: true
packages:
# Curl is pre-installed but only in the "minimal" version.
# Installing curl via cloud-init fails as it conflicts with curl-minimal
- jq
# Snapd is distributed via Maciej's quasi-official archive.
yum_repos:
  snapd:
    name: snapd packages for Amazon Linux
    baseurl: https://bboozzoo.github.io/snapd-amazon-linux/amzn2/$$basearch
    gpgcheck: false
    enabled: true
endef

define AMAZONLINUX_2023_CLOUD_INIT_USER_DATA_TEMPLATE
$(BASE_CLOUD_INIT_USER_DATA_TEMPLATE)
$(snapd_suspend_workaround)
# https://documentation.ubuntu.com/lxd/latest/howto/network_bridge_firewalld/#prevent-connectivity-issues-with-lxd-and-docker
- echo net.ipv4.conf.all.forwarding=1 >/etc/sysctl.d/99-forwarding.conf
package_update: true
package_upgrade: true
packages:
# Curl is pre-installed but only in the "minimal" version.
# Installing curl via cloud-init fails as it conflicts with curl-minimal
- jq
# Snapd is distributed via Maciej's quasi-official archive.
yum_repos:
  snapd:
    name: snapd packages for Amazon Linux
    baseurl: https://bboozzoo.github.io/snapd-amazon-linux/al2023/$$basearch
    gpgcheck: false
    enabled: true
endef


define CENTOS_CLOUD_INIT_USER_DATA_TEMPLATE
$(BASE_CLOUD_INIT_USER_DATA_TEMPLATE)
$(snapd_suspend_workaround)
# https://documentation.ubuntu.com/lxd/latest/howto/network_bridge_firewalld/#prevent-connectivity-issues-with-lxd-and-docker
- echo net.ipv4.conf.all.forwarding=1 >/etc/sysctl.d/99-forwarding.conf
package_update: true
package_upgrade: true
packages:
- curl
- jq
# Snapd is distributed via the EPEL archive.
- epel-release
endef

ALMALINUX_CLOUD_INIT_USER_DATA_TEMPLATE=$(CENTOS_CLOUD_INIT_USER_DATA_TEMPLATE)
ORACLE_CLOUD_INIT_USER_DATA_TEMPLATE=$(CENTOS_CLOUD_INIT_USER_DATA_TEMPLATE)
ROCKY_CLOUD_INIT_USER_DATA_TEMPLATE=$(CENTOS_CLOUD_INIT_USER_DATA_TEMPLATE)

define DEBIAN_CLOUD_INIT_USER_DATA_TEMPLATE
$(BASE_CLOUD_INIT_USER_DATA_TEMPLATE)
$(snapd_suspend_workaround)
# https://documentation.ubuntu.com/lxd/latest/howto/network_bridge_firewalld/#prevent-connectivity-issues-with-lxd-and-docker
- echo net.ipv4.conf.all.forwarding=1 >/etc/sysctl.d/99-forwarding.conf
package_update: true
package_upgrade: true
packages:
- curl
- jq
- unzip
endef

define FEDORA_CLOUD_INIT_USER_DATA_TEMPLATE
$(BASE_CLOUD_INIT_USER_DATA_TEMPLATE)
$(snapd_suspend_workaround)
# https://documentation.ubuntu.com/lxd/latest/howto/network_bridge_firewalld/#prevent-connectivity-issues-with-lxd-and-docker
- echo net.ipv4.conf.all.forwarding=1 >/etc/sysctl.d/99-forwarding.conf
package_update: true
package_upgrade: true
packages:
- curl
- jq
endef

# openSUSE Tumbleweed instances with AppArmor and SELinux variants
$(eval $(call define-instance,opensuse-cloud-tumbleweed,apparmor))
$(eval $(call define-instance,opensuse-cloud-tumbleweed,selinux))

define OPENSUSE_TUMBLEWEED@apparmor_CLOUD_INIT_USER_DATA_TEMPLATE
$(CLOUD_INIT_USER_DATA_TEMPLATE)
$(snapd_suspend_workaround)
# https://documentation.ubuntu.com/lxd/latest/howto/network_bridge_firewalld/#prevent-connectivity-issues-with-lxd-and-docker
- echo net.ipv4.conf.all.forwarding=1 >/etc/sysctl.d/99-forwarding.conf
# Tumbleweed is now using SELinux. Switch it back to AppArmor
- sed -i -e 's/security=selinux/security=apparmor/g' /etc/default/grub
- sed -i -e 's/selinux=1//g' /etc/default/grub
- update-bootloader
# Add the system:snappy repository and install snapd
- zypper addrepo --refresh https://download.opensuse.org/repositories/system:/snappy/openSUSE_Tumbleweed snappy
- zypper --gpg-auto-import-keys refresh
package_update: true
package_upgrade: true
packages:
- curl
- jq
endef

define OPENSUSE_TUMBLEWEED@selinux_CLOUD_INIT_USER_DATA_TEMPLATE
$(CLOUD_INIT_USER_DATA_TEMPLATE)
$(snapd_suspend_workaround)
# https://documentation.ubuntu.com/lxd/latest/howto/network_bridge_firewalld/#prevent-connectivity-issues-with-lxd-and-docker
- echo net.ipv4.conf.all.forwarding=1 >/etc/sysctl.d/99-forwarding.conf
# Add the system:snappy repository and install snapd
- zypper addrepo --refresh https://download.opensuse.org/repositories/system:/snappy/openSUSE_Tumbleweed snappy
- zypper --gpg-auto-import-keys refresh
package_update: true
package_upgrade: true
packages:
- curl
- jq
endef

define UBUNTU_CLOUD_INIT_USER_DATA_TEMPLATE
$(BASE_CLOUD_INIT_USER_DATA_TEMPLATE)
$(snapd_suspend_workaround)
# https://documentation.ubuntu.com/lxd/latest/howto/network_bridge_firewalld/#prevent-connectivity-issues-with-lxd-and-docker
- echo net.ipv4.conf.all.forwarding=1 >/etc/sysctl.d/99-forwarding.conf
# Remove the LXD snap that is sometimes pre-installed.
# We want to make sure that we can remove all the base
# snaps at the end of testing.
- |
    snap wait system seed.loaded
    if snap list lxd | grep -q lxd; then
        snap remove --purge lxd
    fi
    if snap list core20 | grep -q core20; then
        snap remove --purge core20
    fi
    if snap list snapd | grep -q snapd; then
        snap remove --purge snapd
    fi
package_update: true
package_upgrade: true
packages:
- curl
- jq
endef

# include local overrides if present
-include $(GARDEN_PROJECT_DIR)/.image-garden.local.mk
