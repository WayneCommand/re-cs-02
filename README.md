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
| `luci-theme-aurora` | 界面主题 |
| `luci-app-sqm` + `sqm-scripts` | SQM 流量整形，缓解 bufferbloat |
| `luci-app-https-dns-proxy` + `https-dns-proxy` | DoH 加密 DNS |
| `luci-app-openclash` | OpenClash 代理面板 |
| `luci-i18n-base/firewall/sqm-zh-cn` | 对应界面的简体中文翻译 |

### 其它

| 选项 | 作用 |
|---|---|
| `openssh-server` + `openssh-sftp-server` | OpenSSH（dropbear 仍是默认包） |
| `htop` | 交互式进程查看 |

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
   ./scripts/feeds update -a && ./scripts/feeds install -a
   cp re-cs-02.config .config && make defconfig
   ```

2. **版本必须是 OpenWrt main（或含该机型提交的版本）**。RE-CS-02 支持是 2026-01 才进 main 的（commit `53a8e7b`，PR #19840），没有 backport 到 25.12 稳定分支——在 v25.12.x 上 `make defconfig` 会把 `..._DEVICE_jdcloud_re-cs-02` 当未知符号丢掉，最后编出空目标。稳定的做法是把 workflow 里的 clone 钉到某个 commit：

   ```sh
   git clone https://git.openwrt.org/openwrt/openwrt.git --depth=1
   # 或者钉版本：
   # git fetch --depth=1 origin <commit> && git checkout FETCH_HEAD
   ```

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

5. 构建见 `.github/workflows/build-binaries.yml`（OpenWrt main，额外引入 OpenClash feed）。产物在 `bin/targets/qualcommax/ipq60xx/`：

   - `*-squashfs-sysupgrade.bin` —— 已经在跑 OpenWrt 时升级用，或 TFTP 进去之后 sysupgrade
   - `*-initramfs*.itb` —— 首次刷机用，重命名为 `initramfs.itb` 放到 TFTP 服务器，U-Boot 里 `tftpboot initramfs.itb && bootm`

6. 首次刷机（原厂固件 ≥ 4.3.0.r4211 时需要在 U-Boot 倒计时里输入 `jdmt018R` 打断自动启动）：

   ```
   tftpboot initramfs.itb
   bootm
   ```

   进入 OpenWrt 后把 sysupgrade.bin 通过 LuCI / scp 传上去，`sysupgrade -n` 刷写。
