# Qualcomm Snapdragon 8cx Gen 3 Adreno 690 Qualcomm WCN6855 Wi-Fi 6E Bluetooth 5.1
BOARD_NAME="Windows Dev Kit 2023"
BOARD_VENDOR="generic"
BOARDFAMILY="uefi-arm64"
BOARD_MAINTAINER="rbqvq"
KERNEL_TARGET="current,edge,legacy"
KERNEL_TEST_TARGET="current"
BOOT_LOGO=desktop

# Boot via EFI + DT
GRUB_CMDLINE_LINUX_DEFAULT="clk_ignore_unused pd_ignore_unused arm64.nopauth efi=noruntime" # iommu.passthrough=0 iommu.strict=0 pcie_aspm.policy=powersupersave
BOOT_FDT_FILE="qcom/sc8280xp-microsoft-blackrock.dtb"
enable_extension "grub-with-dtb"

# Use the full firmware, complete linux-firmware with armbian-firmware
BOARD_FIRMWARE_INSTALL="-full"

# Follow the "thinkpad-x13s.conf"
function windows_devkit_2023_is_userspace_supported() {
	[[ "${RELEASE}" == "trixie" || "${RELEASE}" == "sid" || "${RELEASE}" == "noble" || "${RELEASE}" == "oracular" ]] && return 0
	return 1
}

# Reference: https://wiki.debian.org/InstallingDebianOn/Thinkpad/X13s
function post_family_config__debian_now_has_userspace_for_the_windows_devkit_2023() {
	if !windows_devkit_2023_is_userspace_supported; then
		if [[ "${RELEASE}" != "" ]]; then
			display_alert "Missing userspace for ${BOARD}" "${RELEASE} does not have the userspace necessary to support the ${BOARD}" "warn"
		fi
		return 0
	fi

	display_alert "Setting up extra packages for ${BOARD}" "${RELEASE}///${BOARD}" "info"
	add_packages_to_image "bluez" "bluetooth"        # for bluetooth stuff
	add_packages_to_image "protection-domain-mapper"
	add_packages_to_image "qrtr-tools"
	add_packages_to_image "acpi"
	add_packages_to_image "zstd"                     # for zstd compression of initrd
	add_packages_to_image "mtools"                   # for access to the EFI partition

	# Also needed, not listed here:
	# - mesa > 23.1.5; see https://packages.ubuntu.com/mesa-vulkan-drivers and https://packages.debian.org/mesa-vulkan-drivers
}

function post_family_tweaks_bsp__windows_devkit_2023_bsp_bluetooth_addr() {
	### The bluetooth does not have a public MAC address set in DT, and BT won't start without one.
	### Use a systemd override to hook up setting a public-addr before starting bluetoothd
	declare random_mac_address="" # would be much better to rnd mac on board-side though
	random_mac_address=$(printf '02:%02X:%02X:%02X:%02X:%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
	display_alert "Adding systemd override for bluetooth public address init" "${BOARD} :: bt mac ${random_mac_address}" "info"

	add_file_from_stdin_to_bsp_destination "/etc/systemd/system/bluetooth.service.d/override.conf" <<- EOD
		[Service]
		ExecStartPre=/bin/bash -c 'sleep 5 && yes | btmgmt public-addr ${random_mac_address}'
	EOD
}

##
## Include certain firmware in the initrd
##
function post_family_tweaks_bsp__windows_devkit_2023_bsp_firmware_in_initrd() {
	display_alert "Adding to bsp-cli" "${BOARD}: firmware in initrd" "info"
	declare file_added_to_bsp_destination # will be filled in by add_file_from_stdin_to_bsp_destination
	add_file_from_stdin_to_bsp_destination "/etc/initramfs-tools/hooks/windows-devkit-2023-firmware" <<- 'FIRMWARE_HOOK'
		#!/bin/bash
		[[ "$1" == "prereqs" ]] && exit 0
		. /usr/share/initramfs-tools/hook-functions
		for f in /lib/firmware/qcom/sc8280xp/microsoft/blackrock/* ; do
			add_firmware "${f#/lib/firmware/}"
		done
		add_firmware "qcom/a660_sqe.fw" # extra one for dpu
		add_firmware "qcom/a660_gmu.bin" # extra one for gpu
		add_firmware "qcom/a690_gmu.bin" # extra one for gpu (is a symlink)
	FIRMWARE_HOOK
	run_host_command_logged chmod -v +x "${file_added_to_bsp_destination}"
}

## Modules, required to boot, add them to initrd; might need to be done in '.d/windows-devkit-2023-modules' instead
function post_family_tweaks_bsp__windows_devkit_2023_bsp_modules_in_initrd() {
	display_alert "Adding to bsp-cli" "${BOARD}: modules in initrd" "info"
	add_file_from_stdin_to_bsp_destination "/etc/initramfs-tools/modules" <<- 'EXTRA_MODULES'
		phy_qcom_qmp_pcie
		pcie_qcom
		phy_qcom
		qmp_pcie
		phy_qcom_qmp_combo
		qrtr
		phy_qcom_edp
		gpio_sbu_mux
		i2c_hid_of
		i2c_qcom_geni
		pmic_glink_altmode
		leds_qcom_lpg
		qcom_q6v5_pas  # This module loads a lot of FW blobs
		msm
		nvme
		usb_storage
		uas
	EXTRA_MODULES
}

# armbian-firstrun waits for systemd to be ready, but snapd.seeded might cause it to hang due to wrong clock.
# if the battery runs out, the clock is reset to 1970. This causes snapd.seeded to hang, and armbian-firstrun to hang.
function pre_customize_image__disable_snapd_seeded() {
	[[ "${DISTRIBUTION}" != "Ubuntu" ]] && return 0 # only needed for Ubuntu
	display_alert "Disabling snapd.seeded" "${BOARD}" "info"
	chroot_sdcard systemctl disable snapd.seeded.service "||" true
}
