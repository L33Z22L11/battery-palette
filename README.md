# Battery Palette

macOS 电量面板及 WidgetKit 小组件。显示设备图标、名称和电量；没有面板标题、时钟或操作提示文案。

## 使用

安装脚本的默认位置：`~/Applications/BatteryPalette.app`。
通知中心 → 编辑小组件 → 搜索 Battery Palette，提供小、中、大三种尺寸，也可放到桌面。小、中尺寸优先显示电量最低的四台设备，未知电量排在最后；相同电量保持原有顺序。大尺寸按设备数量与可用高度动态调整圆环和行高，四台时更舒展，五至六台时收紧，仍从顶部逐行排列。

设置 → 显示方式 → 预设：

- **仅组件**：隐藏菜单栏图标和常驻面板，通过 Widget 唤出面板。
- **菜单栏**：左键图标在其下方弹出面板，再次点击、点击别处或按 Esc 收起。
- **桌面浮窗**：保留可拖动的桌面面板；点击可临时置前，点击别处或按 Esc 回到底层。也可以选择前两项，直接把系统 Widget 拖到桌面。

右键菜单栏或面板打开设置；面板激活时也可按 Command+,。设置内可控制设备名称、电量百分比（同步至面板与 Widget，百分比也控制菜单栏数字），以及开机自启。登录项通过系统 SMAppService 管理，仅在手动切换开关时注册；如系统要求批准，设置会显示入口。启动默认不弹出临时面板。

点击桌面或通知中心 Widget，在唤起时的鼠标位置附近展开面板，并避让屏幕边缘。WidgetKit 的 URL 回调不包含组件屏幕边界，因此不是精确贴合组件外框；冷启动期间移动鼠标可能改变展开位置。菜单栏点击仍定位在图标下方。桌面浮窗的位置单独保存。

右键设备行可更换图标并同步至组件。真实设备名称和电量从系统读取；预览只使用“笔记本电脑／无线键盘／无线鼠标／遥控器”等通用示例。硬件 VID/PID 兼容规则用于修正特定型号在系统中的错误分类，不绑定某个人的设备标识。

状态栏电量环：充电绿、未充电且电量 ≤20% 红、低电量模式黄、游戏模式蓝。冲突优先级为低电量红 → 省电黄 → 游戏蓝 → 充电绿。数字和底环跟随菜单栏深浅外观变化；普通状态和菜单选中状态使用系统模板图标。
游戏模式通过 Xcode 默认安装路径中的 `gamepolicyctl game-mode status` 只读查询；不可用时不显示游戏状态色。

后台每 30 秒读取系统电量，设备上报可能更慢。完全退出后，Widget 仍在系统调度时自行读取，无法保证固定刷新间隔；读取失败时使用最多 20 分钟的快照。隐藏界面不会停止后台采集。

桌面面板使用原生 NSGlassEffectView（macOS 26+）：停在桌面层时为 Clear 材质，临时置前时切换为 Regular 材质以提高可读性；没有叠加自定义模糊或染色层。玻璃直接作为窗口内容并裁剪边界，窗口外不再保留透明留白容器。旧系统使用系统模糊材质。系统 Widget 背景由 macOS 管理。
不联网、不安装驱动、不修改蓝牙配置。

## 构建和安装

需要 macOS 14+、Xcode 26+（提供 macOS 26 SDK），并完成 Xcode 首次初始化。Liquid Glass 需要运行在 macOS 26+；旧系统使用系统模糊材质。无第三方依赖。

构建脚本使用 `xcode-select` 当前选中的完整 Xcode，也支持通过 `DEVELOPER_DIR` 指定位置。默认本地 ad-hoc 签名，未提供 Developer ID 签名或公证发行包。

```sh
./build.sh --install
# 只生成 zip 安装包，不留下第二份可被系统登记的 .app：
./build.sh
~/Applications/BatteryPalette.app/Contents/MacOS/BatteryPalette --dump
~/Applications/BatteryPalette.app/Contents/MacOS/BatteryPalette --widget-dump
```

构建在临时目录进行，结束后删除临时构建产物。安装包位于 build 目录，该目录及编译缓存均不纳入版本管理。
直接从 Xcode 运行仍会产生 DerivedData 副本；日常安装请使用脚本。
扩展目标使用 `_NSExtensionMain` 入口，避免 macOS 26 上 Swift Widget.main 返回后扩展立即退出。
验证不能只看 pluginkit 注册：还需确认 chronod 成功取得描述和三种尺寸的预览。

读取配件电量使用 IOKit 私有接口 `IOPSCopyPowerSourcesByType`，未来系统更新可能影响兼容性。
主程序向自己扩展的容器写入快照，扩展在沙盒中读取；未使用需要开发者团队配置的 App Group。

## 卸载

退出应用并将安装目录中的应用移到废纸篓。偏好域为 `local.battery-palette`，扩展缓存位于 `~/Library/Containers/local.battery-palette.widget`。

电量圈使用 SwiftUI Circle 自绘：系统绿色进度弧、圆头端点、8% 系统前景色底环。满电直接画闭合圆，零电量只显示底环。圆环没有阴影、模糊、渐变、对比度修正或 drawingGroup。中心图标限制在圆环直径的 46% 内，文字使用默认字重与字体设计。


## 开源范围与数据

本仓库发布 macOS 主应用、WidgetKit 扩展、构建脚本、测试及渲染诊断工具。设备名称、电量、图标偏好、安装包、编译缓存和本机设置不随源码提交。应用不包含遥测、账号系统或网络请求。预览和诊断仅使用通用示例。

配件支持取决于 macOS 是否暴露电量；不是所有蓝牙设备都能读取。当前使用 IOKit 私有接口，属于实验性的本地桌面工具，不是 App Store 发行方案。扩展数据共享依赖本机容器路径，系统升级可能影响兼容性。修改 bundle identifier 时，应同步修改 `SnapshotStore.swift` 中的扩展标识与 Info.plist URL 配置。

## 代码导航与验证

| 文件 | 职责 |
| --- | --- |
| `main.swift` | 面板、设置、菜单栏交互和登录项 |
| `Sources/BatteryData.swift` | 系统电量读取与设备分类 |
| `Sources/BatteryRing.swift` | 环形电量绘制 |
| `Sources/StatusAppearance.swift` | 菜单栏图标、状态色与可选游戏模式读取 |
| `Sources/SnapshotStore.swift` | 主应用与 Widget 的数据快照 |
| `Widget/BatteryPaletteWidget.swift` | 小组件内容和时间线 |

```sh
./test.sh
./build.sh
```

测试覆盖状态颜色优先级、游戏模式输出解析和快照兼容。界面检查工具见 [Diagnostics](Diagnostics/README.md)。提交改动时请描述 macOS/Xcode 版本、复现步骤及相关验证；提交截图或日志前移除设备标识和私人信息。

## 许可证

[MIT](LICENSE) · Copyright © 2026 Zhilu

## 自动发布

GitHub Actions 会在推送 `v*` 标签后自动测试、构建通用安装包、验证版本号与架构、生成 SHA-256 校验文件，再发布中文 Release。主应用和 Widget 的 `CFBundleShortVersionString` 必须与标签去掉 `v` 后一致。

也可在 Actions →「构建与发布」→ Run workflow 中输入已有标签，补发旧版本。流水线使用 GitHub 自动提供的令牌，无需配置个人访问令牌。附件上传成功后才公开 Release，已经发布的版本不会被覆盖。安装包仍为 ad-hoc 签名，流水线不包含公证。


## 组件注册自动恢复

仅在主程序启动、系统唤醒时检查当前安装目录中的 Widget 注册记录，不进行周期性检查。注册缺失时只重新登记本应用及内嵌扩展，验证成功后请求刷新。不删除布局、不清理全局缓存、不重启系统服务，也不重新启用用户明确禁用的扩展。命令超时或查询失败会记录日志，等待下次启动或唤醒再检查。

自动恢复需要主程序运行。若希望系统升级重启后自动恢复，可在设置中开启「开机自启」。这是对已观察到的注册丢失问题的恢复措施，不保证解决全部 WidgetKit 故障。
