# Development

PhotoSelect 使用 Swift / SwiftUI 与 AppKit，目标系统为 macOS 14+，当前无第三方运行依赖。请先阅读 [AGENTS.md](../AGENTS.md)、[产品说明](../PRODUCT_SPEC.md) 和 [v2 审核记录](../V2_AUDIT.md)。

<a id="build"></a>

## 构建与测试

使用完整 Xcode，选择 PhotoSelect scheme 和 My Mac。已提交的 `.xcodeproj` 可直接使用，`project.yml` 供需要 XcodeGen 的开发者参考。

```bash
open "PhotoSelect.xcodeproj"
```

命令行构建：

```bash
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
  xcodebuild -project "PhotoSelect.xcodeproj" -scheme PhotoSelect \
  -destination 'platform=macOS' build
```

运行测试：

```bash
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
  xcodebuild -project "PhotoSelect.xcodeproj" -scheme PhotoSelect \
  -destination 'platform=macOS' test
```

只检查本地编译时，可在构建命令末尾加 `CODE_SIGNING_ALLOWED=NO`。这不验证分发签名、公证或实际运行权限。不要为处理本地签名问题关闭应用沙箱或扩大文件访问权限。

<a id="verification"></a>

## 最近验证：2026-10-22

| 检查 | 结果 | 范围 |
| :--- | :--- | :--- |
| 本地构建 | 成功 | Xcode / macOS 26.5 SDK，Apple Silicon，`CODE_SIGNING_ALLOWED=NO` |
| XCTest 目标编译 | 成功 | 测试代码完成编译与链接 |
| XCTest 执行 | 环境阻断 | 沙箱阻止连接 `com.apple.testmanagerd.control`，未得到测试通过结果 |
| 本轮实拍交互验收 | 未执行 | 需要在正常桌面环境重新验证完整流程 |

本次执行的命令如下；结果文件位于执行机器的临时目录，未收入仓库。

```bash
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
  xcodebuild -project "PhotoSelect.xcodeproj" -scheme PhotoSelect \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "/private/tmp/PhotoSelect-status-20261022" \
  CODE_SIGNING_ALLOWED=NO build

DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
  xcodebuild -project "PhotoSelect.xcodeproj" -scheme PhotoSelect \
  -destination 'platform=macOS' \
  -derivedDataPath "/private/tmp/PhotoSelect-status-20261022" \
  CODE_SIGNING_ALLOWED=NO test
```

工程有一个未使用局部绑定的编译警告，位于 `AsyncPhotoView.swift`；不影响此次构建。构建成功不能替代实际选片体验和文件安全验收。

## 测试覆盖范围

仓库内的 XCTest 包含以下场景；这里描述测试内容，不表示本轮全部执行通过。

- 决定日志持久化、重载与清理；稳定的文件路径身份。
- Unreviewed 中连续决策、自动前进，以及关闭自动前进后离开当前筛选的选择状态。
- 切换筛选后的撤销、决策计数、首末导航与快速连续导航。
- 按当前筛选序列、下一张优先的预加载顺序。
- JPEG 降采样与缓存复用、预览和检查档位、缩放边界。
- 最近文件夹去重、八项上限、无效目录清理。
- EXIF 读取，以及尚未开放到界面的非破坏性复制导出辅助函数。

## 图像管线约束

| 请求档位 | 最大边长请求 | 用途 |
| :--- | ---: | :--- |
| Filmstrip | 320 px | 缩略图条 |
| Preview | 3200 px | 当前照片与相邻预加载，共用缓存档位 |
| Inspection | 7680 px | 离开 Fit 后的放大检查 |

图像缓存目标上限为 256 MiB、96 项；`NSCache` 会自行决定淘汰时机，这些设置不等同于整个应用的内存上限。实际输出分辨率受源图和系统解码器限制。RAW 先尝试 Quick Look，再回退到 ImageIO。

预加载遵循当前 `visibleAssets`，依次请求后面三张、前面两张。后台请求顺序执行，避免同时启动多项推测性 RAW 解码。目录扫描在后台运行，每批最多 128 个文件。

<a id="storage"></a>

## 数据存储与备份

选片决定使用标准化文件路径作为键。`DecisionPersistence` 在应用当前用户域的 Application Support 下创建：

```text
PhotoSelect/decisions.json
PhotoSelect/decisions.json.journal
```

应用启用了 App Sandbox；使用当前 bundle identifier 构建运行时，这通常位于：

```text
~/Library/Containers/com.example.PhotoSelect/Data/Library/Application Support/PhotoSelect/
```

未沙箱化的运行环境通常位于 `~/Library/Application Support/PhotoSelect/`。实际位置以运行时解析的用户域目录为准；修改 bundle identifier 会改变沙箱容器。

在退出应用后备份整个 `PhotoSelect` 数据目录，保留快照与日志两个文件。快照可能尚未生成，最新决定可能只在日志中。每 1,000 次日志变更会触发快照压缩。文件夹书签、最近文件夹和界面偏好保存在 UserDefaults 中；撤销栈只保存在内存中。

## 手动验收建议

使用可丢弃的测试副本验证文件操作，不要拿唯一原片测试废纸篓流程。

1. 打开数百张以上的混合素材，确认索引完成前可看到首批照片。
2. 连续翻片、连续分级，验证所有筛选中选择状态与计数一致。
3. 切换 Auto Advance，检查当前照片离开筛选后的导航与撤销。
4. 捏合缩放、双指平移、回到 Fit，切换照片与窗口大小。
5. 开关 Focus Mode 和缩略图条，验证快捷键继续工作。
6. 退出并重开，确认决定与文件夹恢复。
7. 用可丢弃副本检查废纸篓确认数量、成功移除与失败保留。

历史测试截图留在本地 `SmokeTestArtifacts/`，因含个人照片已被 `.gitignore` 排除。首页图片为独立矢量示意，不作为验收截图。
