# 踩坑与根因

按**主题**归类，不按日期。每条格式：现象 → 根因 → 做法。

---

## 1. 构建环境（沙箱）

### 1.1 漏打 SDK / material_ui 补丁
- **现象**：`flutter build apk` 在 AOT 阶段报 66~68 条「未定义 getter / 无此命名参数」，集中在 `lib/common/widgets/**`。
- **根因**：项目依赖 Flutter SDK 私有成员与 `material_ui` 扩展 API，需要 `apply_patches.sh` 给 Flutter 打 24 个补丁、给 `material_ui` 打 9 个补丁。
- **做法**：`flutter pub get` → `bash /opt/sdk/apply_patches.sh android` → 再构建。`pub get` 必须在打 `material_ui` 补丁之前（会重新解包覆盖 pub-cache）。

### 1.2 本地 `material_ui` 解析到 1.7.0 编译失败
- **现象**：kernel 编译报缺少 `StandardBottomSheet` / `TabBarState` 等。
- **根因**：1.7.0 移除了仓库依赖的私有 API，且 `material_ui` 在 `pub get` 时会被重新解析到最新满足版。
- **做法**：本地临时在 `pubspec.yaml` 的 `dependency_overrides` 加 `material_ui: 1.5.0`，构建后 `git checkout -- pubspec.yaml pubspec.lock` 还原。**绝不提交**。CI 用它自己的解析结果，不受影响。

### 1.3 浅克隆导致 versionCode 变成 1 / 147
- **现象**：本地 APK `versionCode=1`（或 147），CI 是 5000+。
- **根因**：`build.ps1` / `build.sh` 用 `git rev-list --count HEAD` 算 versionCode，浅克隆只数到 graft 点。
- **做法**：`git fetch --unshallow origin` 补全历史；补全后不要再浅克隆。也可以用 `--build-number` 显式覆盖。

### 1.4 `android-37` 目录不存在
- **现象**：`Failed to find target with hash string 'android-37'`。
- **根因**：API 37 起 SDK 目录叫 `android-37.0`，AGP 仍按旧式查找。
- **做法**：`ln -sfn android-37.0 /opt/sdk/android/platforms/android-37`。

### 1.5 代理只认特定入口
- **现象**：`Remote host terminated the handshake`（直连 dl.google.com 被墙）；sdkmanager 列不出新包。
- **根因**：`sdkmanager` 只认 `HTTP_PROXY`；Gradle 只认 `~/.gradle/gradle.properties` 的 `systemProp.http(s).proxyHost/Port`，`GRADLE_OPTS` 与项目 `gradle.properties` 里的 JVM 参数都不生效。
- **做法**：按上述两处配置代理。**不要**写 `~/.gradle/init.gradle` 注入镜像，AGP 9 的 `FAIL_ON_PROJECT_REPOS` 会直接失败。

### 1.6 mihomo 首次启动 / 休眠被杀
- **现象**：后台启动立即 fatal；或长时间构建后 `Connection refused`。
- **根因**：首次下载 `geoip.metadb` 失败（实际用本地 `GeoIP.dat`，`geodata-mode: true`）；沙箱休眠会杀掉代理进程。
- **做法**：直接再启动一次；每次构建前确认代理存活。

### 1.7 R8 mapping 缓存损坏
- **现象**：`Cannot access output property 'mappingFile'` / `Failed to create MD5 hash`。
- **根因**：构建被休眠中断，写坏 `build/app/outputs/mapping/release/mapping.txt`。
- **做法**：`rm -rf build/app/outputs/mapping/release/` 后重编。

### 1.8 `flutter clean` 后忘记 `pub get`
- **现象**：`.dart_tool/package_config.json does not exist`。
- **做法**：clean 后必须重新 `flutter pub get`。

### 1.9 `flutter analyze` 全绿 ≠ 能编译
- **根因**：`analyze` 只报既有问题；AOT/CFE 会额外暴露「引用未打补丁 API」。
- **做法**：判断能否出包必须真跑一次 `flutter build apk`。合并上游时以「改动前后 analyze 结果集合一致」为口径，而不是追求零 warning。

---

## 2. 合并上游与发布一致性

### 2.1 tag 指向的 commit 与 APK 来源不一致
- **现象**：Release tag 指 A，APK 实际由 B 构建。
- **根因**：Release 步骤用输入 tag 绑定，artifact 由 workflow run 的 HEAD 构建。
- **做法**：改完先推 `main` → 删除旧 Release 与旧 tag → 从新 HEAD 带 tag 重新构建。发布后核对 tag 的 commit 与 run 的 HEAD。

### 2.2 保留 `@Keep` 导致 Java 编译失败
- **现象**：`cannot find symbol: class Keep`。
- **根因**：上游 2.1.6.2 改用 `proguard-rules.pro` 的 `-keep class ...AndroidHelper { public *; }` + `$ToDart`，删掉了 `androidx.annotation.Keep` import；冲突解决时若保留 fork 的 `@Keep` 注解就编译失败。
- **做法**：注解跟随上游构建方式删除，保留 `mergeM4sToMp4` 等实际代码。

### 2.3 import 区被整段覆盖
- **现象**：合并后 analyze 报未定义，但单个文件逻辑看起来没问题。
- **根因**：冲突解决时 import 区整体取了一边，另一边需要的 import 丢失。
- **做法**：两边 import 都保留；合并后用脚本核对「上游/HEAD 有而结果缺失」的 import。`connectivity_plus`、`platform_utils`、`SegmentType`、`AudioQuality` 都踩过。

### 2.4 依赖版本被 CI 重新解析
- **现象**：本地能编，CI 编不过；或补丁行为不同。
- **根因**：官方构建流程会删除 `material_ui` 包再 `pub get`，实际拿到当时最新满足版。
- **做法**：不要依赖本地 pub-cache 的具体版本；补丁要兼容上游实际解析到的版本。

### 2.5 合并后验证清单
- `flutter analyze`：改动前后问题集合逐条一致。
- `flutter test`：全量通过（播放器状态机用例必须包含）。
- `flutter build apk --release`：至少成功一次。
- 核对 fork 特性仍在：`applicationId`、`mergeM4sToMp4`、media_kit override、清风、PiliNova 命名/CI 前缀。

---

## 3. 播放器 / 详情页折叠

> 这块出过连续五轮误判，核心教训：**先确认渲染条件，再猜点击/主题/设置**。

### 3.1 灰色死区的状态不变式
- **现象**：打开视频不点播放，直接上滑折叠，视频区变成一块灰色实心区域，点也没反应。
- **根因**：播放器渲染条件是 `!videoState || !autoPlay || videoController == null → SizedBox.shrink()`，封面条件是 `if (!autoPlay)`。当 `autoPlay=true` 但播放器尚未就绪时，**播放器不渲染 + 封面已移除 = 灰色死区**。
- **做法**：封面与播放器的渲染条件必须**互补**——任何「`autoPlay=true` 但播放器不渲染」的状态都不允许出现；`handlePlay` 在播放器未就绪时回退 `playerInit(autoplay: true)`，不要静默 `play()`。

### 3.2 折叠工具栏覆盖层
- **现象**：`preInitPlayer=true` 时，一上滑折叠就整块变灰；播放过的视频正常。
- **根因**：`_buildHeaderOverlay` 在 `scrollRatio > 0` 时渲染一层不透明 `Container(color: colorScheme.surface)`。未播放时底下是封面，被整层盖住 → 灰。
- **做法**：`scrollRatio == 0 || !videoDetailController.autoPlay` 时**不渲染**该覆盖层；未进入播放态保持封面（封面层自带点击与返回/主页图标）。

### 3.3 点击按 `playedTime` 分流会「封面背后播放」
- **现象**：点灰条后像没反应；实际后端已在播，但封面没消失、头部没展开。
- **根因**：`playerInit` 末尾有 `playedTime = seek`。只要视频有观看进度（登录 + 看过），`playedTime` 在预初始化完成时就非 null；旧代码据此走 `onDoubleTapCenter()` → `playOrPause()`，但页面 `autoPlay` 仍为 false。
- **做法**：`_handleOverlayTap` 按**真实播放状态**路由：`!autoPlay || !playerStatus.isPlaying` → `handlePlay()`；正在播放 → 暂停。

### 3.4 查询/初始化期间点击被丢弃
- **现象**：加载播放地址时点击无效，之后也不会自动播。
- **根因**：`isQuerying` / `processing` 分支直接 return，没有记录播放意图。
- **做法**：查询期间写 `pendingPlay`，URL 就绪后由视图层 `StreamSubscription` 续播；初始化进行中写 `plPlayerController.autoPlay = true`；`onInit` 里 `autoPlay && !isPlaying` 时补 `play()`，堵住「初始化已读过旧值」的缝隙。

### 3.5 首次加载被误判为尺寸中间态
- **现象**：用户手动折叠后又被强行展开，工具条闪烁/消失。
- **根因**：`_setVideoHeight` 的 else 分支把「用户主动折叠」当成「尺寸未校正」而 `isExpanding + forward`。
- **做法**：else 展开只保留给显式重载（切画质/音质/语言），首次加载用 `fromReset` 区分。移除「播放后 320ms 强制拉回顶部」，避免打断滚动。

### 3.6 回归测试
- 状态机单测：`test/pages/video/fold_deadzone_test.dart`。
- 必测场景：有进度+折叠+点击、无进度+折叠+点击、播放→暂停→折叠→点击、长视频/异形比例。
- 台架注入登录态要走应用自身路径（`LoginAccount(...).onChange()` + `Accounts.refresh()`）；导航用 `Get.toNamed`，不要 `offAllNamed`（会销毁首页并 `GStorage.close()`，后续 `Pref` 读 Hive 抛异常）。

---

## 4. 设置导入 / 主题

### 4.1 导入是「先 clear 再 putAll」
- **现象**：旧版导出设置导入后，某些行为和新装默认值一致，而不是保留当前值。
- **根因**：`GStorage.importAllJsonSettings` 对 `setting`、`video` 两个 box 执行 `clear()` 再 `putAll()`。
- **做法**：按导入后的最终值判断；JSON 缺失的键会回落代码默认值。排查时先列出「JSON 里没有、但代码有默认值」的键。

### 4.2 灰块曾被误判为纯黑/主题色问题
- **反例**：开 `isPureBlackTheme`、改 `schemeVariant`、改 `themeMode` 都没有解决灰块。
- **根因**：灰块是折叠覆盖层（见 3.2），与主题无关；加 `isPureBlackTheme` 只是把中性深灰换成纯黑。
- **做法**：先确认该区域是 `colorScheme.surface` 实心块还是图片叠加色；是渲染状态问题就去查 `autoPlay / videoState / scrollRatio`，不要先动主题。

### 4.3 枚举 / 索引不要凭猜测改
- `themeMode`：`0` 浅色 / `1` 深色 / `2` 跟随系统。
- `schemeVariant`：`FlexSchemeVariant` 索引；当前依赖 5.0.1 中 `10` 合法（`material3Legacy`），不是越界值。
- `reduceLuxColor`：深色下图片叠加色，异常才会让图片整体发灰。
- 改之前对照 `storage_pref.dart` 的读取逻辑与枚举定义，不要只改 JSON 猜。

### 4.4 导出范围
- 只导出 `setting` + `video` 两个 box。
- 哔哩清风 API Key 在独立的 `breeze` box，**不会随设置导出**；换机后需要重新填。

### 4.5 新增设置项
- 同时改 `storage_key.dart` 与 `storage_pref.dart`（含默认值），再加设置页 UI。
- 只在 `setting` box 里就能被导出；放其他 box 不会。

---

## 5. 音频 / 缓存 / 下载

### 5.1 耳机无法控制音乐播放器
- **根因**：`audio_handler.dart` 未实现 `skipToNext` / `skipToPrevious`；`PlPlayerController.instanceExists()` 守卫阻止播放状态更新。
- **做法**：补两个方法（类型 `void Function()?`），移除该守卫。合并上游时注意上游重构过 `onUpdateState` 签名。

### 5.2 合并缓存的回退判断
- **现象**：合并失败后回退逻辑编译不过或行为异常。
- **根因**：guarded-case 在 `&&` 后绑定变量会报错；`Success` 的字段名是 `response` 不是 `r`。
- **做法**：用嵌套 `if (forceMerged) { if (res case Success(:final response)) { ... } }`。

### 5.3 播放列表排序不一致
- **做法**：本地播放列表按 `pageId` 分组、组内按 `sortKey` 排序，并把当前缓存条目插入首位。

### 5.4 下载面板缺 import
- 合并/改造下载面板后，`platform_utils.dart`、`connectivity_plus` 容易被漏掉；改完跑 analyze 并检查 import。

---

## 6. 其他

### 6.1 沙箱休眠中断长构建
- 会杀代理、写坏 R8 产物。构建前确认代理存活，失败后按 1.7 清理。

### 6.2 「主项目」的定义
- 用户说的主项目 = `fork/main`（个人仓库 `silverwolf-lv9999/PiliPlus` 的 `main`），不是上游，也不是 `test/*` 分支。

### 6.3 改名只改显示名
- 只改 `appName`、Android `string.xml` / `AndroidManifest.xml` 的 label、iOS `Info.plist`。
- 不改 Dart 包名、`package:PiliPlus/...`、源码目录、`applicationId`、仓库 slug。

### 6.4 用户说「只改设置，不动软件」
- 严格遵守：只修改导出的 JSON / 配置文件，不碰仓库源码。先确认问题确实在设置侧，不要把代码 bug 硬塞进设置里绕过。
