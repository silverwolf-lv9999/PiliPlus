# 架构与仓库

## 1. 三个仓库

| 名称 | GitHub | 本地 | 用途 |
|---|---|---|---|
| 上游 | `bggRGjQaUbCoE/PiliPlus` | remote `origin` | 官方 PiliPlus，只读同步 |
| 个人 fork | `silverwolf-lv9999/PiliPlus` | `/workspace/PiliPlus` | **PiliNova 主项目**，发布来源 |
| PR 基线 | `silverwolf-lv9999/PiliUpstream` | `/workspace/PiliUpstream` | 干净的纯上游基线 + `pr/*` 分支，专门向上游提 PR |

> 用户说的「主项目」= 个人 fork 的 `main`。做功能、发版本都以它为准。
> `PiliUpstream` 的 remote 配置不同：`origin` 的 fetch 指上游、push 指自己的仓库；另有 `pr` remote。

## 2. 分支模型

| 分支 | 规则 |
|---|---|
| `main` | 主项目 / 发布基线。功能验证后并入这里。 |
| `pr/*` | **已提交给上游的 PR 分支，冻结**：不改、不并入 main、不删除。只在需要更新 PR 时操作。 |
| `feat/*`、`test/*` | 开发/测试分支。验证后并入 `main`，按需清理。 |

新功能流程：开发 → 验证 → 合并进 `fork/main` → 清理临时分支。**不要污染 `pr/*`**。

## 3. 同步上游

```bash
git fetch origin --tags
git checkout main
git merge <上游 tag>          # 如 2.1.6、upstream-2.1.6.2，按实际 tag 名
```

冲突处理原则：

1. **保留 fork 自研功能**：耳机控制、缓存听视频、仅下载音频、合并缓存、TAG 屏蔽、发布记录、PiliNova 命名与 CI 产物前缀。
2. **结构跟随上游**：上游重构过的 API/命名参数优先采用，再把 fork 参数追加进去（如 `downloadVideo` 的 `audioOnly/audioQuality/merge`）。
3. **import 区不要整段取一边**：两边都需要的 import 全部保留；合并后用脚本核对「上游/HEAD 有而合并结果缺失的 import」。
4. **注解跟随上游构建方式**：上游 2.1.6.2 起用 `proguard-rules.pro` 的 `-keep`，不再用 `@Keep`；保留 `@Keep` 会 `cannot find symbol`。
5. **合并后必须**：`flutter analyze`（对比改动前后集合）→ `flutter test` → 至少一次真实 APK 构建。`analyze` 全绿不代表能 AOT 编译。

同步完成后：

- 推送 `main`；
- 删除旧 release 与旧 tag（如果 tag 指向旧 HEAD），重新带 tag 构建，保证 **tag 与 APK 同源**；
- 在 [CHANGELOG.md](../CHANGELOG.md) 记版本级变化，在 [PITFALLS.md](PITFALLS.md) 记新踩的坑。

## 4. 向上游提 PR

- 在 `/workspace/PiliUpstream` 从 `main` 开 `pr/*` 分支，只包含单个功能的提交，**不带任何 PiliNova 自研功能**。
- 一个 PR 一个主题；提交信息用 Conventional Commits。
- 当前 PAT 是 fine-grained，通常无上游仓库写权限，创建 PR 需要浏览器打开 compare 链接。

## 5. 模块地图

| 模块 | 位置 | 关键点 |
|---|---|---|
| 视频详情页 | `lib/pages/video/` | 折叠工具栏 `_buildHeaderOverlay`；点击路由 `_handleOverlayTap`；高度动画 `_setVideoHeight` |
| 播放器 | `lib/plugin/pl_player/` | `autoPlay` / `videoState` / `videoController` 三者共同决定渲染，详见 [PITFALLS](PITFALLS.md#3-播放器--详情页折叠) |
| 下载 / 缓存 | `lib/pages/download/`、`lib/services/download/` | `audioOnly`、`audioQuality`、`merge` 参数贯穿；安卓合并走 Java `MediaHelper.mergeM4sToMp4` |
| 后台音频 | `lib/services/audio_handler.dart` | 耳机 `skipToNext` / `skipToPrevious`；后台播放开关 |
| SponsorBlock / 清风 | `lib/services/breeze/` | 规则、缓存、API Key 单独存放 |
| 设置 | `lib/pages/setting/` | 按功能拆 `models/*.dart`；读写统一走 `Pref` |
| 存储 | `lib/utils/storage.dart`、`storage_key.dart`、`storage_pref.dart` | 见下节 |
| 构建 | `lib/scripts/build.*`、`.github/workflows/build.yml` | 版本号注入，见 [BUILD.md](BUILD.md) |

## 6. 设置存储与导入导出

Hive boxes：

| box | 内容 | 是否随设置导出 |
|---|---|---|
| `setting` | 绝大多数设置项 | 是 |
| `video` | 视频相关设置 | 是 |
| `breeze` | 哔哩清风 API Key | **否**（单独保存，安全考虑） |
| `breezeCache` | 清风判定缓存 | 否 |
| `account` / `reply` 等 | 账号、发布记录 | 否 |

导出格式：`{ "setting": {...}, "video": {...} }`。

导入实现是 **`box.clear()` 再 `putAll()`**（`GStorage.importAllJsonSettings`）：

- JSON 里**缺失的键会回落成代码默认值**，不是保留当前值；
- 因此「旧设置导入后某处异常」要按**导入后的最终值**判断，而不是只看 JSON 里有没有这个键；
- JSON 里多出的、当前版本已不认识的键会被写进 box，但 `Pref` 不会读取，通常无害，只是脏数据。

主题相关设置的合法范围以代码为准：

- `themeMode`：`0` 浅色 / `1` 深色 / `2` 跟随系统（`ThemeType` 顺序）；
- `schemeVariant`：`FlexSchemeVariant` 枚举索引，当前依赖 5.0.1 中 `10` 合法（`material3Legacy`）；
- `reduceLuxColor`：深色下给图片叠加的 ARGB 颜色，异常值会让图片整体发暗/发灰；
- 判断「灰」是主题问题还是渲染问题，先看该区域是不是 `colorScheme.surface` 实心块，**不要先改主题**（反例见 [PITFALLS 4.2](PITFALLS.md#4-设置导入--主题)）。

新增设置项的固定动作：

1. `lib/utils/storage_key.dart` 加 key；
2. `lib/utils/storage_pref.dart` 加 getter/setter 与默认值；
3. `lib/pages/setting/` 加 UI；
4. 需要导出就放进 `setting` box（自动包含）。

## 7. 命名

- 应用显示名：**PiliNova**（`lib/common/constants.dart` 的 `appName`、Android `string.xml`、`AndroidManifest.xml` 的 `android:label`、iOS `Info.plist`）。
- 保持不变：Dart 包名 `PiliPlus`、`package:PiliPlus/...`、源码目录、仓库 slug、`applicationId`。
- APK 名与版本号由 CI / `lib/scripts/build.*` 生成，前缀 `PiliNova_android_`。
