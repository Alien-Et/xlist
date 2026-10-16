# CloudX（原 Xlist）

> **本项目由纯 AI 构建**：从原型魔改、功能开发、Bug 修复到 CI/CD 发布，全程由豆包（Doubao）AI 助手完成，仅由用户提供需求、服务器配置与真机验收。项目自带「自检-修复-推送-记录」闭环，每次迭代都有提交与文档留痕。

CloudX 是一款基于 **Flutter + WebDAV** 的跨平台云盘文件管理器，支持浏览、搜索、预览、下载、上传、移动/复制、多选批量操作、缩略图缓存、在线播放、本地搜索索引等完整能力，兼容 Cloudflare Workers / AList 等 WebDAV 代理服务。

---

## ✨ 功能特性

| 模块 | 能力 |
|---|---|
| **文件浏览** | 网格/列表双布局、排序（时间/名称/大小）、面包屑路径导航（根目录显示「首页」）、下拉刷新、中文目录支持 |
| **多选批量** | 长按进入多选模式 → 批量移动/复制/删除，操作同步到 WebDAV 服务器 |
| **长按二级导航栏** | 长按弹出与一级导航栏同 UI 的操作栏：属性 / 下载文件 / 移动 / 复制 / 删除 / 重命名 / 复制链接 / 完成；位置不够可左右滑动 |
| **搜索** | 本地索引优先（毫秒级命中），未命中走轻量并发递归搜索（深度 10 / 上限 500 / 请求限流 / 防抖，防闪退）；结果条目显示缩略图、文件名、大小 |
| **预览** | 图片查看器（渐进加载）、视频/音乐在线播放（自动解析实际地址 + Range 探测，避开 /dav 触发下载的坑）、文档预览（PDF/Office） |
| **下载** | FlutterDownloader 真下载（通知栏进度/速度）、文件夹递归下载、断点续传、下载后点击可用系统 APP 打开 |
| **下载目录** | 直接下载到系统公共目录 `Download/CloudX/图片|视频|音乐|文档|压缩|文件`（按扩展名自动分类，非 APP 私有空间） |
| **服务器** | 多 WebDAV 服务器管理、服务器选择持久化（重启记住上次服务器）、密码管理 |
| **收藏/最近** | 一键收藏；最近浏览支持缩略图、点击秒开（本地索引直开） |
| **缓存** | 缩略图缓存（本地 thumbnails 目录）、网络图片缓存（HTTP 缓存）、文件缓存，清理量以 MB 显示；清除缩略图缓存/清除文件缓存文案区分 |
| **体验** | 深色/浅色主题持久化、毛玻璃悬浮导航栏、Telegram 风格导航栏、统一优雅错误页（同款背景图+简短提示）、全局持久化设置（重启不丢） |

## 🧠 内部设计

### 双数据库分库

| 库 | 文件 | 内容 |
|---|---|---|
| **持久化库** | `xlist.db` | 服务器配置、最近浏览、下载记录、进度、收藏、密码、文件索引（drift，version 4） |
| **索引库** | `xlist_index.db` | 独立索引库（仅文件索引），与持久化库物理分离，避免索引膨胀拖累配置读写 |

### 搜索索引机制

- 浏览文件时自动将对象写入本地索引（`FileIndexService`），加速下次搜索
- 文件被删除时同步清除对应索引（removeFile / removeDirectory）
- 搜索命中索引直接返回（上限 1000），未命中再走网络递归兜底

### 核心目录结构

```
lib/
├── main.dart              # 入口：初始化下载引擎 + 主题恢复 + 路由
├── global.dart            # 服务装配（存储/DAO/DeviceInfo/DownloadService）
├── routes/                # 路由常量与 GetPage 注册
├── pages/                 # 页面（homepage/directory/detail/file/search/setting/播放器/下载管理）
├── components/            # 通用组件（列表/网格/空状态/统一错误页/悬浮导航栏/二级导航栏）
├── services/              # 服务（core_service/object_repository/thumbnail_cache/download_service/file_index_service…）
├── helpers/               # 工具（object_helper/download_helper/preview_helper…）
├── models/                # 数据模型（ObjectModel/FsSearchModel…）
├── database/              # drift 本地库（持久化库 + 索引库，独立文件）
└── langs/                 # i18n（zh_Hans/en_US）
```

技术栈：**Flutter + GetX（状态/路由/依赖注入）+ drift（本地双库）+ flutter_downloader（下载）+ cached_network_image（图片缓存）+ keframe（列表帧缓存）+ dio（WebDAV 请求）+ jiffy（日期）**

## 📦 安装

- **GitHub Releases**（自动构建）：`https://github.com/Alien-Et/xlist/releases`
  - `app-release.apk`：正式发布版（已签名，带版本号）
  - `app-debug.apk`：调试版（含调试日志）
- 或本地构建（见下）

## 🛠 本地构建

环境要求：Flutter 3.47.x stable、JDK 17、Android SDK（含 NDK 27）。

```bash
git clone https://github.com/Alien-Et/xlist.git
cd xlist
flutter pub get

# 调试 APK（仅 arm64）
flutter build apk --debug --target-platform android-arm64

# 正式 APK（需配置签名，见 android/keystore.properties）
flutter build apk --release --target-platform android-arm64
```

> Linux / Windows / macOS 命令一致；Android 端也可用 Termux 等环境执行上述 flutter 命令。

## 🚀 发布流程（标签驱动）

`.github/workflows/release-apk.yml`：

1. **推送版本标签（`v*`）自动触发打包发布**，如 `git tag v1.0.2 && git push origin v1.0.2`
2. **版本号随标签同步**：CI 从标签提取版本（如 v1.0.2 → pubspec `1.0.2+10002`），Android versionCode/versionName 自动跟随，**无需手动改版本号**
3. 构建 release（已签名）+ debug 双 APK
4. 以**最近提交信息作为发布说明**（每次发布写明修复/变更内容）
5. 挂载双 APK 发布到 GitHub Releases（Release 名 = 标签名）

日常 push main 不会触发构建，只有推标签才会出包。

## 🧭 项目文档

- **PROJECT_MAP.md**：项目架构脑图报告（AI 阅读用），含总览、模块耦合、死代码清单、矛盾清单、变更记录，**每次修复后同步更新**，AI 每次修复项目时据此动态更新
- **CHANGELOG.md**：逐次修复记录（每次修复都记录改动内容）
- **docs/skills/self-check-repair/SKILL.md**：自检-修复-验证-推送通用 Skill（适用于任何项目，不只本项目）

## 🔁 迭代纪律（本项目的工作方式）

- 每次修复只改用户点名的逻辑，其余保持不动
- 每修一个问题，与全部脚本比对耦合度（grep 全局引用）
- 每次修复自动 `git push`，并在 CHANGELOG / PROJECT_MAP 留痕
- 修复完做门禁验证：`flutter analyze` 0 error → 构建 debug APK → 真机验收

## ⚠️ 已知限制 / 待优化

- 双列表解析（core_service 重诊断 vs object_repository 轻量）待收敛
- 播放器 video/audio 逻辑重复，待抽公共基类
- Fs* 模型与 ObjectModel 并存待统一
- WebDAV 权限模型与实际登录角色不完全匹配（UI 层已做降级）
- 文件大小为 0B 时属服务器 PROPFIND 未返回 `getcontentlength`（服务器侧数据缺失，非本项目问题）

## 🙏 说明

- 本项目基于开源 Flutter WebDAV 文件管理器原型修改而来，后续功能、修复与迭代全部由 AI 完成
- 数据库/包名等内部标识仍保留历史命名（xlist），不影响使用
- 所有发布版本均来自 GitHub Actions 自动构建，可在 Releases 页追溯
