# AGENTS.md — PiliNova

给 AI 编码代理的项目入口。**先读本文件，再按文末「按需阅读」跳转**。

本文件只放**稳定的、可复用的规则**。改动历史进 [CHANGELOG.md](CHANGELOG.md)，踩坑根因进 [docs/PITFALLS.md](docs/PITFALLS.md)。

## 项目是什么

- PiliNova 是上游 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 的二次开发版，Flutter 项目，Android 优先。
- 个人仓库：`silverwolf-lv9999/PiliPlus`，主分支 `main`（remote `fork`）。
- 上游仓库：`bggRGjQaUbCoE/PiliPlus`（remote `origin`）。
- 上游 PR 专用干净基线仓库：`silverwolf-lv9999/PiliUpstream`（本地 `/workspace/PiliUpstream`）。
- **只改显示名**：Dart 包名、`package:PiliPlus/...`、源码目录、仓库 slug、applicationId 都保持 `PiliPlus`。

## 常用命令

> 沙箱内构建前必须先打补丁，漏跑会在 AOT 阶段报几十条「未定义 getter / 无此命名参数」。

```bash
source /opt/sdk/build_env.sh              # 代理 + 镜像 + SDK 环境
flutter pub get                           # 必须在 material_ui 补丁之前
bash /opt/sdk/apply_patches.sh android    # Flutter 24 补丁 + material_ui 9 补丁（必做）
bash lib/scripts/build.sh android         # 注入合法 versionName / versionCode（必做）
flutter analyze
flutter test
flutter build apk --release --dart-define-from-file=pili_release.json
```

CI 用 `.github/workflows/build.yml`（`workflow_dispatch`），默认只构建 Android。
发布、签名、版本号规则见 [docs/BUILD.md](docs/BUILD.md)。

## 硬约束

1. **不动 `pr/*` 分支**：那是已提交给上游的 PR 分支，不改、不并、不删。
2. **不改包名**：测试包名固定 `test.piliplus.com`；未到最终版不要用 `com.example.piliplus`。
3. **不改 Dart 包名 / import**：改名只改显示名。
4. **不提交密钥**：`.signing/`、`android/key.properties`、token 一律不入库。
5. **不提交沙箱专用的 `dependency_overrides`**（如 `material_ui: 1.5.0`）：那是本地解析差异，CI 不受影响，提交会污染构建。
6. **未经用户明确授权，不推送、不发 Release**；用户说「只改设置 / 不动代码」时严格遵守。
7. **合并上游必须保留 fork 功能**：耳机控制、缓存听视频、仅下载音频、合并缓存、TAG 屏蔽、发布记录、PiliNova 命名与 CI 产物前缀。
8. **不要清理私有的 SDK / material_ui 补丁 API**：项目依赖这些补丁暴露的成员，删了 analyze 可能不报，但 AOT 编译必炸。
9. **同一状态的渲染条件必须互补**：详见 [PITFALLS «播放器折叠»](docs/PITFALLS.md)，不要单独放宽其中一侧。

## 代码地图

| 路径 | 内容 |
|---|---|
| `lib/pages/video/` | 视频详情页；折叠/播放态在 `view.dart`（`_buildHeaderOverlay`、`_handleOverlayTap`、`_setVideoHeight`） |
| `lib/plugin/pl_player/` | 播放器封装；`controller.dart` 维护 `autoPlay` / `videoState` / `videoController` 状态机 |
| `lib/pages/download/`、`lib/services/download/` | 缓存/下载；合并缓存走 Java `MediaHelper.mergeM4sToMp4` + Dart 包装 |
| `lib/services/breeze/` | 哔哩清风 SponsorBlock / BiliBreeze 移植 |
| `lib/services/audio_handler.dart` | 后台音频、耳机控制（`skipToNext` / `skipToPrevious`） |
| `lib/utils/storage_key.dart`、`storage_pref.dart` | Hive 设置读写；**新增设置项必须同时改这两处** |
| `lib/pages/setting/` | 设置 UI，按功能拆在 `models/*.dart` |
| `lib/scripts/build.*`、`.github/workflows/build.yml` | 版本号注入与 CI 发布 |
| `test/` | 单测；播放器状态机用例在 `test/pages/video/` |

## 按需阅读

| 文档 | 什么时候读 |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 搞不清仓库/分支关系、要合并上游、要提 PR |
| [docs/BUILD.md](docs/BUILD.md) | 构建、签名、版本号、发版、下载 artifact |
| [docs/PITFALLS.md](docs/PITFALLS.md) | 构建失败、灰屏、合并冲突、设置异常 |
| [CHANGELOG.md](CHANGELOG.md) | 想知道当前基线、上次改了什么 |
| [docs/archive/DEV_MEMO.md](docs/archive/DEV_MEMO.md) | 仅查历史细节，**已废弃，不作为规范** |

## 工作方式

- 改之前先读相关代码，不要凭印象改；不确认的结论要标明未验证。
- 只做用户要求的事，不做顺手重构、不加超前抽象。
- 提交信息用 Conventional Commits：`fix(video): ...`、`feat(download): ...`。
- 完成定义（按需）：`flutter analyze` 无新增问题 → `flutter test` 通过 → 台架/真机验证 → 留下证据（命令输出、截图、commit）。
- 记录规则：
  - 稳定知识（怎么构建、为什么这样设计）→ `docs/`；
  - 每次改动/发布 → 追加 `CHANGELOG.md`（**版本维度**）；
  - 新踩的坑 → 追加 `docs/PITFALLS.md`（**根因维度，按主题归类，不按日期**）；
  - 不要再新建 `DEV_MEMO.md` 这类混合大文件。
