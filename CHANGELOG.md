# CHANGELOG

> 每次修复功能后的记录（最新在上）。版本号对应 GitHub Release tag。

## 未发布（当前开发中，v4 批次）
- **修复 HTTP 明文流量被 Android 禁止（cleartext）**：视频播放报 `Cleartext HTTP traffic to 127.0.0.1 not permitted`、图片解码失败（下载到错误内容导致解码 unimplemented）——根因是 http 服务器（含本地代理）请求被 Android 9+ 默认拦截。主 Manifest 增加 `android:usesCleartextTraffic="true"`，http/https 服务器均可正常播放与加载
- **修复 AudioService not found（音频播放/后台通知）**：audio_service 插件的 AudioService/MediaButtonReceiver 未在 Manifest 注册（日志 `Unable to start service ... AudioService not found`），已补齐 service/receiver 注册 + FOREGROUND_SERVICE、FOREGROUND_SERVICE_MEDIA_PLAYBACK 权限
- 构建 debug APK 验证通过（analyze 0 error）


- **主页顶栏搜索框底色改为透明**：搜索框不设背景色，直接透出页面背景（任何主题下与背景天然一致）；保留圆角+浅描边标识输入框位置（深色 white24 / 浅色 black12）


- **主页搜索框深色底色改为对称方案**：白背景用浅灰搜索框（轻微区分），黑背景同样用同色系深灰 0xFF1C1C1E（原 0xFF2E2E34 偏亮突兀、完全同色又无边界），两种模式逻辑对称


- **修复主页顶栏搜索框深色模式底色不一致**：深色主题下搜索框底色原为 0xFF2E2E34（偏亮灰），与纯黑背景（0xFF121212）不协调；改为使用 CommonUtils.backgroundColor 与页面背景完全同色，仅靠边框区分（浅色模式不变；搜索页为原生 CupertinoSearchTextField 深色自适应无此问题）


- **修复 debug 模式红屏（No Material widget found）**：新建服务器页输入框是 Material 的 TextField，但页面为 Cupertino 风格树（CupertinoPageScaffold）无 Material ancestor，debug 断言直接报错并遮挡提示。TextFieldHelper.createCupertino 外包一层透明 Material（Colors.transparent）提供父级，不影响视觉，覆盖该页全部输入框


- **README 全面更新**：补充内部设计（双数据库分库/搜索索引机制）、标签驱动发布流程、迭代纪律、已知限制细化，并修正过时的 CI 描述


- **最近浏览支持缩略图**：addToRecent 保存时补写 object.thumb，图片类最近条目显示缩略图（组件与缓存机制此前已具备）
- **搜索结果显示缩略图**：FsSearchModel 新增 thumb 字段（含 g.dart 重新生成），网络递归结果携带 thumb，搜索列表/网格图片条目显示缩略图
- **下载管理器耦合复查（参考社区开源结构）**：DownloadService 单例全局收敛（6 处引用均走单例）、下载入口统一经 DownloadHelper（object_helper/长按菜单/各播放器共用），服务层无反向依赖页面，无循环耦合，无需结构改动
- **下载路径结论**：flutter_downloader 的 savedDir 直写系统公共下载目录 `Download/CloudX/{图片|视频|音乐|文档|压缩|文件}`，非 APP 私有空间，系统相册/文件 APP 可直接打开
- **列表大小显示结论**：列表与网格条目均已显示 `formatFileSize(size)`；若显示 0B，属服务器 PROPFIND 未返回 getcontentlength（服务器侧数据缺失），非本项目显示逻辑问题


- **发布流程改为标签触发**：GitHub Actions 改为推送标签（v*）时打包并发布 APP（不再每次 push main 都构建）
- **版本号随标签同步**：CI 从标签提取版本（如 v1.2.3 → pubspec 1.2.3+10203，Android versionCode/versionName 自动跟随），Release 使用推送的标签


- **连接错误页增加"新建服务器"按钮**：检测到服务器不可用时，错误页除"重试"外新增"新建服务器"按钮（OutlinedButton），一键跳转服务器添加页；未配置服务器场景已有"添加服务器"按钮


- **移动/剪切合并（去一留一）**：确认两者实现完全相同（都走 WebDAV MOVE，源位置删除）。按用户确认保留"移动"、删除"剪切"按钮（homepage + directory 双侧二级导航栏）、删除 _actionCut 死代码与 pull_down_cut 语言键


- **搜索参数按用户要求调整**：搜索结果上限恢复 500、递归深度保持 10 层；索引库不限量存储/查询（一次查询上限 1000 条，覆盖超大目录）


- **搜索崩溃加固**：索引为空时走网络递归，增加请求总数上限（250 次）+ 深度降到 6 层 + 结果上限降到 200，防止无节制递归风暴拉崩 App；每次搜索重置请求计数
- **下载状态重复显示修复**："失败 0%" 左右两侧各显示一次 → 改为左侧一行显示"大小·状态"，右侧仅在下载中显示速度与进度，失败/完成不再重复


- **删除进入/退出多选的烦人吐司**：toggleSelectMode / enterSelectMode 不再弹"已进入多选/已退出多选"提示（homepage + directory 双侧），选中状态看界面即可
- **清除文件缓存修复**：①提示词与入口标题统一（原提示"已清除网络图片缓存"与"清除文件缓存"标题不一致）；②逻辑补齐：现在同时清除缩略图缓存 + 网络图片缓存，统计两部分合计大小后统一清理，显示"已清除文件缓存 X"


- **修复顶栏搜索框不可点击/无法输入**：根因是搜索框在 Obx 里且每次 build 新建 TextEditingController——输入一个字符就触发 Obx 重建、controller 被替换、焦点丢失，表现像"灰色底色点不动"。改为独立 StatefulWidget（_HomeSearchField）持有稳定 controller，输入/聚焦不再被重建


- **下载管理排版**：路径单独一行、大小与状态/进度一行，上下排显示不再挤成一排
- **下载默认目录**：改为系统下载目录 Download/CloudX/图片|视频|音乐|文档|压缩|文件（按文件类型自动分目录），文件均在系统下载目录中，安卓自带 APP 可直接打开
- **重命名默认选中文件名主体**：打开重命名框时自动选中不含后缀的文件名（如"视频原神.mp4"默认选中"视频原神"），直接输入即可改名
- **错误页不再重复弹吐司**：视频/音乐播放失败等已有错误界面（优雅错误页）时不再同时弹 toast，避免重复提示
- **最近浏览点击秒开**：点击文件时直接用本地索引信息打开，不再每次网络加载父目录（文件夹仍需加载内容）


- **顶栏搜索框深色背景下隐形修复**：错误页等纯黑背景下搜索框几乎看不见（深灰底+灰字）。已提高对比度：深色模式搜索框背景提亮（#2E2E34）+ 白色半透明边框 + placeholder/搜索图标用白色系，任何页面下都清晰可见


- **所有错误页面统一 UI 审美风格**：连接错误、视频播放失败、音乐播放失败全部使用同款图二风格（纯色背景 + 简约插画 + 简短提示 + 重试），不再出现生硬的长报错文本与三角警告图标
- **修复服务器地址无法保存/新建服务器无效**：根因是 DB 升级 v4 时缺少 3→4 迁移，导致旧库打开失败、所有写入不可用；已补 migration3to4（创建 file_index 表及索引）
- **持久化数据库与索引数据库分库**：新增独立索引库 `xlist_index.db`（IndexDatabase，仅文件索引表），与主库 `xlist_database.db` 分开保存；索引损坏/清空不影响服务器、下载等业务数据；文件索引服务（FileIndexService）改走独立索引库


- **连接错误页统一为图二风格**：ConnectionErrorView 改为与空状态同款（纯色背景 + 简约插画 + 简短提示"请检查网络连接或服务器地址" + 重试按钮），不再展示 PROPFIND/GET 长报错文本



- 二级导航栏与一级导航栏对齐（同一高度与底部间距）
- 修复粘贴后回退到"选择目标文件夹"页：粘贴完成返回长按前的来源界面（fromRoute 回退所有选择目录层）
- 一级导航栏"下载"图标更换（arrow_down_circle），二级导航栏"下载"改名"下载文件"
- 修复重命名后跳回首页：列表刷新保持当前目录（getObjectList 默认 '/' 跳首页）
- 修复多选时列表反复刷新：列表 key 去掉选中数量（只保留多选状态）
- 顶栏搜索框不再显示路径名，固定显示"搜索"灰字提示
- 下载管理器：修复文字溢出（固定宽度改自适应 Expanded）；下载完成点击非音视频文件调用安卓系统应用打开（新增 open_filex 依赖）
- **新增本地文件索引**：浏览目录自动写入索引库（floor 新表 file_index，DB 升级 v4）；搜索先查本地索引（毫秒级、不再网络递归崩溃），无结果才联网递归；删除/重命名时自动同步清理或更新索引
- 检查下载管理器与视频播放器逻辑（Range 探测播放地址、下载速度监听均正常，无回归）



- **长按菜单重构为二级导航栏**：长按文件直接进入多选模式并选中该文件，底部显示与导航栏同款 UI 的二级操作栏（属性/下载/移动/复制/剪切/删除/重命名/复制链接/完成），支持横向滑动；安卓侧滑返回退出多选与二级栏
- **修复长按文件下载失败**：根因 `DownloadHelper.getDownloadUrl` 路径拼接缺 `/`（如 `/视频`+`原神.mp4` → `/视频原神.mp4` → WebDAV 404）→ 补斜杠后正常
- **修复粘贴后不退出目录选择页**：单文件移动/复制完成后 `Get.back()` 返回
- **修复删除后列表不刷新**：`refreshObjectList` 移除危险的 `Get.until`（路由不匹配会误 pop 页面）+ try-catch 兜底
- **缓存标题简化**：改为"清除缩略图缓存"、"清除文件缓存"（去掉溢出的注解文字）

## v1.0.13（commit 119d2c1，v2 批次）

- 缓存清理区分：缩略图缓存（列表缩略图/预览预取）与网络图片缓存（预览大图/封面），文案+副标题明确
- 移除 Android 12+ 系统启动 SplashScreen logo 一闪（透明启动图标）
- 图片查看器提速：图片链接并发获取 + 缩略图只预取当前±2 张
- 应用彻底改名 CloudX（MaterialApp title + 语言键 + 确认 manifest）
- CI 发布说明自动取最近提交信息（写明修复内容），Release 名称改 CloudX
- 新增详细 README（标注"本项目由纯 AI 构建"）

## v1.0.12（commit ce7aee2，自检 A~G 批次）

- 修复收藏/最近页 404（rawUrl 被当路径）
- 修复独立搜索页恒空（真搜索）
- 修复主题切换无效（持久化恢复）
- 删除假下载（detail 页 downloadObject）
- 清理死代码 -637 行（含剪贴板整条机制）
- 移动/复制/剪切统一走目录选择页、批量 confirmPaste

## v1.0.11（commit 52f6599，自检 H~K 批次）

- 废除启动画面残留（Routes.SPLASH 删除）
- 修复长按菜单下载报"菜单显示失败"（DeviceInfoService/DownloadService 未注册）
- 修复重命名后列表不刷新/点不开（列表 key 加 dataVersion）
- 修复缓存清理逻辑（DefaultCacheManager().emptyCache() + 显示 MB）

## v1.0.10（commit fa561c1，4 bug 批次）

- 修复搜索崩溃闪退（递归分批并发每批 10 个 + 空断言防御）
- 连接错误统一背景（ConnectionErrorView 组件）
- 目录选择页网格间距对齐主页
- 导航栏多选移除、并入长按菜单
- 新增通用自检-修复-验证-推送 Skill（docs/skills/self-check-repair）

## 更早批次

- 排序功能、多选批量操作、面包屑导航、文件夹递归下载
- 搜索进度与取消、空状态美化、响应式布局
- WebDAV 文件列表获取修复、音乐/视频播放器修复
- 缩略图显示、边缘滑动返回、悬浮圆角导航栏
- 删除"关于"页、全局设置持久化、重命名修复
