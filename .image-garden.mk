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
packages:
- apparmor
- curl
- jq
# To clone and build snapd.
- base-devel
- git
endef

define AMAZONLINUX_2_CLOUD_INIT_USER_DATA_TEMPLATE
$(BASE_CLOUD_INIT_USER_DATA_TEMPLATE)
$(snapd_suspend_workaround)
# https://documentation.ubuntu.com/lxd/latest/howto/network_bridge_firewalld/#prevent-connectivity-issues-with-lxd-and-docker
- echo net.ipv4.conf.all.forwarding=1 >/etc/sysctl.d/99-forwarding.conf
- systemctl enable --now snapd.socket
# Amazon 2 does not implement the power_state cloud-init plugin.
- shutdown --poweroff now
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
packages:
- curl
- jq
endef

define OPENSUSE_tumbleweed-apparmor_CLOUD_INIT_USER_DATA_TEMPLATE
$(BASE_CLOUD_INIT_USER_DATA_TEMPLATE)
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
packages:
- curl
- jq
endef

define OPENSUSE_tumbleweed-selinux_CLOUD_INIT_USER_DATA_TEMPLATE
$(BASE_CLOUD_INIT_USER_DATA_TEMPLATE)
$(snapd_suspend_workaround)
# https://documentation.ubuntu.com/lxd/latest/howto/network_bridge_firewalld/#prevent-connectivity-issues-with-lxd-and-docker
- echo net.ipv4.conf.all.forwarding=1 >/etc/sysctl.d/99-forwarding.conf
# Add the system:snappy repository and install snapd
- zypper addrepo --refresh https://download.opensuse.org/repositories/system:/snappy/openSUSE_Tumbleweed snappy
- zypper --gpg-auto-import-keys refresh
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
packages:
- curl
- jq
endef

# apparmor variant
opensuse-cloud-tumbleweed-apparmor.x86_64.run: $(MAKEFILE_LIST) | opensuse-cloud-tumbleweed-apparmor.x86_64.qcow2 opensuse-cloud-tumbleweed.x86_64.efi-code.img opensuse-cloud-tumbleweed.x86_64.efi-vars.img
	echo "#!/bin/sh" >$@
	echo 'set -xeu' >>$@
	echo "# WARNING: The .qcow2 file refers to a file in $(GARDEN_DL_DIR)/opensuse" >>$@
	echo '$(strip $(call QEMU_SYSTEM_X86_64_EFI_CMDLINE,$(word 1,$|),$(word 2,$|),$(word 3,$|)) "$$@")' >>$@
	chmod +x $@

opensuse-cloud-tumbleweed-apparmor.x86_64.qcow2: $(GARDEN_DL_DIR)/opensuse/opensuse-cloud-tumbleweed.x86_64.qcow2 opensuse-cloud-tumbleweed-apparmor.x86_64.seed.iso opensuse-cloud-tumbleweed-apparmor.x86_64.efi-code.img opensuse-cloud-tumbleweed-apparmor.x86_64.efi-vars.img
	$(strip $(QEMU_IMG) create -f qcow2 -b $< -F qcow2 $@ $(QEMU_IMG_SIZE))
	$(strip $(call QEMU_SYSTEM_X86_64_EFI_CMDLINE,$@,$(word 3,$^),$(word 4,$^)) \
    -drive file=$(word 2,$^),format=raw,id=drive1,if=none,readonly=true,media=cdrom \
    -device virtio-blk,drive=drive1 \
    | tee $@.log)

opensuse-cloud-tumbleweed-apparmor.x86_64.meta-data: export META_DATA = $(call CLOUD_INIT_META_DATA_TEMPLATE,opensuse)
opensuse-cloud-tumbleweed-apparmor.x86_64.meta-data: $(MAKEFILE_LIST)
	echo "$${META_DATA}" | tee $@
	touch --reference=$(shell stat $^ -c '%Y %n' | sort -nr | cut -d ' ' -f 2 | head -n 1) $@

opensuse-cloud-tumbleweed-apparmor.x86_64.user-data: export USER_DATA = $(call $(call PICK_CLOUD_INIT_USER_DATA_TEMPLATE_FOR,OPENSUSE,tumbleweed-apparmor),opensuse-tumbleweed,opensuse)
opensuse-cloud-tumbleweed-apparmor.x86_64.user-data: $(MAKEFILE_LIST) $(wildcard $(GARDEN_PROJECT_DIR)/.image-garden.mk)
	echo "$${USER_DATA}" | tee $@
	touch --reference=$(shell stat $^ -c '%Y %n' | sort -nr | cut -d ' ' -f 2 | head -n 1) $@

# selinux variant
opensuse-cloud-tumbleweed-selinux.x86_64.run: $(MAKEFILE_LIST) | opensuse-cloud-tumbleweed-selinux.x86_64.qcow2 opensuse-cloud-tumbleweed.x86_64.efi-code.img opensuse-cloud-tumbleweed.x86_64.efi-vars.img
	echo "#!/bin/sh" >$@
	echo 'set -xeu' >>$@
	echo "# WARNING: The .qcow2 file refers to a file in $(GARDEN_DL_DIR)/opensuse" >>$@
	echo '$(strip $(call QEMU_SYSTEM_X86_64_EFI_CMDLINE,$(word 1,$|),$(word 2,$|),$(word 3,$|)) "$$@")' >>$@
	chmod +x $@

opensuse-cloud-tumbleweed-selinux.x86_64.qcow2: $(GARDEN_DL_DIR)/opensuse/opensuse-cloud-tumbleweed.x86_64.qcow2 opensuse-cloud-tumbleweed-selinux.x86_64.seed.iso opensuse-cloud-tumbleweed-selinux.x86_64.efi-code.img opensuse-cloud-tumbleweed-selinux.x86_64.efi-vars.img
	$(strip $(QEMU_IMG) create -f qcow2 -b $< -F qcow2 $@ $(QEMU_IMG_SIZE))
	$(strip $(call QEMU_SYSTEM_X86_64_EFI_CMDLINE,$@,$(word 3,$^),$(word 4,$^)) \
    -drive file=$(word 2,$^),format=raw,id=drive1,if=none,readonly=true,media=cdrom \
    -device virtio-blk,drive=drive1 \
    | tee $@.log)

opensuse-cloud-tumbleweed-selinux.x86_64.meta-data: export META_DATA = $(call CLOUD_INIT_META_DATA_TEMPLATE,opensuse)
opensuse-cloud-tumbleweed-selinux.x86_64.meta-data: $(MAKEFILE_LIST)
	echo "$${META_DATA}" | tee $@
	touch --reference=$(shell stat $^ -c '%Y %n' | sort -nr | cut -d ' ' -f 2 | head -n 1) $@

opensuse-cloud-tumbleweed-selinux.x86_64.user-data: export USER_DATA = $(call $(call PICK_CLOUD_INIT_USER_DATA_TEMPLATE_FOR,OPENSUSE,tumbleweed-selinux),opensuse-tumbleweed,opensuse)
opensuse-cloud-tumbleweed-selinux.x86_64.user-data: $(MAKEFILE_LIST) $(wildcard $(GARDEN_PROJECT_DIR)/.image-garden.mk)
	echo "$${USER_DATA}" | tee $@
	touch --reference=$(shell stat $^ -c '%Y %n' | sort -nr | cut -d ' ' -f 2 | head -n 1) $@

# include local overrides if present
-include $(GARDEN_PROJECT_DIR)/.image-garden.local.mk
