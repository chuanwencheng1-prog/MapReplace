# MapReplacer - iOS 地图替换器（IPA 版）

将原 dylib 越狱插件源码改造为 IPA 应用，无需越狱，通过 **TrollStore（巨魔）** 或 **自签** 即可安装。

主界面采用与原 dylib 完全一致的 **悬浮按钮 + 弹出面板** UI。

## 特性

- 🎯 **悬浮按钮 UI**：与原 dylib 插件的布局、动效、交互完全一致
- 🪟 **UIWindow 悬浮层**：使用 `UIWindowLevelAlert+100` 的独立窗口，支持拖动
- 📥 **下载管理**：NSURLSession 实时进度、下载完成自动替换
- 🗂 **文件替换逻辑**：保留原 dylib 的备份 `.bak_original` 与恢复机制
- 💾 **状态持久化**：通过 NSUserDefaults 记录当前已替换的地图类型
- 🔁 **iOS 13+ 兼容**：UIOverlay 适配 WindowScene，解决新系统悬浮窗不显示问题

## 目录结构

```
MapReplacer-App/
├── Classes/
│   ├── AppDelegate.h/m          # 启动后调用 [UIOverlay showFloatingButton]
│   ├── MapViewController.h/m    # 引导背景页（仅显示提示）
│   ├── MapManager.h/m           # 与 dylib 完全一致的下载/替换管理
│   └── UIOverlay.h/m            # 悬浮按钮 + 面板（来自 dylib）
├── Resources/
│   └── Info.plist               # Bundle 元信息
├── main.m                       # UIApplicationMain 入口
├── Makefile                     # Theos application 构建配置
└── entitlements.xml             # TrollStore 完整权限
```

## 与 dylib 行为的对应关系

| dylib 行为 | IPA 版实现 |
|---|---|
| `%ctor` 注入时创建 `/var/mobile/MapReplacerRes` | IPA 启动时在自身沙箱 Documents 下创建 `MapReplacerRes` |
| Hook `AppDelegate didFinishLaunching` 延迟 3s 显示悬浮球 | 自身 `AppDelegate` 启动后延迟 0.8s 显示 |
| 悬浮按钮点击弹出地图管理面板 | 完全一致（UIOverlay.m 直接复用） |
| 下载完成后直接写入目标 Paks 目录并备份 | 完全一致 |
| 记录当前地图类型 `MapReplacer_CurrentMap` | 完全一致 |

## 编译方法

### GitHub Actions 云编译

1. Fork 本仓库并启用 Actions
2. 运行 `Build iOS App` workflow
3. 在 Artifacts 中下载 `MapReplacer-App`（内含 `.ipa`）

### 本地编译（macOS）

```bash
export THEOS=~/theos
git clone --recursive https://github.com/theos/theos.git $THEOS

make clean
make package FINALPACKAGE=1
# 产物位于 packages/*.ipa
```

## 安装方法

### 方法 1：TrollStore（推荐）
直接将 `.ipa` 用 TrollStore 安装。entitlements 已包含 `platform-application`、`no-container` 等 TrollStore 扩展权限。

### 方法 2：自签名
- 使用 Sideloadly / TrollStore Helper / 爱思助手 / AltStore 等重签后安装
- 自签环境下无 `platform-application` 权限，应用只能操作自身沙箱 Documents

## 权限说明

| 权限 | 作用 |
|---|---|
| `get-task-allow` | 允许调试 |
| `platform-application` | TrollStore 专用：提升为平台应用 |
| `com.apple.private.security.no-container` | 脱离沙箱容器 |
| `com.apple.private.security.no-sandbox` | 禁用沙箱 |
| `com.apple.private.skip-library-validation` | 跳过库验证 |

## 许可证

MIT License
