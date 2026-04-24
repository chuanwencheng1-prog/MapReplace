# MapReplacer - iOS地图资源管理器

## 项目简介
这是一个独立的iOS应用（非越狱插件），提供悬浮按钮和地图管理面板，用于下载和管理游戏地图资源文件。

## 功能特性
- ✅ 可拖拽的悬浮按钮
- ✅ 优雅的地图选择面板
- ✅ 支持6种地图下载（海岛、沙漠、雨林、雪地、Livik、Karakin）
- ✅ 自动备份原始文件
- ✅ 一键恢复原始地图
- ✅ 实时下载进度显示
- ✅ 横竖屏自适应

## 项目结构
```
MapReplacer-Standalone/
├── Classes/
│   ├── AppDelegate.h/m       # 应用入口和主界面
│   ├── MapManager.h/m        # 地图管理器（下载、替换、恢复）
│   └── UIOverlay.h/m         # UI界面（悬浮按钮+面板）
├── Resources/
│   └── Info.plist            # 应用配置
├── .github/workflows/
│   └── build.yml             # GitHub Actions编译脚本
├── Makefile                  # Theos编译配置
└── entitlements.xml          # 权限配置
```

## 编译方法

### 方法1：本地编译（需要Theos环境）
```bash
export THEOS=~/theos
make package
```

### 方法2：云端编译（推荐）
1. 使用GUI工具一键上传编译
2. GitHub Actions自动编译
3. 下载编译产物

## 安装方法
编译完成后会生成 `.deb` 包，可以通过以下方式安装：
- Filza文件管理器直接安装
- SSH传输后使用 `dpkg -i` 安装
- Cydia/Sileo本地源安装

## 使用说明
1. 安装并打开应用
2. 点击屏幕右侧的蓝色悬浮按钮
3. 在弹出的面板中选择地图
4. 点击"下载"按钮开始下载
5. 下载完成后自动应用

## 技术栈
- **开发框架**: Theos
- **语言**: Objective-C
- **最低支持**: iOS 9.0
- **架构**: arm64, arm64e

## 注意事项
- 本应用需要相应的文件系统访问权限
- 首次使用前请确保已运行过目标游戏
- 下载地图文件需要网络连接

## 许可证
MIT License

## 开发者
MapReplacer Team
