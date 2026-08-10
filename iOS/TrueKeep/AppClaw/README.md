# TrueKeep AppClaw 自动回归

这里保存 TrueKeep / 留真的确定性 AppClaw P0 用例。用例只使用稳定的 accessibility identifier 和 AppClaw 严格 YAML，不依赖 LLM、截图识别或坐标点击。

## 当前覆盖

| Case | 场景 | 关键断言 |
| --- | --- | --- |
| `trust-intro-skip` | 授权前说明与暂不授权 | 先说明本地处理、不会自动删除；暂不授权不会触发系统弹窗，首页保留恢复入口 |
| `settings-trust-details` | 隐私与安全说明 | 三项说明均可发现，数据与隐私详情可进入且明确不上传、不跟踪 |
| `review-bin-deletion-safety` | 任务复核到复核箱 | 必须二次确认并展示 iCloud 风险；测试安全锁阻止真实删除 |
| `permission-denied-retry` | 权限关闭与重试 | 重试按钮显示局部忙碌状态，失败后可继续重试或回到首页 |
| `scan-cancel-recovery` | 扫描中取消 | 取消入口始终可用，明确未改动照片，能够回到首页 |
| `limited-results-rescan` | 有限权限结果页重扫 | 入口位于 Tab Bar 上方，点击后重新进入本地扫描流程 |

启动参数集中维护在 `cases.json`，Flow 在 `flows/`。每条用例都必须包含 `-TrueKeepDisablePhotoDeletion`；运行器还会注入 `TRUEKEEP_DISABLE_PHOTO_DELETION=1` 作为第二道保护。

## 运行前提

- 已安装 AppClaw 2.x，并可通过 `appclaw` 命令运行。
- iPhone 已解锁、信任当前 Mac、开启 Developer Mode，并已安装当前 TrueKeep Debug 包。
- 真机需要可用的 WebDriverAgent。运行器支持让 AppClaw 自行管理 WDA，也支持复用或启动已安装的 WDA。
- 这些用例会读取确定性 sample data，但不会调用真实 Photos 删除 API；破坏性测试不在本套件范围内。

## 常用命令

列出用例：

```bash
python3 iOS/TrueKeep/Scripts/appclaw_regression.py --list
```

预览完整回归命令，不操作设备：

```bash
python3 iOS/TrueKeep/Scripts/appclaw_regression.py --udid <DEVICE_UDID>
```

让 AppClaw 自行准备 WDA，运行全部 P0：

```bash
python3 iOS/TrueKeep/Scripts/appclaw_regression.py \
  --udid <DEVICE_UDID> \
  --execute
```

模拟器需要先安装当前 TrueKeep Debug 包，然后指定 booted simulator：

```bash
python3 iOS/TrueKeep/Scripts/appclaw_regression.py \
  --device-type simulator \
  --udid <SIMULATOR_UDID> \
  --execute
```

推荐的稳定真机方式是复用已安装 WDA；运行器会启动 WDA、管理 `iproxy` 并等待 `/status` 就绪：

```bash
python3 iOS/TrueKeep/Scripts/appclaw_regression.py \
  --udid <DEVICE_UDID> \
  --wda-bundle-id <WDA_RUNNER_BUNDLE_ID> \
  --execute
```

如果 WDA 和端口转发已经由外部进程管理：

```bash
python3 iOS/TrueKeep/Scripts/appclaw_regression.py \
  --udid <DEVICE_UDID> \
  --wda-url http://127.0.0.1:8100 \
  --execute
```

只运行一条或多条用例：

```bash
python3 iOS/TrueKeep/Scripts/appclaw_regression.py \
  --udid <DEVICE_UDID> \
  --wda-bundle-id <WDA_RUNNER_BUNDLE_ID> \
  --case scan-cancel-recovery \
  --case limited-results-rescan \
  --execute
```

构建并覆盖安装当前 checkout 后再回归：

```bash
python3 iOS/TrueKeep/Scripts/appclaw_regression.py \
  --udid <DEVICE_UDID> \
  --install-latest \
  --team-id <DEVELOPMENT_TEAM> \
  --wda-bundle-id <WDA_RUNNER_BUNDLE_ID> \
  --execute
```

`--install-latest` 当前只用于签名真机包；模拟器请先通过 `xcodebuild` 和 `simctl install` 安装。

也可以使用环境变量 `DEVICE_UDID`、`APPCLAW_WDA_URL`、`APPCLAW_WDA_BUNDLE_ID` 和 `DEVELOPMENT_TEAM`，避免在每次命令中重复填写。

## 报告与失败定位

每条 Flow 都以独立 Appium session 启动，确保启动参数和状态互不污染。运行器默认继续执行剩余 case，并在最后汇总 PASS/FAIL；需要首错即停时添加 `--fail-fast`。

运行器会把 AppClaw 子进程固定为非交互模式，避免自动化任务等待隐藏的 WDA 确认提示；单条 case 默认最多运行 180 秒，可用 `--case-timeout <SECONDS>` 调整。
目标 UDID 会同时传给 AppClaw CLI 和每个 Appium session，避免连续真机 session 丢失设备选择后误走模拟器 runtime。

AppClaw 的截图、页面树和步骤报告写入仓库根目录的 `.appclaw/runs/`，该目录已加入 `.gitignore`。查看报告：

```bash
appclaw --report --report-dir .
```

定位失败时按以下顺序检查：

1. WDA `/status` 是否为 ready，iPhone 是否仍保持解锁。
2. Flow 使用的 `truekeep.*` identifier 是否仍存在于 `TrueKeepAccessibility.swift`。
3. `cases.json` 的启动场景是否与对应 Flow 一致。
4. AppClaw 报告中的页面树是否能找到目标；只有无法提供语义标识的控件才考虑视觉 fallback，P0 主链路不得依赖视觉模型。

## 新增用例约定

1. 在 `flows/` 新增一个完整、可独立执行的严格 YAML Flow。
2. 在 `cases.json` 注册唯一 case id、P0/P1 层级、说明和启动参数。
3. 必须启用 `-TrueKeepDisablePhotoDeletion`，涉及删除时只验证二次确认和安全锁结果。
4. 优先使用 `truekeep.*` identifier；避免坐标、易变文案和模糊视觉定位。
5. 长耗时操作必须断言操作局部进度、取消或重试入口以及失败后的恢复路径。
6. 先运行脚本单元测试，再在模拟器或真机上执行新增 Flow。
