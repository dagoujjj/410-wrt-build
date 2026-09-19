#!/bin/bash
# Build customization script
# https://github.com/P3TERX/Actions-OpenWrt
# 文件名: diy-part2.sh
# 功能说明: OpenWrt DIY脚本第2部分（更新feeds之后）
# 版权: (c) 2019-2024 P3TERX <https://p3terx.com>
# 基于 MIT 开源协议，详见 /LICENSE

# Change the default management address
#sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate


# Select Argon as the default theme when available.
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true

kernel_options=(
  CONFIG_IP_ADVANCED_ROUTER=y
  CONFIG_IP_MULTIPLE_TABLES=y
  CONFIG_IP_ROUTE_MULTIPATH=y
  CONFIG_IP_ROUTE_VERBOSE=y
  CONFIG_NETFILTER_XT_TARGET_MARK=m
  CONFIG_NETFILTER_XT_TARGET_CONNMARK=m
  CONFIG_NETFILTER_XT_TARGET_TPROXY=m
  CONFIG_NETFILTER_XT_MATCH_MARK=m
  CONFIG_NETFILTER_XT_MATCH_CONNMARK=m
  CONFIG_NETFILTER_XT_MATCH_SOCKET=m
  CONFIG_NETFILTER_XT_MATCH_OWNER=m
  CONFIG_NETFILTER_XT_MATCH_CGROUP=m
  CONFIG_XFRM_USER=m
  CONFIG_XFRM_ALGO=m
  CONFIG_XFRM_ESP=m
  CONFIG_XFRM_AH=m
  CONFIG_NFT_XFRM=m
  CONFIG_PPPOE=m
  CONFIG_NET_VRF=m
  CONFIG_BONDING=m
  CONFIG_NET_TEAM=m
  CONFIG_IPVLAN=m
  CONFIG_MACVTAP=m
  CONFIG_VXLAN=m
  CONFIG_GENEVE=m
  CONFIG_NFT_TUNNEL=m
  CONFIG_NET_IPIP=m
  CONFIG_NET_IPGRE=m
  CONFIG_NET_IPGRE_DEMUX=m
  CONFIG_NET_FOU=m
  CONFIG_NET_FOU_IP_TUNNELS=y
  CONFIG_IPV6_SIT=m
  CONFIG_OVPN=m
  CONFIG_USB_NET_CDC_MBIM=m
  CONFIG_USB_NET_QMI_WWAN=m
  CONFIG_USB_ACM=m
  CONFIG_MHI_BUS=m
  CONFIG_MHI_BUS_EP=m
  CONFIG_MHI_WWAN_CTRL=m
  CONFIG_MHI_WWAN_MBIM=m
  CONFIG_NET_CLS_BPF=m
  CONFIG_NET_ACT_BPF=m
  CONFIG_XDP_SOCKETS=m
  CONFIG_NFT_QUEUE=m
  CONFIG_NFT_SYNPROXY=m
  CONFIG_NET_ACT_CT=m
  CONFIG_NET_ACT_TUNNEL_KEY=m
  CONFIG_IP_NF_TARGET_REDIRECT=m
  CONFIG_IP_NF_TARGET_MASQUERADE=m
  CONFIG_IP_VS=m
  CONFIG_IP_VS_IPV6=y
  CONFIG_NF_CT_PROTO_SCTP=y
)

kernel_configs=(target/linux/msm89xx/config-*)
test -f "${kernel_configs[0]}"
for cfg in "${kernel_configs[@]}"; do
  for option in "${kernel_options[@]}"; do
    key=${option%%=*}
    sed -i -E "/^${key}=|^# ${key} is not set$/d" "$cfg"
    printf '%s\n' "$option" >> "$cfg"
  done
done


# Optional local packages.
# git clone https://github.com/lkiuyu/luci-app-cpu-perf package/luci-app-cpu-perf
# git clone https://github.com/lkiuyu/luci-app-cpu-status package/luci-app-cpu-status
# git clone https://github.com/gSpotx2f/luci-app-cpu-status-mini package/luci-app-cpu-status-mini
# git clone https://github.com/lkiuyu/luci-app-temp-status package/luci-app-temp-status
# git clone https://github.com/lkiuyu/DbusSmsForwardCPlus package/DbusSmsForwardCPlus
