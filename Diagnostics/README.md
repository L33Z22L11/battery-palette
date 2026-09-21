# 渲染诊断

这些可选工具使用通用示例数据，不编入主应用或小组件。

- `GaugeRenderingDiagnostics.swift`：比较原生 Gauge 的渲染与合成方式，仅用于调查，不代表已确认系统缺陷。正式应用使用 Circle 自绘电量圈。
- `BatteryRingBoundaryCheck.swift`：检查深浅色下 0/1/50/61/99/100% 的正式电量圈。
- `StatusIconAppearanceCheck.swift`：检查 Aqua、Dark Aqua、Vibrant Light、Vibrant Dark 下的状态色，输出 `/tmp/bp-status-appearances.png`。

选中完整 Xcode 后，在仓库根目录运行：

```sh
xcrun swiftc Diagnostics/GaugeRenderingDiagnostics.swift -framework AppKit -framework SwiftUI -o /tmp/bp-gauge-check
/tmp/bp-gauge-check

xcrun swiftc Sources/BatteryData.swift Sources/BatteryRing.swift Diagnostics/BatteryRingBoundaryCheck.swift -framework IOKit -framework SwiftUI -o /tmp/bp-ring-check
/tmp/bp-ring-check

xcrun swiftc Sources/StatusAppearance.swift Diagnostics/StatusIconAppearanceCheck.swift -framework AppKit -o /tmp/bp-status-check
/tmp/bp-status-check
```
