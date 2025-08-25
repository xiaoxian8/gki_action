#!/usr/bin/env bash

#下载LLVM环境
wget -nv https://github.com/llvm/llvm-project/releases/download/llvmorg-20.1.8/LLVM-20.1.8-Linux-X64.tar.xz
tar -Jxf LLVM-20.1.8-Linux-X64.tar.xz --strip-components=1
#下载源码
git clone https://android.googlesource.com/kernel/common -b $GKI_DEV --depth=1
cd common
git clone https://github.com/xiaoxian8/AnyKernel3.git

#自定义LLVM环境变量
export PATH=$PWD/../LLVM-20.1.8-Linux-X64/bin:$PATH
export DEFCONFIG_FILE=$PWD/arch/arm64/configs/gki_defconfig

#自定义KernelSU分支
if [[ "$KSU_BRANCH" == "y" || "$KSU_BRANCH" == "Y" ]]; then
	KSU_TYPE="SukiSU Ultra"
else
	KSU_TYPE="KernelSU Next"
fi
if [[ "$KSU_BRANCH" == "y" ]]; then
	curl -LSs "https://raw.githubusercontent.com/ShirkNeko/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-main
	git clone https://github.com/ShirkNeko/SukiSU_patch.git
	patch -p1 < SukiSU_patch/hooks/syscall_hooks.patch
	patch -p1 -F3 < SukiSU_patch/69_hide_stuff.patch
else
	curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/next-susfs/kernel/setup.sh" | bash -s next
	git clone https://github.com/KernelSU-Next/kernel_patches.git
	cd KernelSU-Next
	patch -p1 -F3 < ../kernel_patches/susfs/android14-6.1-v1.5.9-ksunext-12823.patch
	cd ..
	patch -p1 -F3 < kernel_patches/syscall_hook/min_scope_syscall_hooks_v1.4.patch
fi

#添加LTO优化
cat >> "$DEFCONFIG_FILE" <<EOF
CONFIG_LTO_CLANG=y
CONFIG_ARCH_SUPPORTS_LTO_CLANG=y
CONFIG_ARCH_SUPPORTS_LTO_CLANG_THIN=y
CONFIG_HAS_LTO_CLANG=y
CONFIG_LTO_CLANG_THIN=y
CONFIG_LTO=y
EOF

# 写入通用 SUSFS/KSU 配置
cat >> "$DEFCONFIG_FILE" <<EOF
CONFIG_KSU=y
EOF

#是否添加susf支持
if [[ "$APPLY_SUSFS" == "y" || "$APPLY_SUSFS" == "Y" ]]; then
	cat >> "$DEFCONFIG_FILE" <<EOF
	CONFIG_KSU_SUSFS=y
	CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y
	CONFIG_KSU_SUSFS_SUS_PATH=y
	CONFIG_KSU_SUSFS_SUS_MOUNT=y
	CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y
	CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y
	CONFIG_KSU_SUSFS_SUS_KSTAT=y
	#CONFIG_KSU_SUSFS_SUS_OVERLAYFS is not set
	CONFIG_KSU_SUSFS_TRY_UMOUNT=y
	CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y
	CONFIG_KSU_SUSFS_SPOOF_UNAME=y
	CONFIG_KSU_SUSFS_ENABLE_LOG=y
	CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
	CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
	CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
EOF
else
	echo "未添加SUSFS支持"
fi

#是否启用lz4kd
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
	if [[ "$KSU_BRANCH" == "n" || "$KSU_BRANCH" == "N" ]]; then
		git clone https://github.com/ShirkNeko/SukiSU_patch.git
	fi
	cp -r ./SukiSU_patch/other/zram/lz4k/include/linux/* ./include/linux/
	cp -r ./SukiSU_patch/other/zram/lz4k/lib/* ./lib
	cp -r ./SukiSU_patch/other/zram/lz4k/crypto/* ./crypto
	cp ./SukiSU_patch/other/zram/zram_patch/$GKI_VERSION/*.patch ./
	cp -r ./SukiSU_patch/lz4k_oplus ./lib
	patch -p1 -F 3 < lz4kd.patch || true
	sed -i 's/^CONFIG_ZRAM=m/CONFIG_ZRAM=y/' "$DEFCONFIG_FILE"
else
	echo "跳过lz4kd补丁"
fi
if [[ "$APPLY_KPROBES" == "y" || "$APPLY_KPROBES" == "Y" ]]; then
	echo "CONFIG_KSU_SUSFS_SUS_SU=y" >> "$DEFCONFIG_FILE"
	echo "CONFIG_KSU_MANUAL_HOOK=n" >> "$DEFCONFIG_FILE"
	echo "CONFIG_KSU_KPROBES_HOOK=y" >> "$DEFCONFIG_FILE"
else
	echo "CONFIG_KSU_MANUAL_HOOK=y" >> "$DEFCONFIG_FILE"
	echo "CONFIG_KSU_SUSFS_SUS_SU=n" >>  "$DEFCONFIG_FILE"
fi

#是否启用kpm
if [[ "$USE_PATCH_LINUX" == "y" || "$USE_PATCH_LINUX" == "Y" ]]; then
	  echo "CONFIG_KPM=y" >> "$DEFCONFIG_FILE"
fi

# 仅在启用 LZ4KD 时启用
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
	cat >> "$DEFCONFIG_FILE" <<EOF
	CONFIG_ZSMALLOC=y
	CONFIG_CRYPTO_LZ4HC=y
	CONFIG_CRYPTO_LZ4K=y
	CONFIG_CRYPTO_LZ4KD=y
	CONFIG_CRYPTO_842=y
	CONFIG_ZRAM_DEF_COMP_LZ4=y
	CONFIG_ZRAM_DEF_COMP="lz4"
	CONFIG_CRYPTO_LZ4K_OPLUS=y
EOF
fi

#添加网络优化功能
echo "CONFIG_BPF_STREAM_PARSER=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_NETFILTER_XT_SET=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_MAX=65534" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_BITMAP_IP=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_BITMAP_IPMAC=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_BITMAP_PORT=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_HASH_IP=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_HASH_IPMARK=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_HASH_IPPORT=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_HASH_IPPORTIP=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_HASH_IPPORTNET=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_HASH_IPMAC=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_HASH_MAC=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_HASH_NETPORTNET=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_HASH_NET=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_HASH_NETNET=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_HASH_NETPORT=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_HASH_NETIFACE=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP_SET_LIST_SET=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP6_NF_NAT=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_IP6_NF_TARGET_MASQUERADE=y" >> "$DEFCONFIG_FILE"

#是否添加BBR等一系列拥塞控制算法
if [[ "$APPLY_BBR" == "y" || "$APPLY_BBR" == "Y" || "$APPLY_BBR" == "d" || "$APPLY_BBR" == "D" ]]; then
	cat >> "$DEFCONFIG_FILE" <<EOF
	CONFIG_TCP_CONG_ADVANCED=y
	CONFIG_TCP_CONG_BBR=y
	CONFIG_TCP_CONG_CUBIC=y
	CONFIG_TCP_CONG_VEGAS=y
	CONFIG_TCP_CONG_NV=y
	CONFIG_TCP_CONG_WESTWOOD=y
	CONFIG_TCP_CONG_HTCP=y
	CONFIG_TCP_CONG_BRUTAL=y
EOF
	if [[ "$APPLY_BBR" == "d" || "$APPLY_BBR" == "D" ]]; then
		echo "CONFIG_DEFAULT_TCP_CONG=bbr" >> "$DEFCONFIG_FILE"
	else
		echo "CONFIG_DEFAULT_TCP_CONG=cubic" >> "$DEFCONFIG_FILE"
	fi
fi

if [[ "$APPLY_SSG" == "y" || "$APPLY_SSG" == "Y" ]]; then
	git clone https://github.com/xiaoxian8/ssg_patch.git
	cp ssg_patch/* ./
	patch -p1 < ssg.patch
	echo "CONFIG_MQ_IOSCHED_SSG=y" >> "$DEFCONFIG_FILE"
	echo "CONFIG_REKERNEL=y" >> "$DEFCONFIG_FILE"
fi

#开始编译
args=(-j$(nproc --all) O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- LLVM_IAS=1 LLVM=1 DTC=dtc DEPMOD=depmod)
make ${args[@]} gki_defconfig
make ${args[@]} Image.lz4

OUT_DIR="$PWD/out/arch/arm64/boot"
if [[ "$USE_PATCH_LINUX" == "y" || "$USE_PATCH_LINUX" == "Y" ]]; then
	mv $OUT_DIR/Image ./
	chmod +x SukiSU_patch/kpm/patch_linux
	./SukiSU_patch/kpm/patch_linux
	mv oImage AnyKernel3/Image
else
	mv $OUT_DIR/Image AnyKernel3/Image
fi

#打包AnyKernel3刷机包
cd AnyKernel3
zip -r9v ../out/AnyKernel3.zip * 
