# 开发备忘录（PiliPlus 二开项目）

> 本文件用于在会话历史被压缩后快速找回项目上下文。遇到“以前说过的要求”丢失时，先读此文件。

> ### 📌 铁律（务必遵守）
> **每完成一次代码/配置修改或发布，都必须立刻在本文件「九、更新 / 修改日志」追加一条日志**，记录：日期、改动内容、涉及文件、构建/发布来源（如 commit / run 号 / tag）。上下文被压缩后也照样执行——新任务的第一个动作应是浏览本文件最近一条日志，确认当前基线和“已做/未做”。

## 一、仓库与身份

- 上游官方仓库（origin）：`bggRGjQaUbCoE/PiliPlus`
- 用户个人仓库（fork）：`silverwolf-lv9999/PiliPlus`
- 这是对官方 PiliPlus 的二次开发版，目标是把自研功能并入个人仓库的 `main`。

### ⚠️ 最关键一句话：「主项目」
用户指的“我的主项目”是**个人仓库 `fork` 的 `main` 分支**（曾经/现在也反映在 `test/cache-tag-combined` 上）。做功能、发版本都以 `fork/main` 为基准，不要混淆成别的分支。

## 二、分支规则（非常重要）

- **`main`**：主项目 / 基准分支，最终发布用。
- **`pr/*`**（`pr/tag-filter`、`pr/cache-listen`、`pr/fix-headphone-control`）：**已经提交给上游官方仓库的 PR 分支，绝对不要改动、不要并入 main、不要删除**，只在需要更新 PR 时操作。
- **`feat/*`、`test/*`**：开发/测试分支，功能验证后并入 main，再清理（或保留视用户选择）。
- 新功能原则上：先开发 → 验证 → 合并进 `fork/main`，且尽量**不污染提交给上游的 PR 分支**。

## 三、已实现的功能清单（均已并入 main）

| 功能 | 说明 |
|---|---|
| 视频 TAG 屏蔽 | 设置中按视频 tag 过滤推荐/热门/排行榜/相关推荐，屏蔽词列表式管理 |
| 缓存「听视频」 | 离线缓存支持仅音频播放 |
| 仅下载音频 | 缓存时可只下载音频流，缓存列表以音质角标区分 |
| 缓存音质选择 | 勾选「仅下载音频」时画质选项切换为音质 |
| 自定义缓存路径 | 可自定义缓存目录 |
| 合并缓存（安卓） | 按哔哩终端方式，把 DASH 分离的音/视频在本地用 MediaMuxer 合成为单个 MP4 |
| 播放列表正序/倒序 | 本地缓存播放列表支持排序切换 |
| 耳机控制 | 音乐播放器支持耳机播放/暂停、切换上下首（skipToNext/skipToPrevious、移除 PlPlayerController instanceExists 守卫） |
| 下载面板优化 | 顶部控件两行排布；「仅下载音频」放第二行；仅音频时自动隐藏「合并/分离缓存」选项；移除「当前网络」显示 |
| 关于页链接 | 关于页新增「本 fork 仓库」链接指向 silverwolf-lv9999/PiliPlus |

## 四、构建 / 发布流程

- 用 **GitHub Actions**（`.github/workflows/build.yml`）构建 APK。
- 工作流用法：`workflow_dispatch`，参数：
  - `ref`：分支（发布用 `main`）
  - `tag`：**为空 = 只出 artifact，不创建 release**；**非空 = 创建 release**。
  - `app_version`：**系统/应用内版本号**（如 `2.1.4x2`），传给 `build.ps1`，同时作为 `pili.name`（应用内展示）和 `--build-name`（Android 版本名）；留空则用上游版本+提交 hash。
  - 测试阶段 `tag=""`，不发 release；发布时同时传 `app_version=<版本号>` 和 `tag=<tag>`。
- **签名（自 2.1.4.2 起）**：不用 debug 签名，用本地 `.signing/release_keystore.jks`（alias `piliplus`）。CI 通过 `SIGN_KEYSTORE_BASE64`/`KEYSTORE_PASSWORD`/`KEY_ALIAS`/`KEY_PASSWORD` 4 个 secrets 解码并配置签名；本机 build.gradle.kts 若存在 `android/key.properties` 也会用 release 签名。
- **版本命名规范**：release 名用 `上游版本号.X`（如 `2.1.4.2`）；但 **Android 系统/应用内版本号用 `2.1.4xN` 格式**（字母 x 分隔，如 `2.1.4x1`/`2.1.4x2`）——因为 Flutter 的 pubspec `version` 不接受四段点数（`2.1.4.2` 会被判非法并回退成 `1.0`/`1`）。
- **版本号怎么落地**：`build.ps1` 只把**合法的三段版本名**（如 `2.1.4`）写进 pubspec，`versionCode` 用 `git rev-list --count`；`flutter build` 用 `--build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"` 覆盖，使系统版本名= `2.1.4xN`、versionCode 正确。详见日志「2.1.4.2 版本号回退修复」。
- **更新日志要求**：写“本次 release 相比上一次 release 改了什么”，不要罗列历史累积的所有功能。
- 发布后需 `PATCH` release 改 `name`（默认是 tag 名）并写 `body`（更新日志）。
- 拉取 APK 用 artifact 下载接口（需 token，`repo` + `actions:read`）。

## 五、包名规则（用户明确要求）

- **未到最终版：不要用原版包名 `com.example.piliplus`**。
- 测试版本用临时包名（例如 `test.piliplus.com`），可与官方版共存；最终版才可考虑恢复/定名。

## 六、重要踩坑 / 已修复 bug（再犯时注意）

1. **release 的 tag 与 APK 二进制来源无法保证一致**：软发布的 Release 步骤用输入 tag 绑定 release，但 artifact 由 workflow run 的 HEAD 构建。若 tag 未指向该 HEAD，会出现“tag 指向 A commit、APK 却是 B commit”。**规范做法：改完代码先推到 main → 删除旧 release+tag → 带 tag 重新构建（tag 落在新 HEAD）**，保证 tag 与 APK 一致。
2. 耳机无法控制音乐播放器：需在 `audio_handler.dart` 实现 `skipToNext/skipToPrevious`，并移除 `PlPlayerController.instanceExists()` 对播放状态更新的守卫。
3. 音乐播放器列表与缓存列表排序不一致：本地播放列表应按 `pageId` 分组、组内按 `sortKey` 排序，且把当前缓存视频条目插入列表首位。
4. 合并缓存回退判断：用嵌套 `if (forceMerged){ if(res case Success(:final response)){ ... } }`，避免 guarded-case 在 `&&` 后绑定变量报错；`Success` 字段名是 `response` 不是 `r`。
5. 结构化 UI 修改后记得同时处理相关 import（如删掉不再使用的 `connectivity_plus`、`platform_utils`），避免 analyze 报错。

## 七、当前状态（截至 2026-09-14）

- `main`＝`test/cache-tag-combined` 均指向最新完整版（含上表全部功能 + 状态命令如 AndroidHelper.mergeM4sToMp4 等）。
- Release 已规范化：`2.1.3.2~2.1.3.7`（基于官方 2.1.3）、`2.1.4.1~2.1.4.2`（基于官方 2.1.4）。翻译版 2.1.3.1 已删除。
- 最新：`2.1.4.2`（tag `v2.1.4.2`）改用**正式 release 签名**（非 debug），并支持**应用内版本号显示 `2.1.4.2`**。
- 个人仓库 token：需要时向用户索取（GitHub PAT，repo+actions 权限）。签名/口令存于本地 `.signing/`（已 gitignore）。

## 九、更新 / 修改日志

> 记录每次发布与主要代码改动的历史，做新任务前先看最近一条确认当前基线与“已完成/未完成”。

### 2026-09-14 【优化】动态「…」底部面板可滚动
- 现象：小屏/选项多时动态「…」面板选项溢出，下方按钮（如「删除」）被截在屏幕外点不到。
- 改动：`lib/pages/dynamics/widgets/author_panel.dart` 的 showModalBottomSheet 里，把选项列表包进 `ConstrainedBox(maxHeight: 屏幕高*0.6)` + `SingleChildScrollView`（顶部手柄和底部「取消」保持固定），屏小可滑动看到全部选项。
- 状态：仅安卓可验证；沙箱无 Flutter SDK，未跑 analyze。

### 2026-09-14 【PR提交】自定义缓存路径 + 合并/分离缓存
- 用户要求：把「自定义缓存路径」和「合并下载」提给上游 bggRGjQaUbCoE/PiliPlus。
- 分支：`pr/merge-cache`，基于最新上游 `a3f9c90d3`，**仅含** 3 个提交（功能 `e789821c2` + 2 个修复 `706377bbf`/`cc1db1070`），13 文件 +337 行，与原始功能逐字一致。
- 已推送到 fork `pr/merge-cache`。⚠️ 当前 PAT（fine-grained）无上游仓库权限，**无法用 API 在上游创建 PR**；需用户浏览器点「Compare & pull request」：
  - URL：`https://github.com/bggRGjQaUbCoE/PiliPlus/compare/main...silverwolf-lv9999:pr/merge-cache?expand=1`
  - title：`feat: 自定义缓存路径与合并/分离缓存（安卓本地 MediaMuxer 合并）`

### 2026-09-14 【新功能】动态分享新增「复制链接」（仅新增，不动已有复制入口）
- 来源：上游 issue bggRGjQaUbCoE/PiliPlus#2606「分享功能可不可以只复制链接」，用户确认痛点=动态没有复制链接选项。
- 最终方案（用户要求）：**只新增**，不改动原本就带「复制链接」的入口。
- 改动（基于当前 main，未发 release）：
  - `lib/pages/dynamics/widgets/author_panel.dart`：动态「…」面板新增「复制链接」项（`Utils.copyText('${HttpString.opusBaseUrl}/${item.idStr}')`），并新增 `import utils/utils.dart`。
  - ⚠️ 曾一度把 `shareText` 改成弹菜单 + 加 `shareToApp` 并改动 6 处自带复制入口，后按用户要求**全部还原**（`share_utils.dart` 与其它入口恢复原样）。当前净改动仅 author_panel 一处。
- ⚠️ 沙箱无 Flutter SDK，未跑 `flutter analyze`，需构建验证。

### 2026-09-14 【修复】2.1.4.2 版本号回退成 1.0/1
- 现象：安装后 Android 系统显示版本名 `1.0`、版本号 `1`（文件名却对，是 `2.1.4.2+5381`）。
- 根因：Flutter 的 pubspec `version` 不接受四段点数版本名（`2.1.4.2`），构建时报 `Invalid version ... default value will be used`，回退成默认 `1.0`/`1`。
- 修复：
  - `lib/scripts/build.ps1`：pubspec 只写**合法三段版本名** `2.1.4+<versionCode>`；`pili.name`（应用内展示）与 `env.BUILD_NAME` 用展示版本号；新增输出 `BUILD_NUMBER`。
  - `.github/workflows/build.yml`：`flutter build apk ... --build-name="${{ env.BUILD_NAME }}" --build-number="${{ env.BUILD_NUMBER }}"`。
- 版本格式（用户确认）：**系统/应用内版本号用 `2.1.4xN`**（字母 x 分隔），本次发布为 `2.1.4x2`、versionCode `5383`（APP 内部 versionName=`2.1.4x2` 已验证）。
- 提交：`fork/main` @ `e9dc284ce`；发布 run/action 号 34842905489，release 名 `2.1.4.2`、tag `v2.1.4.2`。
- 文件：`lib/scripts/build.ps1`、`.github/workflows/build.yml`。

### 2026-09-14 【正式签名 + 应用内版本号】重新发布 `2.1.4.2`（tag `v2.1.4.2`）
- 背景：应用内版本号需显示 `.X` 后缀（如 `2.1.4.2`）；并且不再用 debug 签名，改用本地新生成的 release 签名。
- **新签名**：用 `keytool` 生成 `.signing/release_keystore.jks`（alias `piliplus`），口令存于 `.signing/keystore.env`（两者均已加入 `.gitignore`，切勿提交）。
- **CI 接入**：在 `silverwolf-lv9999/PiliPlus` 仓库配置了 4 个 Actions secrets：`SIGN_KEYSTORE_BASE64`（keystore 的 base64）、`KEYSTORE_PASSWORD`、`KEY_PASSWORD`、`KEY_ALIAS=piliplus`。`.github/workflows/build.yml` 的「Write key」步骤会自动解码生成 `android/app/key.jks` 并写入 `android/key.properties`，`build.gradle.kts` 读到即用 release 签名（非 debug）。
- **版本号覆盖**：`lib/scripts/build.ps1` 新增 `VersionOverride` 参数；`build.yml` 新增 `app_version` 输入（如 `2.1.4.2`）传给构建脚本，`pili.name` 即应用内版本号。发布时传 `app_version=2.1.4.2`。
- 本次改动提交：`fork/main` @ `22ee85310`。
- **发布动作**：删除旧 `2.1.4.2`（release+tag `v2.1.4-fork-full`），触发 Android 构建（run/action 号 34837045416，仅安卓，其余端 skipped），release 名 `2.1.4.2`、tag `v2.1.4.2`。APK 名含 `2.1.4.2+5381`。
- **签名校验**：下载 arm64 APK，`keytool -printcert` 的 SHA256 指纹 `6F:62:B5:03:...` 与 `.signing/release_keystore.jks` 完全一致，确认用的是新 release 签名。

### 2026-09-14 发布：`2.1.4.2`（旧版，tag `v2.1.4-fork-full`，已删除）
- 相对 2.1.4.1 新增：自定义缓存模式（合并/分离缓存 + 自定义缓存目录）；安卓合并缓存（DASH 音画本地合成为单个 MP4）。
- 改进：下载面板顶部两行排布，「仅下载音频」放第二行；仅下载音频时自动隐藏「合并/分离缓存」、画质自动切音质；画质文案调整、移除「当前网络」；关于页新增「本 fork 仓库」链接。
- 构建来源：`fork/main` @ `4d0846717`。**该 release 后来按用户要求删除并改用新签名重建为 tag `v2.1.4.2`（见上条）。**

### 2026-09-14 发布：`2.1.4.1`（tag `v2.1.4-cache-tag`）
- 同步官方 PiliPlus v2.1.4 全部更新，保留视频 TAG 屏蔽与缓存听视频/仅下载音频功能。
- 构建来源：`test/cache-tag-combined` @ `d0f770cd9`。

### 2026-09-13 发布系列（基于官方 2.1.3）
- `2.1.3.2`（tag `v2.1.3-tagfilter`）：视频 TAG 屏蔽。
- `2.1.3.3`（tag `v2.1.3-cachelisten`）：缓存听视频 / 仅下载音频，缓存音频进音乐播放器。
- `2.1.3.4`（tag `v2.1.3-cachelisten2`）：缓存音质选择，仅音频与视频区分显示，播放列表正序/倒序。
- `2.1.3.5`（tag `v2.1.3-cache-tag`）：整合标签过滤与缓存听视频分支。
- `2.1.3.6`（tag `v2.1.3-cache-tag-fix`）：修复若干问题（未附安装包）。
- `2.1.3.7`（tag `v2.1.3-cache-tag-fix2`）：修复缓存视频经耳机图标进入音乐模式时标题/封面错取首个仅音频项。
- 曾存在的 `2.1.3.1`（翻译版）已因失败废弃并删除，当前序列不含它。

### 2026-09-14 分支整理
- 确认“主项目”=`fork/main`，`test/cache-tag-combined` 与其对齐。
- 已将 `feat/custom-cache`（自定义缓存/合并缓存）并入主项目；合并时解决 3 处冲突：
  - `bili_download_entry_info.dart`：`audioOnly/audioQuality` 与 `preferMerged` 并存。
  - `download_panel/view.dart`：保留「仅下载音频」开关 + 「合并缓存」下拉 + 移除当前网络 + 画质文案。
  - `download_service.dart`：`downloadVideo/downloadBangumi` 参数同时保留 `audioOnly/audioQuality` 与 `merge`。
- README.md 改为二开版描述（badge/声明/Star History 指向 `silverwolf-lv9999/PiliPlus`）。

### 2026-09-14 备忘录建立
- 创建 `DEV_MEMO.md`：汇总仓库/主项目、分支规则、功能清单、构建/发布/版本命名规范、包名规则、踩坑记录、当前状态、常用操作速查、更新/修改日志。
- 顶部新增铁律：每次修改或发布后必须立即在本文件第九节追加日志（压缩上下文后依旧执行，新任务先读最近一条日志确认基线）。

### 【新功能】应用内返回不停止音频 + 悬浮窗控制（设计中）
- 需求：内置音乐播放器播放音频时，**应用内返回上一层不停止播放**，可继续浏览评论/动态等，并提供一个可拖动悬浮窗随时控制播放。
- 开关：设置里可开/关；音乐播放器界面也可开/关。
- 当前状态：设计中，待摸底现有音频架构后给出实现方案。

### 2026-09-14 【进行中·未发布】应用内返回不停止音频 + 悬浮窗控制（实现中）
- 方案定为「全局永久播放会话」：`AudioController` 以固定 tag `audioFloatSession` 永久注册，播放器/曲目/播放列表不再随页面返回销毁；页面仅作为会话的「窗口」。
- 改动文件：
  - `lib/utils/storage_key.dart`、`lib/utils/storage_pref.dart`：新增设置项 `enableAppFloatAudio`（默认 false）。
  - `lib/pages/audio/controller.dart`：拆出 `enterSession/_parseArgs/_resetSession` 支持「同会话复用 / 新会话重置」；新增 `enableFloat`(Rx)、`maybeInstance/instance/enter`、`onAudioPageClosed`（开关关→`stopAndReset` 还原旧行为；开关开→保持播放）、`stopAndReset`、`playing`(Rx)；`from` 由 `late final` 改 `late`。
  - `lib/pages/audio/view.dart`：改用 `AudioController.enter(Get.arguments)`；`dispose()` 调用 `onAudioPageClosed`；AppBar 新增悬浮窗开关图标。
  - `lib/pages/audio/mini_player.dart`（新增）：可拖动的应用内悬浮条，含播放/暂停、上一首/下一首、点按回到播放器。
  - `lib/main.dart`：`_builder` 用 `Stack` 全局叠加 `AudioMiniPlayer`。
  - `lib/pages/setting/models/play_settings.dart`：新增「应用内悬浮窗控制」开关并同步 `AudioController`。
- ⚠️ 沙箱无 Flutter SDK，**尚未跑 `flutter analyze`/编译**，需本地构建验证后再发布。

### 2026-09-14 【修复】应用内悬浮窗不显示
- 现象：返回后音乐能继续播，但右下角悬浮条完全不显示（与系统「显示在其他应用上层」权限无关，本悬浮窗是应用内叠加，不需要该权限）。
- 根因：顶层 `AudioMiniPlayer` 在应用启动首次构建时会话尚未建立，`maybeInstance==null` 直接返回 `SizedBox.shrink()`，且它内部的 `Obx` 分支未被创建，之后无重建，悬浮窗永远隐藏。
- 修复：新增 `AudioController.audioSessionActive`（静态 `RxBool`），`_updateCurrItem` 置 true、`_resetSession` 置 false；`AudioMiniPlayer.build` 改为从一开始就包裹在 `Obx` 中订阅该信号，会话激活即显示。
- 涉及：`lib/pages/audio/controller.dart`、`lib/pages/audio/mini_player.dart`。已推送 `fork/main` @ `b87b0de96`，并重新触发不发 release 的构建。

### 2026-09-14 【优化】悬浮窗深色模式/可读性 + 播放器内隐藏 + 暂停退出不显示 + 开关直白
- 深色模式取色：悬浮窗先前用 `ColorScheme.of(context)`，取到 MaterialApp builder 外层默认亮色主题导致白底白字；改为 `ThemeUtils.theme.colorScheme`，并整体包 `Theme(data: ThemeUtils.theme)`，图标/文字跟随主题。
- 播放器界面内隐藏悬浮窗：新增 `AudioController.audioPageOpen`(RxBool)，`audio/view.dart` initState 置 true、dispose 置 false；mini_player 在 true 时不显示。
- 暂停退出不显示：mini_player 增加 `!controller.playing.value` 时不显示。
- 开关更直白：AppBar 图标开关删除（防溢出），改为播放器页底部带文字「应用内悬浮窗」+Switch 的 `_buildFloatSwitch`（横竖屏皆显示）。
- 涉及：`lib/pages/audio/controller.dart`、`lib/pages/audio/mini_player.dart`、`lib/pages/audio/view.dart`。

### 2026-09-14 【发布/构建偏好】只构建安卓端
- 用户要求：以后构建**只做安卓端**，其他端（iOS/macOS/Windows/Linux）一律不构建。
- 已把 `.github/workflows/build.yml` 中 `build_ios/build_mac/build_win_x64/build_linux_x64` 的输入默认值从 `true` 改为 `false`（仅 `build_android` 默认 `true`），并已推送。以后 web 手动触发或其他 dispatch 默认只构建安卓。
- 触发时不发 release 用 `tag:""`；如需显式只安卓，可带 `build_android:true`（其余不传即可，因已默认 false）。

### 2026-09-14 【回退】移除「应用内返回不停止音频 + 悬浮窗控制」功能
- 用户决定：该功能 bug 太多，整体回退不要了。
- 已将下列文件还原到基线 `4d0846717`（功能开发前状态），并删除新增的 `lib/pages/audio/mini_player.dart`：
  - `lib/main.dart`、`lib/pages/audio/controller.dart`、`lib/pages/audio/view.dart`、`lib/pages/setting/models/play_settings.dart`、`lib/utils/storage_key.dart`、`lib/utils/storage_pref.dart`
- **保留**：`.github/workflows/build.yml` 的「仅安卓端默认构建」改动与上文构建偏好记录（与悬浮窗功能无关，用户明确要保留）。
- 功能相关历史提交仍存在于 `fork/main` 提交记录中（作为逆操作的还原提交保留，不删除历史）。

## 十、常用操作速查

- 触发测试构建（不发 release）：POST `/repos/silverwolf-lv9999/PiliPlus/actions/workflows/build.yml/dispatches`，body 里 `tag:""`。
- 触发发布构建：同上，`tag:"v2.1.4.2"` 且带 `app_version:"2.1.4.2"`（tag 名自定，建议与版本号一致）。
- 查 run 状态 / 列 artifact / 下载 artifact：用 releases 与 actions 接口，需 token。
- 改 `lib/pages/about/view.dart` 关于页；README 在仓库根；两部分改完都要重现构建 APK 才会生效。