# Sidecar Connect

[English](README.md)

macOS 命令行工具，用于管理 Apple Sidecar（随航）显示连接。通过调用 `SidecarCore.framework` 私有框架，实现从命令行列出、连接和断开 Sidecar 设备，并支持连接后自动设置镜像模式。

## 功能

- **列出设备** — 查看所有可用的 Sidecar 设备及连接状态
- **连接设备** — 按名称连接 Sidecar 设备，连接后自动设置镜像模式
- **断开设备** — 断开所有 Sidecar 连接
- **自动连接** — 通过 launchd 或登录项实现开机自动连接

## 系统要求

- macOS 10.15 (Catalina) 及以上
- Xcode Command Line Tools (Swift 5.9+)

## 构建

```bash
make build
```

构建产物位于 `.build/release/SidecarConnect`。

## 安装

```bash
make install
```

安装流程会：

1. 编译 release 二进制并安装到 `~/bin/sidecar-connect`
2. 对二进制进行代码签名和扩展属性清理
3. 编译 AppleScript 登录项应用到 `/Applications/SidecarAutoConnect.app`
4. 添加为 macOS 登录项
5. 安装 launchd plist 到 `~/Library/LaunchAgents/` 并加载

## 卸载

```bash
make uninstall
```

## 使用

```bash
# 列出可用设备
sidecar-connect --list

# 连接设备（不区分大小写）
sidecar-connect --connect iPad

# 断开所有连接
sidecar-connect --disconnect
```

连接成功后，工具会自动将 Sidecar 显示器设为主显示器的镜像。

## 自动连接

安装后，系统登录时会通过 launchd 自动执行 `sidecar-connect --connect iPad`。

如需每 60 秒定时重连（适用于蓝牙设备间歇断连场景），可改用 `com.user.sidecar-auto.plist`：

```bash
cp com.user.sidecar-auto.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.sidecar-auto.plist
```

> **注意**：两个 plist 不应同时启用，请先卸载再替换。

日志文件位于 `/tmp/sidecar-connect.log` 和 `/tmp/sidecar-connect.err`。

## 注意事项

- 本工具依赖 macOS 私有框架 `SidecarCore.framework`，可能在系统更新后失效
- 自动连接默认设备名为 `iPad`，如设备名称不同需修改 plist 和脚本中的名称
- 镜像模式会将所有非主显示器设为主显示器镜像

## 许可证

[MIT](LICENSE)