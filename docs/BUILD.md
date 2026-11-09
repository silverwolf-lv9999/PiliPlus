# 构建与发布

## 1. 版本号规则

| 名称 | 格式 | 示例 | 用途 |
|---|---|---|---|
| Release 名 / tag | `上游版本.X` | `2.1.4.2`、`2.1.6.2x1` | GitHub Release、tag |
| 应用内 / Android 版本名 | `上游版本xN` | `2.1.4x2`、`2.1.6.2x1` | 系统设置、关于页、APK 文件名 |
| pubspec `version` | **只能三段** | `2.1.4+5383` | Flutter 要求 |
| versionCode | 提交数 | `5549` | 必须递增 |

- Flutter 的 pubspec 不接受四段点数（`2.1.4.2` 会被判非法并回退成 `1.0` / `1`），所以展示版本用字母 `x` 分隔，由 `--build-name` / `--build-number` 覆盖。
- `versionCode` 由 `git rev-list --count` 得出，**必须是完整克隆**；浅克隆会算出 `1` 或几百，见 [PITFALLS 1.3](PITFALLS.md#1-构建环境沙箱)。
- 测试包（本地 debug 签名）与正式包（release 签名）签名不同，且本地测试包的 versionCode 可能更高；从测试包切正式版通常需要先卸载。

## 2. CI 构建（`.github/workflows/build.yml`）

`workflow_dispatch` 输入：

| 输入 | 默认 | 说明 |
|---|---|---|
| `build_android` | `true` | 只构建 Android（其他平台默认全 `false`，按用户要求不构建） |
| `app_version` | 空 | 应用内版本名，如 `2.1.6.2x1`；留空则用上游版本 + 提交 hash |
| `tag` | 空 | **空 = 只出 artifact，不发 Release；非空 = 创建 Release** |

两种用法：

- 测试构建：`tag=""`，只下载 artifact。
- 发布构建：`tag=<tag>` + `app_version=<版本名>`。

签名 secrets（仓库 Settings → Secrets）：

- `SIGN_KEYSTORE_BASE64`：`.signing/release_keystore.jks` 的 base64；
- `KEYSTORE_PASSWORD`、`KEY_PASSWORD`、`KEY_ALIAS`（`piliplus`）。

Workflow 会解码生成 `android/app/key.jks` 与 `android/key.properties`，`build.gradle.kts` 读到即使用 release 签名；缺 secret 会回退 debug 签名。

## 3. 本地构建（沙箱）

```bash
source /opt/sdk/build_env.sh
flutter pub get
bash /opt/sdk/apply_patches.sh android     # 必做，漏跑 AOT 会报几十条未定义成员
bash lib/scripts/build.sh android          # 注入合法 versionName / versionCode
flutter build apk --release --dart-define-from-file=pili_release.json
```

- 环境：Flutter 3.47.7（`/opt/sdk/flutter`）、JDK 17、Android SDK `/opt/sdk/android`。
- `flutter clean` 后必须重新 `flutter pub get`。
- 后台 shell 默认没有 `ANDROID_HOME` / `JAVA_HOME`，`source /opt/sdk/build_env.sh` 会补齐。
- 代理由 mihomo 提供（`127.0.0.1:7890`），构建前确认存活。
- 沙箱专用问题（补丁顺序、代理、R8 缓存损坏、`material_ui` 版本）见 [PITFALLS 第 1 节](PITFALLS.md#1-构建环境沙箱)。

产物校验：

```bash
aapt2 dump badging <apk> | head        # 包名、versionName、versionCode
apksigner verify --print-certs <apk>   # 签名指纹
```

## 4. 发布

1. 代码先推送 `main`，确认 CI 通过。
2. 若旧 tag 指向旧提交：删除旧 Release 与旧 tag。
3. 从 **当前 `main` HEAD** 触发 `build.yml`，带 `tag` 与 `app_version`。
4. 构建成功后 PATCH Release：`name` 改为版本名，`body` 从 [CHANGELOG.md](../CHANGELOG.md) 对应版本段落摘取。
5. 校验：tag 指向的 commit 与 workflow run 的 HEAD 一致；APK 的 `versionName` / `versionCode` 与预期一致。

> **tag 与 APK 必须同源**：Release 步骤用输入 tag 绑定，但 artifact 由 run 的 HEAD 构建。tag 指 A、APK 来自 B 是历史事故，见 [PITFALLS 2.1](PITFALLS.md#2-合并上游与发布一致性)。

下载 artifact 走 GitHub API（需要 `repo` + `actions:read` 权限的 token）。

## 5. 发布记录

| 版本 | tag | versionCode | 日期 | CI run |
|---|---|---|---|---|
| `2.1.6.2x1` | `2.1.6.2x1` | 5549 | 2026-10-20 | 39374799621 |
| `2.1.6x1` | `v2.1.6.1` | 5521 | 2026-10-05 | 37488509429 |
| `2.1.5x1` | `v2.1.5.1` | 5452 | 2026-09-27 | 36285297047 |
| `2.1.4.2` | `v2.1.4.2` | 5383 | 2026-09-14 | 34842905489 |

更早的 `2.1.3.x` / `2.1.4.1` 见 [CHANGELOG.md](../CHANGELOG.md)。
