#!/bin/bash

# -e - Exit on error
# -u - Treat unset variables as an error
# -x - Print commands before executing them
set -eux

EDGE_AI_SDK_URL=https://dr-download.ti.com/software-development/software-development-kit-sdk/MD-NQjfZVt1aJ/11.00.00.08/ti-processor-sdk-linux-edgeai-j722s-evm-11_00_00_08-Linux-x86-Install.bin
SDK_RTOS_URL="https://dr-download.ti.com/software-development/software-development-kit-sdk/MD-1bSfTnVt5d/11.00.00.06/ti-processor-sdk-rtos-j722s-evm-11_00_00_06.tar.gz"

DOWNLOAD_CACHE_DIR=.download-cache
SDK_INSTALL_BIN_PATH=$DOWNLOAD_CACHE_DIR/sdk-install.bin
SDK_RTOS_INSTALL_BIN_PATH=$DOWNLOAD_CACHE_DIR/sdk-rtos-install.bin

TI_SDK_PATH="/app/tisdk"
TI_SDK_LINUX_PATH="${TI_SDK_PATH}/ti-processor-sdk-linux-edgeai-j722s-evm-11_00_00_08"
TI_SDK_RTOS_PATH="${TI_SDK_PATH}/ti-processor-sdk-rtos-j722s-evm-11_00_00_06"

BOOTFS_GZ_PATH="${TI_SDK_LINUX_PATH}/board-support/prebuilt-images/boot-edgeai-j722s-evm.tar.gz"
ROOTFS_XZ_PATH="${TI_SDK_LINUX_PATH}/filesystem/tisdk-edgeai-image-j722s-evm.rootfs.tar.xz"

CROSS_COMPILE_64="${TI_SDK_LINUX_PATH}/linux-devkit/sysroots/x86_64-arago-linux/usr/bin/aarch64-oe-linux/aarch64-oe-linux-"
SYSROOT_64="${TI_SDK_LINUX_PATH}/linux-devkit/sysroots/aarch64-oe-linux"
CC_64="${CROSS_COMPILE_64}gcc --sysroot=${SYSROOT_64}"
CROSS_COMPILE_32="${TI_SDK_LINUX_PATH}/k3r5-devkit/sysroots/x86_64-arago-linux/usr/bin/arm-oe-eabi/arm-oe-eabi-"
PREBUILT_IMAGES="${TI_SDK_LINUX_PATH}/board-support/prebuilt-images"

BUILD_DIR=$(pwd)
MOUNT_BOOT="${TI_SDK_PATH}/fs-boot"
MOUNT_ROOTFS="${TI_SDK_PATH}/fs-rootfs"
IMG_PATH="${BUILD_DIR}/images/beagleyai.img"
IMG_XZ_PATH="${BUILD_DIR}/images/beagleyai.img.xz"


install_genimage() {
	echo "Entering top level build dir..."
	if [ ! -d $TI_SDK_PATH ]; then
		mkdir $TI_SDK_PATH
	fi
	cd $TI_SDK_PATH
	

	echo "Installing genimage apt deps..."
	apt-get update
	apt-get install -y libconfuse-dev mtools

	echo "Downloading genimage..."
	git clone https://github.com/pengutronix/genimage.git

	echo "Checking out tested commit..."
	cd genimage
	echo $PWD
	git checkout 808cc5936c73e88f4a7cc01fe01415e5f7666c8a

	echo "Building genimage..."
	./autogen.sh
	./configure CFLAGS='-g -O0' --prefix=/usr
	make

	echo "Installing genimage..."
	make install

	echo "Making filesystem directories..."
	mkdir $MOUNT_BOOT
	mkdir $MOUNT_ROOTFS
}

install_linux_sdk() {
	echo "Entering build dir..."
	cd $BUILD_DIR

	echo "Ensuring cache directory exists..."
	mkdir -p $DOWNLOAD_CACHE_DIR

	echo "Downloading Edge AI SDK..."
	if [ ! -f "$SDK_INSTALL_BIN_PATH" ]; then
		echo "File '$SDK_INSTALL_BIN_PATH' does not exist, downloading with wget..."
		wget --quiet -O "$SDK_INSTALL_BIN_PATH" "$EDGE_AI_SDK_URL"
	else
		echo "File '$SDK_INSTALL_BIN_PATH' already exists, skipping download."
	fi

	echo "Making SDK executable..."
	chmod +x $SDK_INSTALL_BIN_PATH

	echo "Installing SDK..."
	./$SDK_INSTALL_BIN_PATH

	# Docs say to run ./setup.sh but that is interactive and 
	# adds a lot of target development tools that we don't need...
	#
	# Let's manually run some tools from the bin/ directory instead
	echo "Installing SDK package dependencies..."
	$TI_SDK_LINUX_PATH/bin/setup-package-install.sh
}

install_rtos_sdk() {
	echo "Ensuring cache directory exists..."
	mkdir -p $DOWNLOAD_CACHE_DIR

	echo "Downloading RTOS SDK..."
	if [ ! -f "$SDK_RTOS_INSTALL_BIN_PATH" ]; then
		echo "File '$SDK_RTOS_INSTALL_BIN_PATH' does not exist, downloading with wget..."
		wget --quiet -O "$SDK_RTOS_INSTALL_BIN_PATH" "$SDK_RTOS_URL"
	else
		echo "File '$SDK_RTOS_INSTALL_BIN_PATH' already exists, skipping download."
	fi

	echo "Extracting RTOS SDK..."
	tar -xzf $SDK_RTOS_INSTALL_BIN_PATH -C $TI_SDK_PATH
}

checkout_linux_code() {
	echo "Entering SDK..."
	cd $TI_SDK_LINUX_PATH

	echo "Inspecting SDK directory..."
	ls -al
	ls -al filesystem
	#  sdk-install.sh is _sometimes_ required? Unclear why.
	# ./sdk-install.sh

	echo "Installing linux-devkit + k3r5-devkit..."

	# FIXME: Switch to Beagleboard maintained branch
	echo "U-Boot checkout"
	git clone \
		--single-branch --branch ti-u-boot-2025.01-bb \
		--depth 1 \
		https://github.com/goat-hill/ti-u-boot.git \
		u-boot-ci

	# FIXME: Switch to Beagleboard maintained branch
	echo "Kernel checkout"
	git clone \
		--single-branch --branch ti-linux-6.12.y-bb \
		--depth 1 \
		https://github.com/goat-hill/linux \
		linux-ci
}

populate_partitions() {
	# We use  to preserve file ownership
	# We use --no-same-owner so files are owned by root
	echo "Extracting boot filesystem..."
	tar --no-same-owner -xzf $BOOTFS_GZ_PATH -C $MOUNT_BOOT
	ls -al $MOUNT_BOOT

	echo "Extracting root filesystem..."
	tar -xJf $ROOTFS_XZ_PATH -C $MOUNT_ROOTFS
	ls -al $MOUNT_ROOTFS
}

cc33xx_firmware_install() {
	echo "Entering SDK..."
	cd $TI_SDK_PATH

	echo "Downloading firmware installer..."
	wget https://dr-download.ti.com/software-development/driver-or-library/MD-UoRUAALCjn/1.0.2.10/cc33xx_linux_package_1_0_2_10.run

	echo "Executing firmware installer..."
	chmod u+x cc33xx_linux_package_1_0_2_10.run
	./cc33xx_linux_package_1_0_2_10.run < /dev/null

	echo "Copying firmware lib/ to rootfs..."
	cp -r /opt/ti/cc33xx_linux_package_1_0_2_10/cc33xx/cc33xx_rootfs/lib $MOUNT_ROOTFS/usr
}

checkout_rtos_code() {
	echo "Entering RTOS directory..."
	cd $TI_SDK_RTOS_PATH

	echo "Inspecting RTOS directory..."
	ls -al

	echo "Removing existing vision_apps/ directory..."
	rm -rf vision_apps

	# FIXME: Switch to Beagleboard maintained branch
	echo "Cloning modified vision_apps repository..."
	git clone \
		--single-branch --branch 11.00.00.06-beagley \
		--depth 1 \
		https://github.com/goat-hill/ti-vision-apps \
		vision_apps
}

u_boot_compile() {
	# Docs available at
	# https://software-dl.ti.com/jacinto7/esd/processor-sdk-linux-am67a/11_00_00/exports/docs/linux/Foundational_Components/U-Boot/UG-General-Info.html

	echo "Entering u-boot directory..."
	cd $TI_SDK_LINUX_PATH/u-boot-ci

	echo "Compiling u-boot r5 outputs..."
	make ARCH=arm O=$TI_SDK_LINUX_PATH/uboot-build/r5 beagleyai_r5_defconfig
	make \
		-j$(nproc) \
		ARCH=arm \
		O=$TI_SDK_LINUX_PATH/uboot-build/r5 \
		CROSS_COMPILE="$CROSS_COMPILE_32" \
		BINMAN_INDIRS=${PREBUILT_IMAGES}

	echo "Compiling u-boot a53 outputs..."
	make ARCH=arm O=$TI_SDK_LINUX_PATH/uboot-build/a53 beagleyai_a53_defconfig
	make \
		-j$(nproc) \
		ARCH=arm \
		O=$TI_SDK_LINUX_PATH/uboot-build/a53 \
		CROSS_COMPILE="$CROSS_COMPILE_64" \
		CC="$CC_64" \
		BL31=${PREBUILT_IMAGES}/bl31.bin \
		TEE=${PREBUILT_IMAGES}/bl32.bin \
		BINMAN_INDIRS=${PREBUILT_IMAGES}
}

u_boot_install() {
	echo "Installing u-boot outputs..."
	cp $TI_SDK_LINUX_PATH/uboot-build/r5/tiboot3-j722s-hs-fs-evm.bin $MOUNT_BOOT/tiboot3.bin
	cp $TI_SDK_LINUX_PATH/uboot-build/a53/tispl.bin $MOUNT_BOOT/tispl.bin
	cp $TI_SDK_LINUX_PATH/uboot-build/a53/u-boot.img $MOUNT_BOOT/u-boot.img

	echo "Inspecting BOOT fs..."
	ls -al $MOUNT_BOOT
}

linux_compile() {
	# Docs available at
	# https://software-dl.ti.com/jacinto7/esd/processor-sdk-linux-am67a/11_00_00/exports/docs/linux/Foundational_Components_Kernel_Users_Guide.html

	echo "Entering linux directory..."
	cd $TI_SDK_LINUX_PATH/linux-ci

	echo "Configuring with ti_arm64_prune.config..."
	make \
		-j$(nproc) \
		ARCH=arm64 \
		CROSS_COMPILE="$CROSS_COMPILE_64" \
		defconfig \
		ti_arm64_prune.config
	
	echo "Compiling Image..."
	make \
		-j$(nproc) \
		ARCH=arm64 \
		CROSS_COMPILE="$CROSS_COMPILE_64" \
		Image
	
	echo "Compiling modules..."
	make \
		-j$(nproc) \
		ARCH=arm64 \
		CROSS_COMPILE="$CROSS_COMPILE_64" \
		modules
	
	echo "Compiling dtbs and overlays..."
	make \
		-j$(nproc) \
		ARCH=arm64 \
		CROSS_COMPILE="$CROSS_COMPILE_64" \
		dtbs
}

linux_install() {
	echo "Entering linux directory..."
	cd $TI_SDK_LINUX_PATH/linux-ci
	
	echo "Installing Image..."
	cp arch/arm64/boot/Image $MOUNT_ROOTFS/boot/
	ls -al $MOUNT_ROOTFS/boot/

	echo "Installing dtbs and overlays..."
	cp arch/arm64/boot/dts/ti/k3-am67a-beagleyai.dtb $MOUNT_ROOTFS/boot/dtb/
	cp \
		arch/arm64/boot/dts/ti/k3-am67a-beagley-ai-edgeai-apps.dtbo \
		arch/arm64/boot/dts/ti/k3-am67a-beagley-ai-csi0-imx219.dtbo \
		$MOUNT_ROOTFS/boot/dtb/ti/
	ls -al $MOUNT_ROOTFS/boot/dtb
	ls -al $MOUNT_ROOTFS/boot/dtb/ti

	# Consider INSTALL_MOD_STRIP=1 to strip symbols
	# FIXME: Save a few hundred MBs by deleting previous kernel version modules
	echo "Installing modules..."
	 make \
		ARCH=arm64 \
		INSTALL_MOD_PATH=$MOUNT_ROOTFS \
		modules_install

	echo "Replacing BOOT uEnv.txt overlay..."
	sed -i 's|^name_overlays=.*$|name_overlays=ti/k3-am67a-beagley-ai-edgeai-apps.dtbo|' $MOUNT_BOOT/uEnv.txt
	cat $MOUNT_BOOT/uEnv.txt
	
	echo "Inspecting rootfs..."
	ls -al $MOUNT_ROOTFS/
}

rtos_compile() {
	# Docs available at
	# https://software-dl.ti.com/jacinto7/esd/processor-sdk-rtos-j722s/11_00_00_06/exports/docs/psdk_rtos/docs/user_guide/firmware_builder.html

	echo "Entering SDK RTOS directory..."
	cd $TI_SDK_RTOS_PATH
	
	if [ -d "targetfs" ]; then
		echo "Removing existing targetfs/ directory..."
		rm -rf targetfs
	fi

	echo "Creating targetfs/ directory using existing rootfs..."
	# Otherwise, the setup_psdk_rtos.sh script will create a new targetfs/ directory
	# using the wrong (adas) image
	ln -s $MOUNT_ROOTFS targetfs

	echo "Setting up SDK RTOS..."
	./sdk_builder/scripts/setup_psdk_rtos.sh

	echo "Entering sdk_builder directory..."
	cd sdk_builder

	echo "Compiling SDK firmware for Edge AI..."
	TISDK_IMAGE=edgeai make sdk_show_config
	TISDK_IMAGE=edgeai make -j$(nproc) firmware
}

rtos_install() {
	# Based on sdk_builder/ `make linux_fs_install`
	# But having trouble with propagating environment variables so executing manually

	echo "Installing SDK firmware..."
	export LINUX_FS_STAGE_PATH=/tmp/tivision_apps_targetfs_stage

	echo "Removing existing rtos SDK files..."
	rm -f $MOUNT_ROOTFS/usr/lib/firmware/j722s-*-fw
	rm -f $MOUNT_ROOTFS/usr/lib/firmware/j722s-*-fw-sec
	rm -rf $MOUNT_ROOTFS/usr/lib/firmware/vision_apps_eaik
	rm -rf $MOUNT_ROOTFS/opt/tidl_test/*
	rm -rf $MOUNT_ROOTFS/opt/notebooks/*
	rm -rf $MOUNT_ROOTFS/usr/include/processor_sdk/*

	echo "Creating directories for RTOS SDK files..."
	mkdir -p $MOUNT_ROOTFS/usr/include/processor_sdk

	echo "Copying RTOS SDK files into rootfs..."
	cp -r $LINUX_FS_STAGE_PATH/* $MOUNT_ROOTFS/.
}

clean_and_package_img() {
	echo "Flushing file system buffers..."
	sync

	echo "Moving to build dir..."
	cd $BUILD_DIR

	echo "Setting up genimage mount points..."
	mkdir fs

	ln -s $MOUNT_BOOT fs/fs-boot
	ln -s $MOUNT_ROOTFS fs/fs-rootfs

	echo "Running genimage..."
	genimage --rootpath fs --config /app/genimage.cfg

	# We add -S to tar for a smaller compressed file size due to sparse files
	echo "Compressing image to SD card image file..."
	xz --compress --threads=0 --keep $IMG_PATH
	
	echo "Image ready at ${IMG_XZ_PATH}"
	du -h $IMG_XZ_PATH
}

deploy_image() {
	# FIXME: Disable CI artifacts and upload to beagleboard.org/distros instead
	echo "Making artifact directory..."
	cd $BUILD_DIR
	mkdir -p artifacts

	echo "Creating image.yml for beagleboard.org/distros..."
	extract_size=$(du -b $IMG_PATH | awk '{print $1}')
	echo "  extract_size: ${extract_size}" > artifacts/image.yml
	extract_sha256=$(sha256sum $IMG_PATH | awk '{print $1}')
	echo "  extract_sha256: ${extract_sha256}" >> artifacts/image.yml
	image_download_size=$(du -b $IMG_XZ_PATH | awk '{print $1}')
	echo "  image_download_size: ${image_download_size}" >> artifacts/image.yml
	image_download_sha256=$(sha256sum $IMG_XZ_PATH | awk '{print $1}')
	echo "  image_download_sha256: ${image_download_sha256}" >> artifacts/image.yml
	TIME=$(date +%Y-%m-%d)
	echo "  release_date: '${TIME}'" >> artifacts/image.yml

	echo "Moving image to artifacts directory..."
	mv $IMG_XZ_PATH artifacts/
}

install_genimage
install_linux_sdk
install_rtos_sdk
checkout_linux_code
populate_partitions
checkout_rtos_code
cc33xx_firmware_install
u_boot_compile
u_boot_install
linux_compile
linux_install
rtos_compile
rtos_install
clean_and_package_img
deploy_image
