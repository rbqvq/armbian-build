# Rockchip RK3568 quad core 2-4GB 2x GbE eMMC HDMI WiFi USB3 2x M.2 (B/E-Key)
BOARD_NAME="Photonicat"
BOARD_VENDOR="ariaboard"
BOARDFAMILY="rockchip64"
BOARD_MAINTAINER="rbqvq"
INTRODUCED="2022"
KERNEL_TARGET="current,edge"
KERNEL_TEST_TARGET="current"
FULL_DESKTOP="yes"
BOOT_SOC="rk3568"
BOOT_LOGO="desktop"
BOOT_FDT_FILE="rockchip/rk3568-photonicat.dtb"
BOOTCONFIG="photonicat-rk3568_defconfig"
IMAGE_PARTITION_TABLE="gpt"
MODULES="ledtrig_netdev"
ENABLE_EXTENSIONS="photonicat-pm"

# Mainline U-Boot
function post_family_config__photonicat_mainline_uboot() {
	display_alert "$BOARD" "Using mainline U-Boot for $BOARD / $BRANCH" "info"

	declare -g BOOTSOURCE="https://github.com/u-boot/u-boot.git"
	declare -g BOOTBRANCH="tag:v2026.07"
	declare -g BOOTPATCHDIR="v2026.07/board_${BOARD}"

	declare -g UBOOT_TARGET_MAP="BL31=${RKBIN_DIR}/${BL31_BLOB} ROCKCHIP_TPL=${RKBIN_DIR}/${DDR_BLOB};;u-boot-rockchip.bin"

	unset uboot_custom_postprocess write_uboot_platform write_uboot_platform_mtd

	function write_uboot_platform() {
		dd if=$1/u-boot-rockchip.bin of=$2 seek=64 conv=notrunc status=none
	}
}

function post_family_tweaks__photonicat_udev_network_interfaces() {
	display_alert "$BOARD" "Renaming interfaces" "info"

	mkdir -p $SDCARD/etc/udev/rules.d/
	cat <<- EOF > "${SDCARD}/etc/udev/rules.d/70-persistent-net.rules"
		SUBSYSTEM=="net", ACTION=="add", KERNELS=="fe010000.ethernet", NAME:="wan"
		SUBSYSTEM=="net", ACTION=="add", KERNELS=="fe2a0000.ethernet", NAME:="lan"
	EOF
}

