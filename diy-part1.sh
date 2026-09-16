#!/bin/bash
# Build customization script
# https://github.com/P3TERX/Actions-OpenWrt
# 文件名: diy-part1.sh
# 功能说明: OpenWrt DIY脚本第1部分（更新feeds之前）
# 版权: (c) 2019-2024 P3TERX <https://p3terx.com>
# 基于 MIT 开源协议，详见 /LICENSE

# 取消注释一个源
# sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add third-party feeds for optional packages.
echo 'src-git smpackage https://github.com/kenzok8/small-package^b74fbaf589bf622ce2805163330904758a6b3af3' >> feeds.conf.default
# Add the iStore feed for luci-app-store.
echo 'src-git store https://github.com/linkease/istore.git^3fca15b30aeed9ecacb3efc8b4a8b9c2584ad5c7' >> feeds.conf.default


# OpenClash proxy
# git clone --depth 1 https://github.com/vernesong/OpenClash.git OpenClash

# turboacc setup runs only when luci-app-turboacc is explicitly selected.
# curl -sSL https://raw.githubusercontent.com/mufeng05/turboacc/main/add_turboacc.sh -o add_turboacc.sh && bash add_turboacc.sh

# Debug only
# sed -i 's|src-git-full openstick https://github.com/lkiuyu/openstick-feeds.git|src-git-full openstick https://github.com/xuxin1955/openstick-feeds|g' feeds.conf.default



