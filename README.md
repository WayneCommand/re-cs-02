# re-cs-02.config

JDCloud RE-CS-02（京东云无线宝 AX6600，qualcommax / ipq60xx）的 OpenWrt 精简配置种子（seed config）。

只记录**非默认**的选择：target/device 三行 + 人工挑选的软件包。其余符号（`DEFAULT_*` 包集合、`KERNEL_*`、`BUSYBOX_DEFAULT_*`、工具链、镜像格式等）都由 `make defconfig` 按目标默认值补全，因此不要把它们写回来。

```
cp re-cs-02.config .config && make defconfig
```

## 硬件

| 项目 | 规格 |
|---|---|
| SoC | Qualcomm IPQ6010（4×Cortex-A53 @1.8GHz，aarch64） |
| 内存 | 1 GiB DDR4 |
| 存储 | eMMC 128GB / 256GB（FORESEE） |
| 有线 | 4×1GbE（LAN1–4）+ 1×2.5GbE（WAN，QCA8081） |
| 无线 | QCN5022 2.4G AX 2×2 / QCN5052 5G AX 2×2 / QCN9024 5G AX 4×4 |
| USB | 1× USB 3.0 |
| 按键 | Reset / WPS / Screen |

## 配置项作用

### 目标

| 选项 | 作用 |
|---|---|
| `CONFIG_TARGET_qualcommax` | 目标平台 qualcommax（高通 IPQ 系列，arm64） |
| `CONFIG_TARGET_qualcommax_ipq60xx` | 子目标 ipq60xx，即 IPQ6000/IPQ6010 平台 |
| `..._DEVICE_jdcloud_re-cs-02` | 具体机型；`TARGET_BOARD/SUBTARGET/PROFILE/ARCH_PACKAGES` 均由它推导，设备所需的 `ipq-wifi-jdcloud_re-cs-02`、`ath11k-firmware-qcn9074`、`kmod-ath11k-pci` 由 DEVICE_PACKAGES 自动带上 |

### 镜像

| 选项 | 作用 |
|---|---|
| `CONFIG_TARGET_ROOTFS_INITRAMFS` | 生成 initramfs 镜像。本机只能通过 TFTP + initramfs 首次进入 OpenWrt，再 sysupgrade，所以这个必须开 |

### 存储 / extroot

| 选项 | 作用 |
|---|---|
| `CONFIG_PACKAGE_block-mount` | `/etc/config/fstab` 与挂载脚本，extroot / 自动挂载都依赖它 |
| `CONFIG_PACKAGE_kmod-fs-ext4` | ext4 支持，extroot / U 盘系统盘 |
| `CONFIG_PACKAGE_kmod-fs-vfat` | FAT32 支持，U 盘通用格式 |
| `CONFIG_PACKAGE_kmod-fs-exfat` | exFAT 支持（大容量 U 盘、移动硬盘常见格式） |
| `CONFIG_PACKAGE_kmod-usb-storage` | USB 存储设备（U 盘、移动硬盘）|
| `CONFIG_PACKAGE_kmod-usb-storage-uas` | UASP 协议，USB 3.0 硬盘盒走 UAS 时速度明显更好 |

### USB 网络 / 串口

| 选项 | 作用 |
|---|---|
| `kmod-usb-net-cdc-ether` | USB 有线网卡，或手机 USB 共享网络 |
| `kmod-usb-net-rndis` | Android RNDIS 共享网络 |
| `kmod-usb-serial` | USB 转串口 / LTE 模块基础串口驱动 |

### WireGuard

| 选项 | 作用 |
|---|---|
| `kmod-wireguard` | 内核模块 |
| `wireguard-tools` | `wg`、`wg-quick` 命令行 |
| `luci-proto-wireguard` | LuCI 新建接口时可选 WireGuard 协议 |

### LuCI 与插件

| 选项 | 作用 |
|---|---|
| `luci` | Web 管理界面（元包，带 base/mod-* 一整套） |
| `luci-theme-aurora` | 界面主题（不在 luci feed，CI 里 clone 到 `package/`） |
| `luci-app-sqm` + `sqm-scripts` | SQM 流量整形，缓解 bufferbloat |
| `luci-app-https-dns-proxy` + `https-dns-proxy` | DoH 加密 DNS |
| `luci-app-openclash` | OpenClash 代理面板 |
| `CONFIG_LUCI_LANG_zh_Hans` | 简体中文：给每个已装的 luci 应用自动生成 `luci-i18n-<app>-zh-cn`（比逐个写包名抗版本变化） |

### 其它

| 选项 | 作用 |
|---|---|
| `openssh-server` + `openssh-sftp-server` | OpenSSH（dropbear 仍是默认包） |
| `htop` | 交互式进程查看 |

## NSS / PPE 硬件加速

目标：Wi-Fi 数据面跑在 NSS 协处理器上，转发不吃 CPU。

### 为什么换底座，而不是加个 feed

`openwrt-ppe-nss`（`JuliusBairaktaris/openwrt-ppe-nss`，分支 `ppe-nss`）不是插件包，它是 **openwrt main 的整棵变基分支**：在上游 `qca_edma` / `qca_ppe` 驱动之上，加了 NSS 的 DTS 节点、让 NSS 固件与主机共享 EDMA/PPE 的驱动改动、`nss-wifi-drv`（树内，`package/kernel/nss-wifi-drv`），以及把 ath11k 的数据面 ring 交给 NSS 的 mac80211/ath11k 补丁。这些都在内核和无线驱动层，feed 里的 `.ipk` 无法提供——所以只能换构建底座，而不是"优雅地打补丁"。

真正从 feed 拿的只有 `nss-firmware` 一个包（`nss-packages` 的 `ppe-nss` 分支）。

### 集成方式

本仓库仍然只负责**配置 + CI**，底座换成变基分支，所以结构不变：

| 位置 | 作用 |
|---|---|
| `re-cs-02.config` | 目标 + 包选择，多了三条 NSS 符号 |
| `.github/workflows/build-binaries.yml` | clone ppe-nss（钉 commit）、写 `feeds.conf`、按需装包、把 `files/` 覆盖层塞进镜像 |
| `files/etc/uci-defaults/20-nss-offload` | 首启打开 fw4 硬件 flow offload（PPE）、显式打开 Wi-Fi offload |
| `scripts/check-config.sh` | defconfig 之后校验期望符号，被静默丢弃就 fail |

### 依赖来源（flaky 点都在这里）

| 东西 | 从哪来 | 备注 |
|---|---|---|
| NSS Wi-Fi 驱动、PPE/EDMA 改动、ath11k 补丁 | ppe-nss 变基分支本体 | 不是包，别指望 feed |
| `nss-firmware` | `nss-packages` 的 `ppe-nss` 分支 | 唯一从 nss feed 拿的包，**必须显式 `feeds install`**：树内 `nss-wifi-drv` 依赖它，漏装时不报错，直到组 rootfs 才 `apk: nss-firmware (no such package)` |
| `nss-wifi` 配置 | `package/kernel/nss-wifi-drv` | 树内 |
| `luci-theme-aurora` | `eamonxg/luci-theme-aurora`，clone 到 `package/` | **不在 luci feed 里**，之前就是因此被静默丢弃 |
| zh-cn 翻译 | luci feed，由 `CONFIG_LUCI_LANG_zh_Hans=y` 生成 | 不再逐个写 `luci-i18n-*-zh-cn` |
| `luci-app-openclash` | `vernesong/OpenClash` feed | |

NSS 三条符号：

| 选项 | 作用 |
|---|---|
| `CONFIG_PACKAGE_kmod-nss-wifi-drv` | 树内 NSS Wi-Fi 驱动：拉起 NSS 固件、接管 ath11k 的 ring |
| `CONFIG_ATH11K_NSS_WIFI` | ath11k 侧的 offload 代码路径 |
| `wpad-openssl`（替换 `wpad-basic-mbedtls`） | 官方 seed 用的组合，`wpad-basic` 功能不全 |

### 验证

```sh
logread -e nss-wifi                       # bring-up 过程，失败会落在这里
grep -c HW_OFFLOAD /proc/net/nf_conntrack # >0 表示有线流已经进 PPE
uci get nss-wifi.general.offload          # 1 = Wi-Fi offload 开
```

关闭 Wi-Fi offload（出问题时的回退）：

```sh
uci set nss-wifi.general.offload='0'; uci commit nss-wifi; reboot
```

### 必须知道的坑

1. **IPQ60xx 在作者那里"完全没测过"**（测试机是 AX3600）；RE-CS-02 更没有专门验证。能编出来 ≠ 能跑起来，先刷到 U 盘/备份分区再试。
2. **SQM 与 offload 打架**。装了 `sqm-scripts` 走 cake/ifb 时，已经 offload 的流根本不过 ifb，限速看起来"失效"。要真限速得用 PPE 自己的 shaper：`hw_ppe.qos`（在 `Qualcommax_NSS_Builder` 里，是对 `sqm-scripts` 的补丁，stock feeds 没有），或者用 `qca-ppe-qos` + `luci-app-qca-ppe-qos`（需要一个 luci fork）。
3. **OpenClash / 任何 tproxy 流量不会被加速**。透明代理把连接拉回用户态，`nft` 规则对这些连接生效，也就绕开了 flowtable。这是预期行为，不是配置错了。
4. **NSS 固件是闭源 blob**，随固件再分发有许可风险；自己用没问题，别公开分发带固件的镜像。
5. **mesh 需要固件 11.4**：默认启动的是 12.5，11.4 是最后支持 802.11s 的版本，两者都打包在镜像里。
6. 从 mainline 版 sysupgrade 过来建议 `sysupgrade -n`，内核模块版本全变了，保留配置容易卡在半启动。

## 可以自行调整的地方

**加软件包** —— 在对应分组加一行 `CONFIG_PACKAGE_xxx=y` 即可，`+` 声明的依赖由 kconfig 自动 `select`，不用手写 `kmod-*`/`lib*`。例如 `luci-app-upnp`、`luci-app-ddns`、`luci-app-diskman`、`samba4-server`。

**删软件包** —— 直接删除该行，回到该符号的默认值（对上面这些本来就是"默认未选"的包，等于不装）。

**关闭默认开启的功能** —— 这类不能靠删行，必须显式写 `# CONFIG_XXX is not set`（`diffconfig.sh` 输出的就是这个格式）。典型例子：

- `# CONFIG_TARGET_ROOTFS_INITRAMFS is not set` —— 不生成 initramfs 镜像，构建更快、产物更少；但**本机的首次刷机就靠它**，确认已经刷好 OpenWrt 之后再关
- `# CONFIG_SIGNED_PACKAGES is not set` —— 跳过软件包签名校验，方便装第三方 ipk
- `# CONFIG_KERNEL_KALLSYMS is not set` —— 内核体积换调试能力

**换主题 / 语言** —— 替换 `luci-theme-aurora`，或加 `luci-i18n-openclash-zh-cn` 之类的插件翻译包。

**换设备** —— 三行 target 换成别的机型符号即可（同一 ipq60xx 子目标内的 `jdcloud_re-ss-01`、`jdcloud_re-cs-07`、`qihoo_360v6` 等）。

**LTE 上网卡** —— 只有 `kmod-usb-serial` 不够，还需 `kmod-usb-serial-option`、`kmod-usb-net-qmi-wwan`、`uqmi`、`luci-proto-qmi`（或 MBIM 一组）。

## 与 r3g.config 的差异

| 方面 | 小米路由器 3G（ramips/mt7621） | JDCloud RE-CS-02（qualcommax/ipq60xx） |
|---|---|---|
| 架构 | mips_24kc（32 位） | aarch64_cortex-a53（64 位） |
| 系统盘 | NAND + UBI/UBIFS | eMMC（FIT 镜像 + squashfs + overlay） |
| extroot | 需 `CONFIG_FSTOOLS_UBIFS_EXTROOT` 才能把 U 盘覆盖层叠在 UBIFS 上 | eMMC 本身就是块设备，`block-mount` + `kmod-fs-ext4` 即可，无需 UBIFS 选项 |
| `kmod-mtd-rw` | 有用（改 mtd 分区表） | 无 MTD，已去掉 |
| 首次刷机 | 官方固件直刷 / Breed | 只能 U-Boot TFTP 拉 initramfs，再 sysupgrade |
| 默认 LAN | 192.168.1.1 | 192.168.1.1（`02_network` 中 wan/lan1-4 已适配） |

## 注意事项

1. **必须先装 feeds 再跑 defconfig**，顺序反了 feed 里的符号（如 `luci-app-openclash`）会被当成未知符号静默丢弃：

   ```sh
   ./scripts/feeds update -a
   ./scripts/feeds install luci luci-app-sqm ...   # 见 workflow 里的清单
   cp re-cs-02.config .config && make defconfig
   sh scripts/check-config.sh .config
   ```

   只装用得到的 feed（`packages` / `luci` / `openclash` / `nss`）。stock `feeds.conf.default` 还带 `routing` / `telephony` / `video`，我们一个包都不用，`video` 还会把 qt5 拖进 kconfig 树、刷出一堆 recursive dependency 报错。

2. **底座必须是 ppe-nss 分支**。RE-CS-02 支持是 2026-01 才进 main 的（commit `53a8e7b`，PR #19840），没 backport 到 25.12 稳定分支；而 NSS 的符号又只在 ppe-nss 变基分支里。换句话说：v25.12.x 编不出来（设备符号未知，被静默丢掉），openwrt main 编得出来但没有 offload。workflow 里钉的是 ppe-nss 的 commit SHA，升级时：

   ```sh
   git fetch origin && git reset --hard origin/ppe-nss   # 分支常被 rebase，不要 git pull
   ```

   然后把新的 SHA 填回 workflow 的 `PPE_NSS_COMMIT`。NSS 符号还存在但没编进固件，通常是忘了挂 `nss` feed。

3. 想重新生成最小配置，让 buildroot 自己算（比手工删更可靠，不需要编译）：

   ```sh
   cp 完整配置 .config && make defconfig && mkdir -p tmp
   ./scripts/diffconfig.sh > re-cs-02.config
   ```

4. 改完想确认没漏东西，两次展开后对比即可：

   ```sh
   cp 旧.config .config && make defconfig && cp .config /tmp/old.expanded
   cp re-cs-02.config .config && make defconfig && cp .config /tmp/new.expanded
   diff -u /tmp/old.expanded /tmp/new.expanded
   ```

5. 构建见 `.github/workflows/build-binaries.yml`（ppe-nss 底座 + OpenClash / nss feed + ccache + dl 缓存）。

**产物**（`bin/targets/qualcommax/ipq60xx/`，artifact 里就这几个文件）：

| 文件 | 用途 |
|---|---|
| `openwrt-qualcommax-ipq60xx-jdcloud_re-cs-02-squashfs-sysupgrade.bin` | 已经在跑 OpenWrt 时升级，或 TFTP 进 initramfs 之后 `sysupgrade` |
| `openwrt-qualcommax-ipq60xx-jdcloud_re-cs-02-initramfs-uImage.itb` | **首次刷机用这个**，重命名为 `initramfs.itb` 丢给 TFTP 服务器 |
| `sha256sums` | 两份镜像的校验和 |
| `profiles.json` | 目标/设备清单，排查刷错机型用 |

注意 `.itb` 和 `.itb.gz` 是两个不同文件（后者只在 build_dir 里）：TFTP 要的是**没压缩的 `.itb`**，直接拿 `.gz` 给 `bootm` 会失败。刷之前先对一下校验和：

```sh
sha256sum -c sha256sums --ignore-missing
```

**构建缓存**：`openwrt/dl`（源码包）和 `openwrt/.ccache` 都走 `actions/cache`。ccache 需要 `CONFIG_DEVEL=y` + `CONFIG_CCACHE=y`——`CCACHE` 的 prompt 是 `if DEVEL`，不开 `DEVEL` 时它是不可见符号，会被 defconfig 重新算成 n。cache 目录固定为 `$(TOPDIR)/.ccache`，`CCACHE_MAXSIZE=2G`；两个缓存共用仓库 10 GB 配额，不够时会被 LRU 淘汰，所以第一次冷构建仍然慢。日志末尾的 `ccache stats` 能看命中率。

6. 首次刷机（原厂固件 ≥ 4.3.0.r4211 时需要在 U-Boot 倒计时里输入 `jdmt018R` 打断自动启动）：

   ```
   tftpboot initramfs.itb
   bootm
   ```

   进入 OpenWrt 后把 sysupgrade.bin 通过 LuCI / scp 传上去，`sysupgrade -n` 刷写。
