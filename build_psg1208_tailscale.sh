#!/usr/bin/env bash
# ===================================================================
# 斐讯 PSG1208 (K2) 精简版 OpenWRT 固件 + Tailscale 构建脚本
# 设备: MediaTek MT7620A / 64MB RAM / 8MB Flash
# 目标: ramips/mt7620   设备名: phicomm_psg1208
#
# 用法(在 x86_64 Linux / WSL / 云主机上):
#   chmod +x build_psg1208_tailscale.sh
#   ./build_psg1208_tailscale.sh
#
# 注意:
#   1. 本脚本用官方 Image Builder，无需编译工具链，几分钟出图。
#   2. Image Builder 只有 x86_64 版，aarch64/ARM 机器跑不了。
#   3. 8MB Flash 装 Tailscale 很勉强，见下方 MODE 说明。
# ===================================================================
set -e

# ---- 可调参数 -----------------------------------------------------
OPENWRT_VERSION="23.05.5"          # 稳定版；想用 24.10 改这里即可
TARGET="ramips/mt7620"
PROFILE="phicomm_psg1208"

# MODE = "builtin"  -> 路线A: Tailscale 内置(激进精简, 可能溢出)
# MODE = "extroot"  -> 路线B: 基础精简固件, Tailscale 后续装U盘(推荐)
MODE="${MODE:-extroot}"
# -------------------------------------------------------------------

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
    -luci -luci-ssl -luci-mod-admin-full -luci-base \
    -libip6tc -odhcp6c -odhcpd-ipv6only -kmod-ipv6 \
    -ppp -ppp-mod-pppoe -kmod-ppp -kmod-pppoe -kmod-pppox"
else
  echo "==> [2/4] 路线B: 基础精简固件(不含 Tailscale, 留给 U 盘 extroot)"
  echo "     (保留 PPPoE/WAN, 仅去 LuCI/IPv6 省空间)"
  PACKAGES="kmod-usb-storage kmod-fs-ext4 block-mount \
    -luci -luci-ssl -luci-mod-admin-full -luci-base \
    -libip6tc -odhcp6c -odhcpd-ipv6only -kmod-ipv6"
fi

echo "==> [3/4] 构建固件 (PROFILE=$PROFILE)"
# 去掉默认带的 ppp 相关也可在此追加; 这里用上面 PACKAGES 控制
make image PROFILE="$PROFILE" PACKAGES="$PACKAGES" || {
  echo "!! 构建失败: 多半是 rootfs 超出 8MB Flash 分区。"
  echo "!! 请改用 MODE=extroot 路线B, 或自行再删包。"
  exit 1
}

echo "==> [4/4] 完成! 镜像位置:"
ls -lh bin/targets/ramips/mt7620/
echo
echo "   出厂首刷(从官方固件升级): *-factory.bin"
echo "   已刷 OpenWRT 再升级:      *-sysupgrade.bin"
