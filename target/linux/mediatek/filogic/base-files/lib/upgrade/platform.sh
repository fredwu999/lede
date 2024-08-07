REQUIRE_IMAGE_METADATA=1
RAMFS_COPY_BIN='fitblk'

asus_initial_setup()
{
	# initialize UBI if it's running on initramfs
	[ "$(rootfs_type)" = "tmpfs" ] || return 0

	ubirmvol /dev/ubi0 -N rootfs
	ubirmvol /dev/ubi0 -N rootfs_data
	ubirmvol /dev/ubi0 -N jffs2
	ubimkvol /dev/ubi0 -N jffs2 -s 0x3e000
}

platform_get_bootdev() {
	local rootdisk="$(cat /sys/firmware/devicetree/base/chosen/rootdisk)"
	local handle bootdev
	for handle in /sys/class/block/*/of_node/phandle /sys/class/block/*/device/of_node/phandle; do
		[ ! -e "$handle" ] && continue
		if [ "$rootdisk" = "$(cat $handle)" ]; then
			bootdev="${handle%/of_node/phandle}"
			bootdev="${bootdev%/device}"
			bootdev="${bootdev#/sys/class/block/}"
			echo "$bootdev"
			break
		fi
	done
}

platform_do_upgrade() {
	local board=$(board_name)

	case "$board" in
	asus,tuf-ax4200)
		CI_UBIPART="UBI_DEV"
		CI_KERNPART="linux"
		nand_do_upgrade "$1"
		;;
	bananapi,bpi-r3)
		local rootdev="$(cmdline_get_var root)"
		rootdev="${rootdev##*/}"
		rootdev="${rootdev%p[0-9]*}"
		case "$rootdev" in
		mmc*)
			CI_ROOTDEV="$rootdev"
			CI_KERNPART="production"
			emmc_do_upgrade "$1"
			;;
		mtdblock*)
			PART_NAME="fit"
			default_do_upgrade "$1"
			;;
		ubiblock*)
			CI_KERNPART="fit"
			nand_do_upgrade "$1"
			;;
		esac
		;;
	cmcc,rax3000m-emmc-ubootmod|\
	glinet,gl-mt2500|\
	glinet,gl-mt6000|\
	jdcloud,re-cs-05)
		CI_KERNPART="kernel"
		CI_ROOTPART="rootfs"
		emmc_do_upgrade "$1"
		;;
	*)
		nand_do_upgrade "$1"
		;;
	esac
}

PART_NAME=firmware

platform_check_image() {
	local board=$(board_name)
	local magic="$(get_magic_long "$1")"

	[ "$#" -gt 1 ] && return 1

	case "$board" in
	bananapi,bpi-r3|\
	bananapi,bpi-r4)
		[ "$magic" != "d00dfeed" ] && {
			echo "Invalid image type."
			return 1
		}
		return 0
		;;
	*)
		nand_do_platform_check "$board" "$1"
		return 0
		;;
	esac

	return 0
}

platform_copy_config() {
	case "$(board_name)" in
	bananapi,bpi-r3)
		case "$(cmdline_get_var root)" in
		/dev/mmc*)
			emmc_copy_config
			;;
		esac
		;;
	bananapi,bpi-r4)
		case "$(platform_get_bootdev)" in
		mmcblk*)
			emmc_copy_config
			;;
		esac
		;;
	cmcc,rax3000m-emmc|\
	glinet,gl-mt2500|\
	glinet,gl-mt6000|\
	jdcloud,re-cs-05)
		emmc_copy_config
		;;
	esac
 }
 
platform_pre_upgrade() {
	local board=$(board_name)

	case "$board" in
	asus,tuf-ax4200)
		asus_initial_setup
		;;
	esac
}
