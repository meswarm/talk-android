# Android 常驻语音播报 MVP 设计

## 背景

Talk 已经具备新消息系统通知和豆包 TTS 语音播报链路：

```text
Matrix 新消息 -> NotificationService -> 系统通知 -> DoubaoTtsService -> 本地播放
```

当前问题是 App 进入后台后，普通进程可能被 Android 或厂商 ROM 回收，导致 Matrix 同步、通知监听和语音播报不够稳定。普通应用不能实现微信级别的“永不被杀”，因此 MVP 目标是用 Android 官方支持的前台服务提高后台存活概率，并明确向用户展示常驻通知。

## 目标

实现一个用户主动开启的“语音播报常驻模式”：

- 开启后启动 Android `ForegroundService`。
- 系统通知栏显示常驻通知：“Talk 语音播报监听中”。
- App 进入后台时提升进程优先级，使现有 Matrix 监听和语音播报链路更不容易被系统回收。
- 关闭后停止前台服务，常驻通知消失。
- App 启动时读取本地开关，若用户已开启则自动恢复常驻服务。

## 非目标

本 MVP 不解决所有后台通知问题：

- 不接入 FCM、Matrix Push Gateway 或厂商推送。
- 不实现开机自启动。
- 不实现国产 ROM 的专项保活适配。
- 不启动独立 Flutter isolate 做后台 Matrix 同步。
- 不承诺“永不被杀”。系统仍可能在极端省电、手动清理、强制停止或厂商策略下终止 App。

## 用户体验

入口复用现有“个人资料页 -> 语音播报”设置页。

在语音播报页新增一组设置：

- 标题：`常驻监听模式`
- 开关：`启用常驻监听模式`
- 说明：开启后 Talk 会显示常驻通知，用于提高后台新消息语音播报的可靠性。
- 状态提示：
  - 未开启：`未开启常驻监听`
  - 已开启：`常驻监听中`
  - 启动失败：显示错误信息，不影响普通聊天使用
- 可选按钮：`电池优化设置`
  - 跳转到 Android 电池优化设置页，让用户手动把 Talk 设为不受限制。
  - MVP 只提供跳转入口，不做厂商 ROM 专项步骤。

如果豆包 TTS 未配置，仍允许开启常驻监听，但页面提示：`语音播报未配置，常驻服务只会保持监听，不会播放语音。`

## Android 原生层

新增 `TalkKeepAliveService.kt`：

- 继承 `Service`。
- `onCreate()` 创建通知渠道。
- `onStartCommand()` 调用 `startForeground()` 显示常驻通知，并返回 `START_STICKY`。
- `onDestroy()` 更新运行状态。
- 通知点击后回到 `MainActivity`。

通知内容：

- Channel ID：`talk_keep_alive`
- Channel name：`Talk 常驻监听`
- Notification title：`Talk 语音播报监听中`
- Notification text：`正在保持新消息语音播报监听`
- Ongoing：`true`
- Priority：低优先级，避免干扰用户。

`AndroidManifest.xml` 增加：

- `android.permission.FOREGROUND_SERVICE`
- `android.permission.POST_NOTIFICATIONS`，Android 13+ 需要运行时授权
- service 声明：

```xml
<service
    android:name=".TalkKeepAliveService"
    android:exported="false" />
```

MVP 不声明特殊 foreground service type，避免误用媒体播放、位置、麦克风等更高敏权限类型。

## Flutter 桥接层

新增 `KeepAliveServiceBridge`：

- 使用 `MethodChannel('talk/keep_alive_service')`。
- 暴露方法：
  - `start()`
  - `stop()`
  - `isRunning()`
  - `openBatteryOptimizationSettings()`

`MainActivity.kt` 注册对应 native 方法：

- `startKeepAliveService`
- `stopKeepAliveService`
- `isKeepAliveServiceRunning`
- `openBatteryOptimizationSettings`

Android 8+ 使用 `startForegroundService()`，低版本使用 `startService()`。

## 本地配置

在 `LocalStorage` 增加布尔配置：

- key：`talk_voice_keep_alive_enabled`
- 默认值：`false`

提供方法：

- `Future<bool> loadVoiceKeepAliveEnabled()`
- `Future<void> saveVoiceKeepAliveEnabled(bool enabled)`

配置只保存在本机，不同步到 Matrix。

## 启动恢复

App 启动时：

1. 初始化本地存储。
2. 读取 `talk_voice_keep_alive_enabled`。
3. 如果为 `true`，调用 `KeepAliveServiceBridge.start()`。
4. 如果启动失败，只记录/展示错误，不阻塞 App 初始化。

这不是开机自启动；只有 App 被用户打开后才恢复服务。

## 通知权限

Android 13+ 需要 `POST_NOTIFICATIONS` 权限。

MVP 策略：

- 开启常驻监听时检查/请求通知权限。
- 如果用户拒绝，提示：`需要通知权限才能显示常驻监听通知。`
- 不强制退出设置页，用户可以稍后再开。

如果现有 `flutter_local_notifications` 已有权限处理能力，优先复用现有插件；否则通过原生 MethodChannel 做最小权限请求。

## 错误处理

- 前台服务启动失败：设置页显示错误，并把开关恢复为关闭。
- 通知权限被拒绝：不启动服务，提示用户开启权限。
- 电池优化设置无法打开：显示普通错误提示。
- TTS 未配置：允许服务运行，但语音播报不会执行。
- Android 非目标平台：桥接层返回 no-op，避免影响 iOS、macOS、Windows、Linux 测试。

## 测试策略

单元/Widget 测试：

- `LocalStorage` 能保存和读取常驻监听开关。
- 语音播报设置页能显示常驻监听设置。
- 点击开关会调用 bridge start/stop。
- start 失败时开关恢复关闭并显示错误。
- 未配置 TTS 时显示提示但不阻止开启常驻监听。

原生层测试以手动验证为主：

- Android 设备打开语音播报页，开启常驻监听。
- 通知栏出现常驻通知。
- 回到桌面后通知仍存在。
- 关闭开关后通知消失。
- 重新打开 App 后，如果开关已开启，服务恢复。
- 点击常驻通知能回到 App。

回归验证：

```bash
flutter test
flutter analyze
```

## 后续阶段

MVP 稳定后再考虑：

- 开机自启动恢复常驻监听。
- 检测电池优化状态并提供更明确的引导。
- Matrix Push Gateway / FCM，解决 App 被彻底杀死后的通知可靠性。
- 小米、OPPO、vivo、华为等 ROM 的后台权限引导页。
- 独立后台 isolate 或原生 Matrix 长连接方案。

