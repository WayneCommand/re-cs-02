#!/bin/sh
# Fail loudly when a symbol we depend on silently disappears from .config.
#
# `make defconfig` drops unknown or unsatisfiable symbols without any error,
# which is how luci-theme-aurora and the zh-cn translations went missing
# while the build still "succeeded". Run this right after defconfig.
#
# Usage: ./scripts/check-config.sh openwrt/.config

set -eu

cfg="${1:-.config}"
missing=""

for sym in \
	CONFIG_TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02 \
	CONFIG_TARGET_ROOTFS_INITRAMFS \
	CONFIG_CCACHE \
	CONFIG_LUCI_LANG_zh_Hans \
	CONFIG_PACKAGE_kmod-nss-wifi-drv \
	CONFIG_ATH11K_NSS_WIFI \
	CONFIG_PACKAGE_wpad-openssl \
	CONFIG_PACKAGE_luci-theme-aurora \
	CONFIG_PACKAGE_luci-app-openclash \
	CONFIG_PACKAGE_luci-app-sqm \
	CONFIG_PACKAGE_sqm-scripts \
	CONFIG_PACKAGE_luci-app-https-dns-proxy \
	CONFIG_PACKAGE_https-dns-proxy \
	CONFIG_PACKAGE_luci-proto-wireguard \
	CONFIG_PACKAGE_kmod-wireguard \
	CONFIG_PACKAGE_block-mount \
	CONFIG_PACKAGE_kmod-fs-exfat \
	CONFIG_PACKAGE_kmod-usb-storage-uas \
	CONFIG_PACKAGE_openssh-server \
	CONFIG_PACKAGE_openssh-sftp-server \
	CONFIG_PACKAGE_htop
do
	grep -q "^${sym}=y$" "$cfg" || missing="${missing} ${sym}"
done

# i18n packages are generated per app; the wildcard also proves the zh_Hans
# language switch actually translated into package symbols.
grep -q '^CONFIG_PACKAGE_luci-i18n-.*-zh-cn=y$' "$cfg" ||
	missing="${missing} CONFIG_PACKAGE_luci-i18n-*-zh-cn"

if [ -n "$missing" ]; then
	echo "error: symbols dropped by defconfig (feeds not installed for them?):" >&2
	for s in $missing; do echo "  - $s" >&2; done
	echo "hint: check 'feeds install' list in .github/workflows/build-binaries.yml" >&2
	exit 1
fi

echo "config check: all expected symbols present"
