#!/usr/bin/env bash
git clone https://android.googlesource.com/kernel/common -b android14-6.1-2024-10 --depth=1
cd common
git clone https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 -b android14-release --depth=1 llvm
git clone https://github.com/xiaoxian8/AnyKernel3.git --depth=1
export PATH=$PWD/llvm/clang-r487747c/bin:$PATH
export DEFCONFIG_FILE=$PWD/arch/arm64/configs/gki_defconfig
 
#删除无用的abi和内核后缀
rm android/abi_gki_protected_exports_*
sed -i 's/ -dirty//g' scripts/setlocalversion

echo ">>> 正在添加sukisu和susfs支持..."
curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-main
git clone https://github.com/SukiSU-Ultra/SukiSU_patch.git --depth=1
git clone https://github.com/xiaoxian8/ssg_patch.git --depth=1
git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android14-6.1 --depth=1
cp ssg_patch/* ./ -r
patch -p1 < ssg.patch
patch -p1 < SukiSU_patch/hooks/syscall_hooks.patch
patch -p1 < SukiSU_patch/69_hide_stuff.patch
patch -p1 -F3 < SukiSU_patch/other/zram/zram_patch/6.1/lz4kd.patch
patch -p1 -F3 < SukiSU_patch/other/zram/zram_patch/6.1/lz4k_oplus.patch
cp SukiSU_patch/other/zram/lz4k/* ./ -r
cp SukiSU_patch/other/zram/lz4k_oplus ./lib -r
cp susfs4ksu/kernel_patches/* ./ -r
patch -p1 < 50_add_susfs_in_gki-android14-6.1.patch
echo ">>> 添加LTO优化..."
cat >> "$DEFCONFIG_FILE" <<EOF
CONFIG_LTO_CLANG=y
CONFIG_ARCH_SUPPORTS_LTO_CLANG=y
CONFIG_ARCH_SUPPORTS_LTO_CLANG_THIN=y
CONFIG_HAS_LTO_CLANG=y
CONFIG_LTO_CLANG_THIN=y
CONFIG_LTO=y
EOF

echo ">>> 正在添加SUKISU选项..."
cat >> "$DEFCONFIG_FILE" <<EOF
CONFIG_LOCALVERSION="-xiaoxian"
CONFIG_KSU=y
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
echo "CONFIG_KSU_KPROBES_HOOK=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_KSU_MANUAL_HOOK=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_KSU_SUSFS_SUS_SU=n" >>  "$DEFCONFIG_FILE"
echo "CONFIG_KPM=y" >> "$DEFCONFIG_FILE"

echo ">>> 正在添加LZ4KD以及842支持..."
cat >> "$DEFCONFIG_FILE" <<EOF
CONFIG_CRYPTO_LZ4K_OPLUS=y
CONFIG_ZSMALLOC=y
CONFIG_CRYPTO_LZ4HC=y
CONFIG_CRYPTO_LZ4K=y
CONFIG_CRYPTO_LZ4KD=y
CONFIG_CRYPTO_842=y
CONFIG_ZRAM_DEF_COMP="lz4"
EOF
echo ">>> 正在添加 BBR 等一系列拥塞控制算法..."
echo "CONFIG_TCP_CONG_ADVANCED=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_TCP_CONG_BBR=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_TCP_CONG_CUBIC=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_TCP_CONG_VEGAS=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_TCP_CONG_NV=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_TCP_CONG_WESTWOOD=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_TCP_CONG_HTCP=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_TCP_CONG_BRUTAL=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_DEFAULT_TCP_CONG=bbr" >> "$DEFCONFIG_FILE"

echo ">>> 正在添加ssg调度..."
echo "CONFIG_MQ_IOSCHED_SSG=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_MQ_IOSCHED_SSG_CGROUP=y" >> "$DEFCONFIG_FILE"

echo ">>> 正在启用网络功能增强优化配置..."
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


#编译参数
args=(-j$(nproc --all) O=out ARCH=arm64 LLVM=1 DEPMOD=depmod DTC=dtc)

#清理旧的构建
make ${args[@]} mrproper

#定义默认配置
make ${args[@]} gki_defconfig

#开始编译
make ${args[@]} Image.lz4 modules

#生成modules_install
make ${args[@]} INSTALL_MOD_PATH=modules modules_install

#生成补丁刷机包
chmod +x SukiSU_patch/kpm/patch_linux
cp $(find out -type f  -name "Image") ./
./SukiSU_patch/kpm/patch_linux
mv -v oImage AnyKernel3/Image
cd AnyKernel3
zip -r9v ../out/kernel.zip *
rm Image ../Image

cd ../
git checkout --ours . 