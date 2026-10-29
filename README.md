# r3g.config

小米路由器 3G（ramips / mt7621）的 OpenWrt 精简配置种子（seed config）。

只记录**非默认**的选择：target/device 三行 + 人工挑选的软件包。其余符号（`DEFAULT_*` 包集合、`KERNEL_*`、`BUSYBOX_DEFAULT_*`、工具链、镜像格式等）都由 `make defconfig` 按目标默认值补全，因此不要把它们写回来。

```
cp r3g.config .config && make defconfig
```

## 配置项作用

### 目标

| 选项 | 作用 |
|---|---|
| `CONFIG_TARGET_ramips` | 目标平台 ramips（联发科 MIPS） |
| `CONFIG_TARGET_ramips_mt7621` | 子目标 mt7621，即 MT7621A 双核平台 |
| `..._DEVICE_xiaomi_mi-router-3g` | 具体机型；`TARGET_BOARD/SUBTARGET/PROFILE/ARCH_PACKAGES` 均由它推导 |

### 存储 / extroot

| 选项 | 作用 |
|---|---|
| `CONFIG_PACKAGE_kmod-mtd-rw` | 允许对 mtd 分区写入（改分区表、刷 bootloader 时用） |
| `CONFIG_PACKAGE_kmod-fs-ext4` | ext4 支持，extroot / U 盘系统盘 |
| `CONFIG_PACKAGE_kmod-fs-vfat` | FAT32 支持，U 盘通用格式 |
| `CONFIG_PACKAGE_kmod-usb-storage` | USB 存储设备（U 盘、移动硬盘）|
| `CONFIG_FSTOOLS_UBIFS_EXTROOT` | fstools 支持在 UBIFS 上做 extroot 覆盖层 |

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

**加软件包** —— 在对应分组加一行 `CONFIG_PACKAGE_xxx=y` 即可，`+` 声明的依赖由 kconfig 自动 `select`，不用手写 `kmod-*`/`lib*`。例如加 USB 网卡驱动全家桶、`luci-app-upnp`、`luci-app-ddns`。

**删软件包** —— 直接删除该行，回到该符号的默认值（对上面这些本来就是"默认未选"的包，等于不装）。

**关闭默认开启的功能** —— 这类不能靠删行，必须显式写 `# CONFIG_XXX is not set`（`diffconfig.sh` 输出的就是这个格式）。典型例子：

- `# CONFIG_TARGET_ROOTFS_INITRAMFS is not set` —— 不生成 initramfs 镜像，构建更快、产物更少；但救砖/TFTP 流程可能要它
- `# CONFIG_SIGNED_PACKAGES is not set` —— 跳过软件包签名校验，方便装第三方 ipk
- `# CONFIG_KERNEL_KALLSYMS is not set` —— 内核体积换调试能力

**换主题 / 语言** —— 替换 `luci-theme-aurora`，或加 `luci-i18n-openclash-zh-cn` 之类的插件翻译包。

**换设备** —— 三行 target 换成别的机型符号即可（同一 mt7621 子目标内）。

**LTE 上网卡** —— 只有 `kmod-usb-serial` 不够，还需 `kmod-usb-serial-option`、`kmod-usb-net-qmi-wwan`、`uqmi`、`luci-proto-qmi`（或 MBIM 一组）。

## 注意事项

1. **必须先装 feeds 再跑 defconfig**，顺序反了 feed 里的符号（如 `luci-app-openclash`）会被当成未知符号静默丢弃：

   ```sh
   ./scripts/feeds update -a && ./scripts/feeds install -a
   cp r3g.config .config && make defconfig
   ```

2. 想重新生成最小配置，让 buildroot 自己算（比手工删更可靠，不需要编译）：

   ```sh
   cp 完整配置 .config && make defconfig && mkdir -p tmp
   ./scripts/diffconfig.sh > r3g.config
   ```

3. 改完想确认没漏东西，两次展开后对比即可：

   ```sh
   cp 旧.config .config && make defconfig && cp .config /tmp/old.expanded
   cp r3g.config .config && make defconfig && cp .config /tmp/new.expanded
   diff -u /tmp/old.expanded /tmp/new.expanded
   ```

4. 构建见 `.github/workflows/build-binaries.yml`（OpenWrt v25.12.2，额外引入 OpenClash feed）。
