#!/usr/bin/env bash
# 斐讯 PSG1208 (K2) 精简版 OpenWRT 固件 + Tailscale 构建脚本
# 设备: MediaTek MT7620A / 64MB RAM / 8MB Flash
set -e

OPENWRT_VERSION="23.05.5"
TARGET="ramips/mt7620"
PROFILE="phicomm_psg1208"
MODE="${MODE:-extroot}"

IB_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${TARGET}/openwrt-imagebuilder-${OPENWRT_VERSION}-ramips-mt7620.Linux-x86_64.tar.xz"

WORKDIR="$(pwd)/ib_psg1208"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "==> [1/4] 下载 Image Builder (${OPENWRT_VERSION})"
wget -q --show-progress -O ib.tar.xz "$IB_URL"
tar xf ib.tar.xz
cd openwrt-imagebuilder-*

if [ "$MODE" = "builtin" ]; then
  echo "==> [2/4] 路线A: 激进精简 + 内置 Tailscale"
  echo "     (已移除 LuCI / IPv6 / PPP, WAN 将不支持 PPPoE 拨号)"
  PACKAGES="tailscale kmod-tun \
    -luci -odhcpd-ipv6only -odhcp6c -libip6tc \
    -ppp -ppp-mod-pppoe -kmod-ppp -kmod-pppoe -kmod-pppox"
else
  echo "==> [2/4] 路线B: 基础精简固件(不含 Tailscale, 留给 U 盘 extroot)"
  echo "     (保留 PPPoE/WAN, 仅去 LuCI 省空间)"
  PACKAGES="kmod-usb-storage kmod-fs-ext4 block-mount -luci"
fi

echo "==> [3/4] 构建固件 (PROFILE=$PROFILE)"
if ! make image PROFILE="$PROFILE" PACKAGES="$PACKAGES"; then
  echo "!! 构建失败, 最后 40 行日志如下:"
  tail -n 40 "$(ls -t logs/*.log 2>/dev/null | head -1)" 2>/dev/null || true
  echo "!! 常见原因: rootfs 超出 8MB Flash 分区(改用 MODE=extroot) 或包名不存在"
  exit 1
fi

echo "==> [4/4] 完成! 镜像位置:"
ls -lh bin/targets/ramips/mt7620/
echo
echo "   出厂首刷(从官方固件升级): *-factory.bin"
echo "   已刷 OpenWRT 再升级:      *-sysupgrade.bin"
