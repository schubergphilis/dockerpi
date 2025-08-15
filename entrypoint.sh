# #!/bin/bash
# set -xeuo pipefail

# GIB_IN_BYTES="1073741824"

# target="${1:-pi1}"
# image_path="/sdcard/filesystem.img"
# zip_path="/filesystem.zip"
# xz_path="/filesystem.img.xz"

# extract_image() {
#   if [ -e "${image_path}" ]; then
#     echo "A filesystem image already exists at ${image_path}!"
#     exit 1
#   fi

#   if [ -e "${zip_path}" ]; then
#     echo "Extracting fresh filesystem..."
#     unzip "${zip_path}"
#     mv -- *.img "${image_path}"
#   elif [ -e "${xz_path}" ]; then
#     echo "Decompressing filesystem image..."
#     xz --decompress "$xz_path"
#     mv -- *.img "$image_path"
#   else
#     echo "No supported filesystem image found at ${zip_path} or ${xz_path}!"
#     exit 1
#   fi
# }

# bla() {
#   qemu-img info "${image_path}"

#   image_size_in_bytes=$(qemu-img info "${image_path}" | grep "virtual size" | sed -E 's/.*\(([^)]+) bytes\)/\1/')

#   rem=$(expr "${image_size_in_bytes}" % $(expr ${GIB_IN_BYTES} \* 2))

#   if [ "${rem}" -ne 0 ]; then
#       div=$(expr "${image_size_in_bytes}" / $(expr ${GIB_IN_BYTES} \* 2))
#       new_size_in_gib=$(expr \( $div + 1 \) \* 2)
#       echo "Rounding image size up to ${new_size_in_gib}GiB so it's a multiple of 2GiB..."
#       qemu-img resize "$image_path" "${new_size_in_gib}G"
#   fi
# }

# holamundo() {
# if [ "${target}" = "pi1" ]; then
#   emulator=qemu-system-arm
#   kernel="/root/qemu-rpi-kernel/kernel-qemu-4.19.50-buster"
#   dtb="/root/qemu-rpi-kernel/versatile-pb.dtb"
#   machine=versatilepb
#   memory=256m
#   kernel_pattern=""
#   root=/dev/sda2
#   append=""
#   nic="--net nic --net user,hostfwd=tcp::5022-:22"
# elif [ "${target}" = "pi2" ]; then
#   emulator=qemu-system-arm
#   machine=raspi2b
#   memory=1024m
#   kernel_pattern=kernel7.img
#   dtb_pattern=bcm2709-rpi-2-b.dtb
#   append="dwc_otg.fiq_fsm_enable=0"
#   nic="-netdev user,id=net0,hostfwd=tcp::5022-:22 -device usb-net,netdev=net0"
# elif [ "${target}" = "pi3" ]; then
#   emulator=qemu-system-aarch64
#   machine=raspi3b
#   memory=1024m
#   kernel_pattern=kernel8.img
#   dtb_pattern=bcm2710-rpi-3-b-plus.dtb
#   append="dwc_otg.fiq_fsm_enable=0"
#   nic="-netdev user,id=net0,hostfwd=tcp::5022-:22 -device usb-net,netdev=net0"
# else
#   echo "Target ${target} not supported"
#   echo "Supported targets: pi1 pi2 pi3"
#   exit 2
# fi

# echo "==================== CP42.4 ======================="

# if [ "${kernel_pattern}" ] && [ "${dtb_pattern}" ]; then
#   fat_path="/fat.img"
#   echo "Extracting partitions"
#   fdisk -l ${image_path} \
#     | awk "/^[^ ]*1/{print \"dd if=${image_path} of=${fat_path} bs=512 skip=\"\$4\" count=\"\$6}" \
#     | sh

#   echo "Extracting boot filesystem"
#   fat_folder="/fat"
#   mkdir -p "${fat_folder}"
#   fatcat -x "${fat_folder}" "${fat_path}"

#   root=/dev/mmcblk0p2

#   echo "Searching for kernel='${kernel_pattern}'"
#   kernel=$(find "${fat_folder}" -name "${kernel_pattern}")

#   echo "Searching for dtb='${dtb_pattern}'"
#   dtb=$(find "${fat_folder}" -name "${dtb_pattern}")
# fi

# if [ "${kernel}" = "" ] || [ "${dtb}" = "" ]; then
#   echo "Missing kernel='${kernel}' or dtb='${dtb}'"
#   exit 2
# fi

# echo "Booting QEMU machine \"${machine}\" with kernel=${kernel} dtb=${dtb}"
# echo "==================== CP42.5 ======================="
# exec ${emulator} \
#   --machine "${machine}" \
#   --cpu arm1176 \
#   --m "${memory}" \
#   --drive "format=raw,file=${image_path}" \
#   ${nic} \
#   --dtb "${dtb}" \
#   --kernel "${kernel}" \
#   --append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=${root} rootwait panic=1 ${append}" \
#   --no-reboot \
#   --display none \
#   --serial mon:stdio
# }

# main() {
#   extract_image
#   bla
#   holamundo
#   # helloworld
# }

# main



#!/bin/bash
set -euo pipefail

TARGET_PI="${1:-pi1}"

readonly GIB_IN_BYTES=1073741824
readonly IMAGE_PATH="/sdcard/filesystem.img"
readonly SUPPORTED_TARGETS="pi1 pi2 pi3"
readonly XZ_PATH="/filesystem.img.xz"
readonly ZIP_PATH="/filesystem.zip"

validate() {
  if [[ ! " ${SUPPORTED_TARGETS} " =~ " ${TARGET_PI} " ]]; then
    echo "Usage: $0 [${SUPPORTED_TARGETS}]"
    exit 1
  fi
}

require_cmds() {
  local missing=0
  for cmd in qemu-img fdisk awk dd find grep sed mv unzip xz qemu-system-arm qemu-system-aarch64 fatcat; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Missing command: $cmd" >&2; missing=1; }
  done
  [[ $missing -eq 0 ]] || exit 1
}

extract_image() {
  if [ -e "${IMAGE_PATH}" ]; then
    echo "A filesystem image already exists at ${IMAGE_PATH}!"
    return
  fi

  if [ -e "${ZIP_PATH}" ]; then
    echo "Extracting fresh filesystem..."
    unzip -o "${ZIP_PATH}"
    local img_file
    img_file=$(ls -1 *.img 2>/dev/null | head -n1)
    if [ -z "$img_file" ]; then
        echo "No .img file found after unzip!"
        exit 1
    fi
    mv -- "$img_file" "${IMAGE_PATH}"
  elif [ -e "${XZ_PATH}" ]; then
    echo "Decompressing filesystem image..."
    xz --decompress "${XZ_PATH}"
    local img_file
    img_file=$(ls -1 *.img 2>/dev/null | head -n1)
    if [ -z "$img_file" ]; then
        echo "No .img file found after xz decompress!"
        exit 1
    fi
    mv -- "$img_file" "${IMAGE_PATH}"
  else
    echo "No supported filesystem image found (${ZIP_PATH} or ${XZ_PATH})!"
    exit 1
  fi
}

resize_image_to_multiple_of_2gib() {
  local info size_in_bytes rem div new_size_in_gib
  info=$(qemu-img info "${IMAGE_PATH}")
  size_in_bytes=$(echo "$info" | grep "virtual size" | sed -E 's/.*\(([^)]+) bytes\)/\1/')
  rem=$((size_in_bytes % (GIB_IN_BYTES * 2)))
  if [ "$rem" -ne 0 ]; then
    div=$((size_in_bytes / (GIB_IN_BYTES * 2)))
    new_size_in_gib=$(((div + 1) * 2))
    echo "Rounding image size up to ${new_size_in_gib}GiB so it's a multiple of 2GiB..."
    qemu-img resize "${IMAGE_PATH}" "${new_size_in_gib}G"
  fi
}

boot_qemu() {
  local append cpu dtb dtb_pattern emulator fat_folder fat_path kernel kernel_pattern machine memory need_extract_fat nic root

  fat_folder="/fat"
  fat_path="/fat.img"
  need_extract_fat=0

  case "${TARGET_PI}" in
    pi1)
      append=""
      cpu="arm1176"
      dtb="/root/qemu-rpi-kernel/versatile-pb.dtb"
      dtb_pattern=""
      emulator="qemu-system-arm"
      kernel="/root/qemu-rpi-kernel/kernel-qemu-4.19.50-buster"
      kernel_pattern=""
      machine="versatilepb"
      memory="256m"
      need_extract_fat=0
      nic="--net nic --net user,hostfwd=tcp::5022-:22"
      root="/dev/sda2"
      ;;
    pi2)
      append="dwc_otg.fiq_fsm_enable=0"
      cpu="cortex-a7"
      dtb=""
      dtb_pattern="bcm2709-rpi-2-b.dtb"
      emulator="qemu-system-arm"
      kernel=""
      kernel_pattern="kernel7.img"
      machine="raspi2b"
      memory="1024m"
      need_extract_fat=1
      nic="-netdev user,id=net0,hostfwd=tcp::5022-:22 -device usb-net,netdev=net0"
      root="/dev/mmcblk0p2"
      ;;
    pi3)
      append="dwc_otg.fiq_fsm_enable=0"
      cpu="cortex-a53"
      dtb=""
      dtb_pattern="bcm2710-rpi-3-b-plus.dtb"
      emulator="qemu-system-aarch64"
      kernel=""
      kernel_pattern="kernel8.img"
      machine="raspi3b"
      memory="1024m"
      need_extract_fat=1
      nic="-netdev user,id=net0,hostfwd=tcp::5022-:22 -device usb-net,netdev=net0"
      root="/dev/mmcblk0p2"
      ;;
    *)
      echo "Target '${target}' not supported"
      echo "Supported targets: ${SUPPORTED_TARGETS}"
      exit 2
  esac

  if (( need_extract_fat )); then
    echo "Extracting partition table..."
    local fdisk_out
    fdisk_out=$(fdisk -l "${IMAGE_PATH}")

    local boot_line
    boot_line=$(echo "${fdisk_out}" | awk '/img1/{print}')
    if [ -z "$boot_line" ]; then
        boot_line=$(echo "${fdisk_out}" | awk '/^\/.*img1/{print}')
    fi
    if [ -z "$boot_line" ]; then
        boot_line=$(echo "${fdisk_out}" | grep "^${IMAGE_PATH}" | head -n1)
    fi
    if [ -z "$boot_line" ]; then
        echo "Cannot find boot partition in fdisk output."
        exit 1
    fi

    local skip count
    read -r _ _ _ _ skip count _ <<<"$boot_line"

    echo "dd if=${IMAGE_PATH} of=${fat_path} bs=512 skip=${skip} count=${count}"
    dd if="${IMAGE_PATH}" of="${fat_path}" bs=512 skip="${skip}" count="${count}" status=none

    echo "Extracting boot filesystem..."
    mkdir -p "${fat_folder}"
    fatcat -x "${fat_folder}" "${fat_path}"

    echo "Looking for kernel (${kernel_pattern})..."
    kernel=$(find "${fat_folder}" -name "${kernel_pattern}" | head -n1)
    if [ -z "$kernel" ]; then
        echo "Kernel pattern '${kernel_pattern}' not found."
        exit 1
    fi
    echo "Looking for dtb (${dtb_pattern})..."
    dtb=$(find "${fat_folder}" -name "${dtb_pattern}" | head -n1)
    if [ -z "$dtb" ]; then
        echo "DTB pattern '${dtb_pattern}' not found."
        exit 1
    fi

    trap 'rm -rf "${fat_folder}" "${fat_path}"' EXIT
  fi

  if [ -z "${kernel:-}" ] || [ -z "${dtb:-}" ]; then
    echo "Kernel or DTB not found/missing!"
    exit 2
  fi

  echo "Booting QEMU (${machine})"
  exec ${emulator} \
    --machine "${machine}" \
    --cpu "${cpu}" \
    -m "${memory}" \
    --drive "format=raw,file=${IMAGE_PATH}" \
    ${nic} \
    --dtb "${dtb}" \
    --kernel "${kernel}" \
    --append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=${root} rootwait panic=1 ${append}" \
    --no-reboot \
    --display none \
    --serial mon:stdio
}

main() {
  validate
  require_cmds
  extract_image
  resize_image_to_multiple_of_2gib
  boot_qemu
}

main
